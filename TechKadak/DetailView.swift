import SwiftUI
import UIKit

struct AppDetailView: View {
    let app: AppItem
    @EnvironmentObject var store: Store
    @EnvironmentObject var theme: ThemeStore
    @Environment(\.openURL) private var openURL
    @State private var appear = false
    @State private var shareItems: [Any]? = nil
    @State private var makingPoster = false

    var body: some View {
        let p = theme.p
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                // header
                HStack(alignment: .top, spacing: 16) {
                    AppIconView(app: app, size: 96)
                        .shadow(color: p.isGlass ? Palette.lime.opacity(0.35) : .black.opacity(0.25), radius: 18, y: 8)
                        .scaleEffect(appear ? 1 : 0.6)
                        .rotationEffect(.degrees(appear ? 0 : -12))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(app.name).font(TKFont.display(24)).foregroundColor(p.text).fixedSize(horizontal: false, vertical: true)
                        Text(app.categories.map(Cat.short).joined(separator: " • ")).font(TKFont.body(13)).foregroundColor(p.muted)
                        HStack(spacing: 6) {
                            Pill(text: app.pricing, filled: app.pricing.lowercased() == "free")
                            AvailabilityBadge(app: app)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)

                // actions
                HStack(spacing: 10) {
                    GetButton(app: app, compact: false)
                    Button { Haptics.tap(); withAnimation(.tkBouncy) { store.toggleFav(app) } } label: {
                        Image(systemName: store.isFav(app) ? "heart.fill" : "heart")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(store.isFav(app) ? Color(hex: 0xFF4D6D) : p.text)
                            .scaleEffect(store.isFav(app) ? 1.12 : 1)
                            .frame(width: 52, height: 52)
                            .card(26)
                    }.buttonStyle(PressScale(scale: 0.88))
                    Button { sharePoster() } label: {
                        ZStack {
                            if makingPoster { ProgressView().tint(p.text) }
                            else { Image(systemName: "square.and.arrow.up").font(.system(size: 19, weight: .bold)).foregroundColor(p.text) }
                        }
                        .frame(width: 52, height: 52)
                        .card(26)
                    }.buttonStyle(PressScale(scale: 0.88))
                }
                .padding(.horizontal, 18)

                if app.availability == .android || app.availability == .pc {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill").foregroundColor(p.lime)
                        Text(app.availability == .android
                             ? "Ye app Android ke liye hai. iPhone pe install nahi hoga — button app ka official page kholta hai, kisi Android phone pe bhej sakte ho."
                             : "Ye app PC/laptop ke liye hai. Official site khol ke computer pe download karo.")
                            .font(TKFont.body(13)).foregroundColor(p.muted)
                    }
                    .padding(14).card(16)
                    .padding(.horizontal, 18)
                }

                section("Kya karta hai") {
                    Text(app.what).font(TKFont.body(16)).foregroundColor(p.text).fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 0) {
                    infoRow("Price", app.priceNote ?? app.pricing)
                    if let l = app.limit { divider; infoRow("Limit", l) }
                    if let pl = app.platforms { divider; infoRow("Platforms", pl) }
                    if let r = app.replaces, !r.lowercased().contains("camscanner") { divider; infoRow("Kiski jagah", r) }
                    if let v = app.verified { divider; infoRow("Check kiya", Parse.prettyDate(v)) }
                    if !app.added.isEmpty { divider; infoRow("Add hua", Parse.prettyDate(app.added)) }
                }
                .card(20)
                .padding(.horizontal, 18)

                if !app.iosLinks.isEmpty {
                    section("Official links") {
                        VStack(spacing: 8) {
                            ForEach(app.iosLinks) { l in
                                Button { Haptics.tap(); openURL(l.url) } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: icon(for: l)).font(.system(size: 15, weight: .bold)).foregroundColor(Palette.ink)
                                            .frame(width: 34, height: 34).background(Circle().fill(Palette.lime))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(l.label).font(TKFont.bodyBold(15)).foregroundColor(p.text)
                                            Text(l.url.host ?? l.url.absoluteString).font(TKFont.body(12)).foregroundColor(p.faint).lineLimit(1)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .bold)).foregroundColor(p.muted)
                                    }
                                    .padding(12).card(16)
                                }.buttonStyle(PressScale(scale: 0.97))
                            }
                        }
                    }
                }

                let vids: [Video] = app.videoIds.map { id in store.videos.first(where: { $0.id == id }) ?? Video(id: id, title: "\(app.name) — Tech Kadak video", published: "") }
                if !vids.isEmpty {
                    section("Tech Kadak video") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) { ForEach(vids) { v in VideoCard(video: v, width: 260) } }
                        }
                    }
                }

                if let page = app.pageURL {
                    Button { openURL(page) } label: {
                        Label("techkadak.github.io pe poori jaankari", systemImage: "globe")
                            .font(TKFont.bodyBold(13)).foregroundColor(p.muted)
                    }
                    .padding(.horizontal, 18)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(app.name)
        .onAppear { withAnimation(.tkBouncy.delay(0.05)) { appear = true } }
        .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) {
            ShareSheet(items: shareItems ?? [])
                .presentationDetents([.medium, .large])
        }
    }

    private var divider: some View { Rectangle().fill(theme.p.stroke.opacity(0.5)).frame(height: 1).padding(.leading, 16) }

    private func infoRow(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).font(TKFont.body(14)).foregroundColor(theme.p.muted).frame(width: 96, alignment: .leading)
            Text(v).font(TKFont.bodyBold(14)).foregroundColor(theme.p.text).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(TKFont.display(16)).foregroundColor(theme.p.text)
            c()
        }
        .padding(.horizontal, 18)
    }

    private func icon(for l: AppLink) -> String {
        let s = l.label.lowercased()
        if s.contains("github") { return "chevron.left.forwardslash.chevron.right" }
        if s.contains("app store") { return "bag.fill" }
        if s.contains("doc") || s.contains("faq") { return "book.fill" }
        if s.contains("whatsapp") { return "message.fill" }
        return "globe"
    }

    @MainActor
    private func sharePoster() {
        guard !makingPoster else { return }
        Haptics.tap()
        makingPoster = true
        Task { @MainActor in
            var icon: UIImage? = nil
            if let u = app.iconURL { icon = await ImageCache.shared.load(u) }
            let poster = PosterView(app: app, icon: icon)
            let r = ImageRenderer(content: poster)
            r.scale = 1
            let text = "\(app.name) — \(app.what)\nFree apps ke liye Tech Kadak: \(Config.website)"
            var items: [Any] = [text]
            if let img = r.uiImage { items.insert(img, at: 0) }
            makingPoster = false
            shareItems = items
        }
    }
}

