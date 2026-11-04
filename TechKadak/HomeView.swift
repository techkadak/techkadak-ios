import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var theme: ThemeStore
    @Environment(\.switchTab) private var switchTab
    @Environment(\.openURL) private var openURL
    @State private var appeared = false

    var body: some View {
        let p = theme.p
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 22) {
                header
                searchPill
                if store.offlineNote {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                        Text("Net nahi hai — saved list dikha rahe hain. Neeche kheench ke refresh karo.")
                            .font(TKFont.body(12))
                    }
                    .foregroundColor(p.muted)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .card(14)
                    .padding(.horizontal, 18)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                if store.apps.isEmpty {
                    EmptyState(emoji: "📡", title: "Apps load nahi hue", sub: "Net on karke neeche kheencho.")
                } else {
                    hero
                    chips
                    newApps
                    if !store.kits.isEmpty { kits }
                    if !store.videos.isEmpty { videos }
                    if !store.favApps.isEmpty { favs }
                    ForEach(store.categories, id: \.self) { c in categoryRow(c) }
                    footer
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 20)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
        }
        .refreshable { await store.refresh() }
        .navigationBarHidden(true)
        .animation(.tk, value: store.offlineNote)
        .onAppear { withAnimation(.tk.delay(0.05)) { appeared = true } }
    }

    // MARK: header
    private var header: some View {
        let p = theme.p
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Palette.lime)
                Text("TK").font(TKFont.display(17)).foregroundColor(Palette.ink)
            }
            .frame(width: 46, height: 46)
            .shadow(color: Palette.lime.opacity(p.isGlass ? 0.55 : 0.0), radius: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text("TECH KADAK").font(TKFont.display(20)).foregroundColor(p.text)
                Text("Free apps ka adda • \(store.apps.count) apps").font(TKFont.body(12)).foregroundColor(p.muted)
            }
            Spacer()
            Button {
                Haptics.tap()
                withAnimation(.tk) { theme.mode = (theme.mode == .light) ? .dark : (theme.mode == .glass ? .light : .glass) }
            } label: {
                Image(systemName: theme.mode == .glass ? "sun.max.fill" : (theme.mode == .light ? "moon.fill" : "sparkles"))
                    .font(.system(size: 16, weight: .bold)).foregroundColor(p.text)
                    .frame(width: 42, height: 42)
                    .card(21)
            }
            .buttonStyle(PressScale())
        }
        .padding(.horizontal, 18)
    }

    private var searchPill: some View {
        Button { switchTab(.search) } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .semibold))
                Text("Apps search karo…").font(TKFont.body(15))
                Spacer()
            }
            .foregroundColor(theme.p.muted)
            .padding(.horizontal, 16).frame(height: 50)
            .card(25)
        }
        .buttonStyle(PressScale(scale: 0.98))
        .padding(.horizontal, 18)
    }

    // MARK: hero
    private var heroItems: [AppItem] {
        var out: [AppItem] = []
        if let d = store.appOfDay { out.append(d) }
        for a in store.newest where !out.contains(a) { out.append(a) }
        return Array(out.prefix(5))
    }

    private var hero: some View {
        TabView {
            ForEach(Array(heroItems.enumerated()), id: \.element.slug) { i, a in
                NavigationLink(value: Route.app(a.slug)) {
                    FeaturedCard(app: a, badge: i == 0 ? "AAJ KA APP" : "NAYA APP")
                }
                .buttonStyle(PressScale(scale: 0.97))
                .padding(.horizontal, 18)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 236)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                NavigationLink(value: Route.allApps) { chip("Sab apps", "square.grid.2x2.fill", true) }
                ForEach(store.categories, id: \.self) { c in
                    NavigationLink(value: Route.category(c)) { chip(Cat.emoji(c) + " " + Cat.short(c), nil, false) }
                }
            }
            .padding(.horizontal, 18)
        }
        .buttonStyle(PressScale())
    }

    private func chip(_ t: String, _ icon: String?, _ on: Bool) -> some View {
        HStack(spacing: 6) {
            if let i = icon { Image(systemName: i).font(.system(size: 12, weight: .bold)) }
            Text(t).font(TKFont.bodyBold(13))
        }
        .foregroundColor(on ? Palette.ink : theme.p.text)
        .padding(.horizontal, 14).frame(height: 36)
        .background { if on { Capsule().fill(Palette.lime) } }
        .modifier(ChipBG(on: on))
    }

    // MARK: sections
    private var newApps: some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink(value: Route.newApps) {
                SectionHeader(title: "Naye Apps 🔥", subtitle: "Bot roz naya app daalta hai — sabse naye upar")
            }.buttonStyle(.plain)
            VStack(spacing: 0) {
                ForEach(store.newest) { a in
                    NavigationLink(value: Route.app(a.slug)) {
                        ZStack(alignment: .topLeading) {
                            AppRow(app: a)
                            if a.added == store.newest.first?.added {
                                Text("NAYA").font(TKFont.display(8)).foregroundColor(Palette.ink)
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Capsule().fill(Palette.lime))
                                    .offset(x: 14, y: 4)
                            }
                        }
                    }
                    .buttonStyle(PressScale(scale: 0.98))
                }
            }
            .padding(.vertical, 6)
            .card(24)
            .padding(.horizontal, 12)
        }
    }

    private var kits: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { switchTab(.kits) } label: {
                SectionHeader(title: "Kits 🎒", subtitle: "Ek kaam, poora set — official links ke saath")
            }.buttonStyle(.plain)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.kits) { k in
                        NavigationLink(value: Route.kit(k.id)) { KitCard(kit: k, apps: store.apps(for: k)) }
                            .buttonStyle(PressScale())
                    }
                }
                .padding(.horizontal, 18).padding(.vertical, 4)
            }
        }
    }

    private var videos: some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink(value: Route.videos) {
                SectionHeader(title: "Tech Kadak Videos ▶️", subtitle: "Rohit ke naye tutorials")
            }.buttonStyle(.plain)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.videos.prefix(10)) { v in VideoCard(video: v, width: 250) }
                }
                .padding(.horizontal, 18).padding(.vertical, 4)
            }
        }
    }

    private var favs: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { switchTab(.favs) } label: {
                SectionHeader(title: "Meri Pasand ❤️", subtitle: "\(store.favApps.count) apps saved")
            }.buttonStyle(.plain)
            iconRow(store.favApps)
        }
    }

    private func categoryRow(_ c: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink(value: Route.category(c)) {
                SectionHeader(title: Cat.emoji(c) + " " + Cat.short(c), subtitle: Cat.tagline(c))
            }.buttonStyle(.plain)
            iconRow(Array(store.apps(in: c).prefix(12)))
        }
    }

    private func iconRow(_ apps: [AppItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(apps) { a in
                    NavigationLink(value: Route.app(a.slug)) {
                        VStack(alignment: .leading, spacing: 6) {
                            AppIconView(app: a, size: 78)
                            Text(a.name).font(TKFont.bodyBold(13)).foregroundColor(theme.p.text).lineLimit(1)
                            Text(a.pricing).font(TKFont.body(11)).foregroundColor(theme.p.lime)
                        }
                        .frame(width: 80, alignment: .leading)
                    }
                    .buttonStyle(PressScale())
                }
            }
            .padding(.horizontal, 18)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Official links only", systemImage: "checkmark.shield.fill")
                .font(TKFont.bodyBold(13)).foregroundColor(theme.p.lime)
            Text("Tech Kadak khud koi app host nahi karta. GET dabane pe app ka official page / website khulta hai. iPhone pe dusre apps yahan se install nahi hote — Android-only apps pe \"Android ke liye\" likha hai.")
                .font(TKFont.body(12)).foregroundColor(theme.p.muted)
        }
        .padding(16)
        .card(18)
        .padding(.horizontal, 18)
    }
}

