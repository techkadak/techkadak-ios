import Foundation

struct AppLink: Hashable, Identifiable {
    let label: String
    let url: URL
    var id: String { label + url.absoluteString }
}

enum IOSAvailability: Equatable {
    case iphone      // iPhone/iOS pe available
    case web         // browser me chalta hai (iPhone pe bhi)
    case pc          // sirf computer
    case android     // sirf Android
}

struct AppItem: Identifiable, Hashable {
    let slug: String
    let name: String
    let categories: [String]
    let what: String
    let pricing: String
    let priceNote: String?
    let limit: String?
    let platforms: String?
    let replaces: String?
    let links: [AppLink]
    let icon: String?
    let added: String
    let verified: String?
    let videoIds: [String]

    var id: String { slug }
    static func == (a: AppItem, b: AppItem) -> Bool { a.slug == b.slug }
    func hash(into h: inout Hasher) { h.combine(slug) }

    var iconURL: URL? {
        guard let icon = icon, !icon.isEmpty else { return nil }
        if icon.hasPrefix("https://") { return URL(string: icon) }
        let path = icon.hasPrefix("/") ? String(icon.dropFirst()) : icon
        return URL(string: Config.siteBase + "/" + path)
    }
    var pageURL: URL? { URL(string: Config.siteBase + "/apps/\(slug).html") }

    var initials: String {
        let parts = name.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "_" }).prefix(2)
        let s = parts.compactMap { $0.first.map { String($0).uppercased() } }.joined()
        return s.isEmpty ? "?" : s
    }

    var availability: IOSAvailability {
        let p = (platforms ?? "").lowercased()
        if p.contains("iphone") || p.contains("ios") || appStoreLink != nil { return .iphone }
        if p.contains("web") || p.contains("browser") { return .web }
        if p.contains("android") { return .android }
        if p.contains("windows") || p.contains("mac") || p.contains("linux") || p.contains("pc") || p.contains("laptop") { return .pc }
        if p.isEmpty, links.contains(where: { $0.label.lowercased().contains("web") }) { return .web }
        return .android
    }

    var appStoreLink: AppLink? {
        links.first { $0.url.host?.contains("apps.apple.com") == true || $0.label.lowercased().contains("app store") }
    }

    /// iPhone pe kaam ke links (Android stores hata ke). Kuch na bache to sab.
    var iosLinks: [AppLink] {
        let useless = ["play store", "google play", "f-droid", "download"]
        let l = links.filter { link in
            let lab = link.label.lowercased()
            if useless.contains(lab) { return false }
            if let h = link.url.host, h.contains("play.google.com") || h.contains("f-droid.org") { return false }
            return true
        }
        return l.isEmpty ? links : l
    }

    /// "Get" dabane pe kya khule: App Store > website > pehla link > Tech Kadak page.
    var officialURL: URL? {
        if let a = appStoreLink { return a.url }
        let order = ["website", "web app", "github", "docs"]
        for o in order { if let l = iosLinks.first(where: { $0.label.lowercased() == o }) { return l.url } }
        return iosLinks.first?.url ?? links.first?.url ?? pageURL
    }

    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return true }
        let hay = ([name, what, pricing, replaces ?? "", platforms ?? ""] + categories).joined(separator: " ").lowercased()
        return q.split(separator: " ").allSatisfy { hay.contains($0) }
    }
}

struct Kit: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let tagline: String
    let slugs: [String]
}

struct Video: Identifiable, Hashable {
    let id: String
    let title: String
    let published: String
    var thumbURL: URL? { URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg") }
    var watchURL: URL? { URL(string: "https://www.youtube.com/watch?v=\(id)") }
}

// MARK: - Lenient parsing (kabhi crash nahi — kharab data skip)

enum Parse {
    static func str(_ o: [String: Any], _ k: String) -> String? {
        guard let v = o[k] else { return nil }
        var s: String?
        if let x = v as? String { s = x } else if let n = v as? NSNumber { s = n.stringValue }
        let t = s?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (t.isEmpty || t == "null") ? nil : t
    }