/// Status / story poster (1080x1920) — Android ke poster jaisa.
struct PosterView: View {
    let app: AppItem
    let icon: UIImage?
    var body: some View {
        ZStack {
            Color(hex: 0x070A07)
            Circle().fill(Palette.lime.opacity(0.45)).frame(width: 1100).blur(radius: 220).offset(x: 300, y: -700)
            Circle().fill(Palette.lime.opacity(0.18)).frame(width: 900).blur(radius: 200).offset(x: -400, y: 700)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 22) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Palette.lime)
                        Text("TK").font(TKFont.display(46)).foregroundColor(Palette.ink)
                    }.frame(width: 110, height: 110)
                    Text("TECH KADAK").font(TKFont.display(58)).foregroundColor(.white)
                }
                Spacer().frame(height: 170)
                Text("AAJ KA FREE APP").font(TKFont.display(34)).foregroundColor(Palette.ink)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(Capsule().fill(Palette.lime))
                Spacer().frame(height: 60)
                ZStack {
                    if let i = icon { Image(uiImage: i).resizable().scaledToFill() }
                    else {
                        Palette.lime
                        Text(app.initials).font(TKFont.display(120)).foregroundColor(Palette.ink)
                    }
                }
                .frame(width: 320, height: 320)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 80, style: .continuous))
                .shadow(color: Palette.lime.opacity(0.5), radius: 60)
                Spacer().frame(height: 60)
                Text(app.name).font(TKFont.display(96)).foregroundColor(.white).lineLimit(2).minimumScaleFactor(0.5)
                Spacer().frame(height: 26)
                Text(app.what).font(TKFont.body(44)).foregroundColor(.white.opacity(0.8)).lineLimit(5).fixedSize(horizontal: false, vertical: true)
                Spacer().frame(height: 40)
                HStack(spacing: 16) {
                    Text(app.pricing.uppercased()).font(TKFont.display(32)).foregroundColor(Palette.ink)
                        .padding(.horizontal, 24).padding(.vertical, 12).background(Capsule().fill(Palette.lime))
                    if let pl = app.platforms {
                        Text(pl).font(TKFont.bodyBold(32)).foregroundColor(.white)
                            .padding(.horizontal, 24).padding(.vertical, 12).background(Capsule().fill(Color.white.opacity(0.14)))
                            .lineLimit(1)
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Download: techkadak.github.io").font(TKFont.display(38)).foregroundColor(Palette.lime)
                    Text("Follow @techkadak").font(TKFont.bodyBold(34)).foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(90)
            .frame(width: 1080, height: 1920, alignment: .topLeading)
        }
        .frame(width: 1080, height: 1920)
        .clipped()
        .environment(\.colorScheme, .dark)
    }
}
