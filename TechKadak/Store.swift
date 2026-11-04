import Foundation
import SwiftUI
import UIKit

enum Config {
    static let siteBase = "https://techkadak.github.io"
    static let appsURL = "https://techkadak.github.io/data/apps.json"
    static let kitsURL = "https://techkadak.github.io/data/kits.json"
    static let videosURL = "https://www.youtube.com/feeds/videos.xml?channel_id=UCpxdwzHB-66cPyssRH5IaTA"
    static let instagram = "https://www.instagram.com/techkadak/"
    static let youtube = "https://www.youtube.com/channel/UCpxdwzHB-66cPyssRH5IaTA"
    static let telegram = "https://t.me/techkadak"
    static let website = "https://techkadak.github.io"
    static var version: String { (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0" }

    /// CI/test hooks (launch arguments). Real users ke liye kuch nahi badalta.
    static let args = ProcessInfo.processInfo.arguments
    static func arg(_ name: String) -> String? {
        guard let i = args.firstIndex(of: "-" + name), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    static var offline: Bool { arg("tkOffline") == "1" }
}

enum DataSource: String { case live, cache, bundled, none }

@MainActor
final class Store: ObservableObject {
    @Published var apps: [AppItem] = []
    @Published var kits: [Kit] = []
    @Published var videos: [Video] = []
    @Published var source: DataSource = .none
    @Published var loading = false
    @Published var offlineNote = false
    @Published var favs: [String] = UserDefaults.standard.stringArray(forKey: "tk.favs") ?? []

    private var bySlug: [String: AppItem] = [:]
    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 15
        c.timeoutIntervalForResource = 30
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: c)
    }()

    init() {
        loadLocal()
    }

    // MARK: local (cache → bundled), turant — app hamesha khulta hai
    func loadLocal() {
        if let d = Self.readCache("apps.json"), let a = Parse.apps(d) { setApps(a, .cache) }
        else if let d = Self.bundled("apps", "json"), let a = Parse.apps(d) { setApps(a, .bundled) }
        if let d = Self.readCache("kits.json"), let k = Parse.kits(d) { kits = k }
        else if let d = Self.bundled("kits", "json"), let k = Parse.kits(d) { kits = k }
        if let d = Self.readCache("videos.xml"), let v = VideoFeedParser.parse(d) { videos = v }
        else if let d = Self.bundled("videos", "xml"), let v = VideoFeedParser.parse(d) { videos = v }
    }

    func refresh() async {
        if loading { return }
        loading = true
        defer { loading = false }
        if Config.offline { offlineNote = true; return }
        let appsURL = Config.arg("tkAppsURL") ?? Config.appsURL
        async let a = fetch(appsURL)
        async let k = fetch(Config.kitsURL)
        async let v = fetch(Config.videosURL)
        let (ad, kd, vd) = await (a, k, v)
        if let ad = ad, let parsed = Parse.apps(ad) {
            setApps(parsed, .live); Self.writeCache("apps.json", ad); offlineNote = false
        } else {
            offlineNote = true
        }
        if let kd = kd, let parsed = Parse.kits(kd) { kits = parsed; Self.writeCache("kits.json", kd) }
        if let vd = vd, let parsed = VideoFeedParser.parse(vd) { videos = parsed; Self.writeCache("videos.xml", vd) }
    }

    private func fetch(_ s: String) async -> Data? {
        guard let url = URL(string: s) else { return nil }
        do {
            let (d, r) = try await session.data(from: url)
            guard let h = r as? HTTPURLResponse, (200..<300).contains(h.statusCode), !d.isEmpty else { return nil }
            return d
        } catch { return nil }
    }

    private func setApps(_ a: [AppItem], _ s: DataSource) {
        apps = a
        source = s
        var m: [String: AppItem] = [:]
        for x in a { m[x.slug] = x }
        bySlug = m
    }

    func app(_ slug: String) -> AppItem? { bySlug[slug] }
    func apps(for kit: Kit) -> [AppItem] { kit.slugs.compactMap { bySlug[$0] } }

    var newest: [AppItem] { Array(apps.prefix(5)) }
    var appOfDay: AppItem? {
        guard !apps.isEmpty else { return nil }
        let day = Int(Date().timeIntervalSince1970 / 86400)
        let pool = Array(apps.prefix(min(apps.count, 30)))
        guard !pool.isEmpty else { return nil }
        return pool[abs(day) % pool.count]
    }
    var categories: [String] {
        var seen: [String] = []
        for a in apps { for c in a.categories where !seen.contains(c) { seen.append(c) } }
        return seen
    }
    func apps(in cat: String) -> [AppItem] { apps.filter { $0.categories.contains(cat) } }

    func isFav(_ a: AppItem) -> Bool { favs.contains(a.slug) }
    func toggleFav(_ a: AppItem) {
        if let i = favs.firstIndex(of: a.slug) { favs.remove(at: i) } else { favs.insert(a.slug, at: 0) }
        UserDefaults.standard.set(favs, forKey: "tk.favs")
    }
    var favApps: [AppItem] { favs.compactMap { bySlug[$0] } }

    func clearCache() {
        for f in ["apps.json", "kits.json", "videos.xml"] { try? FileManager.default.removeItem(at: Self.cacheURL(f)) }
        ImageCache.shared.clear()
    }

    // MARK: files
    static func cacheURL(_ name: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("tk", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(name)
    }
    static func readCache(_ name: String) -> Data? { try? Data(contentsOf: cacheURL(name)) }
    static func writeCache(_ name: String, _ d: Data) { try? d.write(to: cacheURL(name), options: .atomic) }
    static func bundled(_ name: String, _ ext: String) -> Data? {
        guard let u = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
        return try? Data(contentsOf: u)
    }

    /// CI ke liye: home tak pahunche to ek marker file.
    func markHomeReached() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let s = "home_reached \(ISO8601DateFormatter().string(from: Date())) apps=\(apps.count) kits=\(kits.count) videos=\(videos.count) source=\(source.rawValue)\n"
        try? s.data(using: .utf8)?.write(to: docs.appendingPathComponent("tk_home_reached.txt"), options: .atomic)
    }
}

// MARK: - Image cache (memory + disk)

final class ImageCache {
    static let shared = ImageCache()
    private let mem = NSCache<NSString, UIImage>()
    private let dir: URL
    private init() {
        mem.countLimit = 300
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        dir = base.appendingPathComponent("tkimg", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    private func key(_ url: URL) -> String {
        let s = url.absoluteString
        var h: UInt64 = 1469598103934665603
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return String(h, radix: 16)
    }
    func cached(_ url: URL) -> UIImage? {
        let k = key(url)
        if let i = mem.object(forKey: k as NSString) { return i }
        if let d = try? Data(contentsOf: dir.appendingPathComponent(k)), let i = UIImage(data: d) {
            mem.setObject(i, forKey: k as NSString); return i
        }
        return nil
    }
    func load(_ url: URL) async -> UIImage? {
        if let i = cached(url) { return i }
        if Config.offline { return nil }
        do {
            let (d, r) = try await URLSession.shared.data(from: url)
            guard let h = r as? HTTPURLResponse, (200..<300).contains(h.statusCode), let img = UIImage(data: d) else { return nil }
            let k = key(url)
            mem.setObject(img, forKey: k as NSString)
            try? d.write(to: dir.appendingPathComponent(k), options: .atomic)
            return img
        } catch { return nil }
    }
    func clear() {
        mem.removeAllObjects()
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
}