    static func apps(_ data: Data) -> [AppItem]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = root["apps"] as? [Any] else { return nil }
        var out: [(Int, AppItem)] = []
        var seen = Set<String>()
        for (i, any) in arr.enumerated() {
            guard let o = any as? [String: Any], let slug = str(o, "slug"), let name = str(o, "name"), !seen.contains(slug) else { continue }
            seen.insert(slug)
            var cats: [String] = []
            if let a = o["category"] as? [Any] { cats = a.compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
            else if let c = str(o, "category") { cats = [c] }
            var links: [AppLink] = []
            if let a = o["links"] as? [Any] {
                for l in a {
                    guard let lo = l as? [String: Any], let u = str(lo, "url"), u.hasPrefix("https://"), let url = URL(string: u) else { continue }
                    links.append(AppLink(label: str(lo, "label") ?? "Link", url: url))
                }
            }
            let vids: [String] = (o["videos"] as? [Any])?.compactMap { v in
                guard let s = v as? String, s.count == 11 else { return nil }
                return s.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" } ? s : nil
            } ?? []
            let item = AppItem(slug: slug, name: name, categories: cats, what: str(o, "what") ?? "",
                               pricing: str(o, "pricing") ?? "Free", priceNote: str(o, "priceNote"), limit: str(o, "limit"),
                               platforms: str(o, "platforms"), replaces: str(o, "replaces"), links: links, icon: str(o, "icon"),
                               added: str(o, "added") ?? "", verified: str(o, "verified"), videoIds: vids)
            out.append((i, item))
        }
        if out.isEmpty { return nil }
        out.sort { a, b in a.1.added != b.1.added ? a.1.added > b.1.added : a.0 < b.0 }
        return out.map { $0.1 }
    }

    static func kits(_ data: Data) -> [Kit]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = root["kits"] as? [Any] else { return nil }
        let kits: [Kit] = arr.compactMap { any in
            guard let o = any as? [String: Any], let id = str(o, "id"), let name = str(o, "name") else { return nil }
            let slugs = (o["apps"] as? [Any])?.compactMap { $0 as? String } ?? []
            if slugs.isEmpty { return nil }
            return Kit(id: id, name: name, emoji: str(o, "emoji") ?? "📦", tagline: str(o, "tagline") ?? "", slugs: slugs)
        }
        return kits.isEmpty ? nil : kits
    }

    static func prettyDate(_ iso: String?) -> String {
        guard let iso = iso else { return "" }
        let p = iso.prefix(10).split(separator: "-")
        let months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        guard p.count == 3, let m = Int(p[1]), let d = Int(p[2]), (1...12).contains(m) else { return iso }
        return "\(d) \(months[m - 1]) \(p[0])"
    }
}

/// YouTube RSS (Atom) parser.
final class VideoFeedParser: NSObject, XMLParserDelegate {
    private var videos: [Video] = []
    private var inEntry = false
    private var cur = ""
    private var vid = "", title = "", published = ""

    static func parse(_ data: Data) -> [Video]? {
        let p = VideoFeedParser()
        let x = XMLParser(data: data)
        x.delegate = p
        _ = x.parse()
        return p.videos.isEmpty ? nil : p.videos
    }

    func parser(_ parser: XMLParser, didStartElement el: String, namespaceURI: String?, qualifiedName q: String?, attributes: [String: String] = [:]) {
        cur = ""
        if el == "entry" { inEntry = true; vid = ""; title = ""; published = "" }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { cur += string }
    func parser(_ parser: XMLParser, didEndElement el: String, namespaceURI: String?, qualifiedName q: String?) {
        let v = cur.trimmingCharacters(in: .whitespacesAndNewlines)
        if inEntry {
            switch el {
            case "yt:videoId", "videoId": vid = v
            case "title": if title.isEmpty { title = v }
            case "published": published = v
            case "entry":
                inEntry = false
                if vid.count == 11 { videos.append(Video(id: vid, title: title.isEmpty ? "Tech Kadak video" : title, published: published)) }
            default: break
            }
        }
        cur = ""
    }
}