private struct ChipBG: ViewModifier {
    let on: Bool
    @EnvironmentObject var theme: ThemeStore
    @ViewBuilder
    func body(content: Content) -> some View {
        if on { content } else { content.card(18) }
    }
}

struct FeaturedCard: View {
    let app: AppItem
    let badge: String
    @EnvironmentObject var theme: ThemeStore
    var body: some View {
        let p = theme.p
        ZStack(alignment: .bottomLeading) {
            // lime glow wala background
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: p.isLight ? [Color(hex: 0xE9FFD0), Color(hex: 0xFFFFFF)] : [Color(hex: 0x1F3A0A), Color(hex: 0x0B120B)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().fill(Palette.lime.opacity(p.isLight ? 0.35 : 0.28)).frame(width: 220).blur(radius: 50).offset(x: 190, y: -110)
            AppIconView(app: app, size: 92)
                .rotationEffect(.degrees(-8))
                .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(22)
            VStack(alignment: .leading, spacing: 8) {
                Text(badge).font(TKFont.display(11)).foregroundColor(Palette.ink)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Palette.lime))
                Text(app.name).font(TKFont.display(24)).foregroundColor(p.text).lineLimit(1).minimumScaleFactor(0.7)
                Text(app.what).font(TKFont.body(13)).foregroundColor(p.muted).lineLimit(2)
                    .frame(maxWidth: 250, alignment: .leading)
                HStack(spacing: 6) {
                    Pill(text: app.pricing, filled: false)
                    AvailabilityBadge(app: app)
                }
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(p.isGlass ? Color.white.opacity(0.3) : Palette.lime.opacity(0.25), lineWidth: 1))
        .frame(height: 210)
    }
}

struct KitCard: View {
    let kit: Kit
    let apps: [AppItem]
    @EnvironmentObject var theme: ThemeStore
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(kit.emoji).font(.system(size: 30))
                Spacer()
                Text("\(apps.count) apps").font(TKFont.bodyBold(11)).foregroundColor(Palette.ink)
                    .padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(Palette.lime))
            }
            Text(kit.name).font(TKFont.display(16)).foregroundColor(theme.p.text).lineLimit(1)
            Text(kit.tagline).font(TKFont.body(12)).foregroundColor(theme.p.muted).lineLimit(2)
                .frame(height: 32, alignment: .topLeading)
            HStack(spacing: -10) {
                ForEach(apps.prefix(5)) { a in
                    AppIconView(app: a, size: 34)
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(theme.p.bg, lineWidth: 2))
                }
            }
        }
        .padding(16)
        .frame(width: 210, alignment: .leading)
        .card(24, strong: true)
    }
}

struct VideoCard: View {
    let video: Video
    var width: CGFloat = 250
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var theme: ThemeStore
    var body: some View {
        Button {
            Haptics.tap()
            if let u = video.watchURL { openURL(u) }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RemoteImage(url: video.thumbURL)
                        .frame(width: width, height: width * 9 / 16)
                        .clipped()
                    Image(systemName: "play.fill").font(.system(size: 18, weight: .bold)).foregroundColor(Palette.ink)
                        .frame(width: 46, height: 46).background(Circle().fill(Palette.lime))
                        .shadow(color: .black.opacity(0.4), radius: 8)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text(video.title).font(TKFont.bodyBold(13)).foregroundColor(theme.p.text).lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: width, alignment: .leading)
            }
        }
        .buttonStyle(PressScale())
    }
}
