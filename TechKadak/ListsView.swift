import SwiftUI
import UIKit

struct AppListView: View {
    let title: String
    var subtitle: String? = nil
    let apps: [AppItem]
    var ranked = false
    @EnvironmentObject var theme: ThemeStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let s = subtitle {
                    Text(s).font(TKFont.body(14)).foregroundColor(theme.p.muted).padding(.horizontal, 18).padding(.bottom, 10)
                }
                if apps.isEmpty {
                    EmptyState(emoji: "🫙", title: "Abhi koi app nahi", sub: "Jald hi aayenge.")
                }
                ForEach(Array(apps.enumerated()), id: \.element.slug) { i, a in
                    NavigationLink(value: Route.app(a.slug)) { AppRow(app: a, rank: ranked ? i + 1 : nil) }
                        .buttonStyle(PressScale(scale: 0.98))
                        .transition(.opacity)
                }
            }
            .padding(.vertical, 8)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

struct SearchView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var theme: ThemeStore
    @State private var q = Config.arg("tkSearch") ?? ""
    @State private var cat: String? = nil
    @FocusState private var focused: Bool

    private var results: [AppItem] {
        store.apps.filter { a in a.matches(q) && (cat == nil || a.categories.contains(cat ?? "")) }
    }

    var body: some View {
        let p = theme.p
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundColor(p.muted)
                TextField("Apps search karo… (PDF, video, notes)", text: $q)
                    .font(TKFont.body(16)).foregroundColor(p.text)
                    .focused($focused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !q.isEmpty {
                    Button { withAnimation(.tk) { q = "" } } label: { Image(systemName: "xmark.circle.fill").foregroundColor(p.muted) }
                }
            }
            .padding(.horizontal, 16).frame(height: 52)
            .card(26)
            .padding(.horizontal, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("Sab", nil)
                    ForEach(store.categories, id: \.self) { c in chip(Cat.emoji(c) + " " + Cat.short(c), c) }
                }
                .padding(.horizontal, 18)
            }

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    let r = results
                    if r.isEmpty {
                        EmptyState(emoji: "🔍", title: "Kuch nahi mila", sub: "Dusra shabd try karo — jaise \"pdf\", \"video\", \"notes\".")
                    } else {
                        Text("\(r.count) apps").font(TKFont.body(12)).foregroundColor(p.faint)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.bottom, 4)
                        ForEach(r) { a in
                            NavigationLink(value: Route.app(a.slug)) { AppRow(app: a) }
                                .buttonStyle(PressScale(scale: 0.98))
                        }
                    }
                }
                .animation(.tk, value: q)
                .animation(.tk, value: cat)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(.top, 8)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.large)
    }

    private func chip(_ t: String, _ c: String?) -> some View {
        let on = cat == c
        return Button { Haptics.tap(); withAnimation(.tkBouncy) { cat = c } } label: {
            Text(t).font(TKFont.bodyBold(13))
                .foregroundColor(on ? Palette.ink : theme.p.text)
                .padding(.horizontal, 14).frame(height: 34)
                .background(Capsule().fill(on ? Palette.lime : (theme.p.isGlass ? Color.white.opacity(0.1) : theme.p.surface2)))
        }
        .buttonStyle(PressScale())
    }
}

struct KitsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var theme: ThemeStore
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Ek kaam ke liye poora set. iPhone pe har app ka official link milega — Android-only apps pe saaf likha hai.")
                    .font(TKFont.body(14)).foregroundColor(theme.p.muted)
                    .padding(.horizontal, 18)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(store.kits) { k in
                        NavigationLink(value: Route.kit(k.id)) { KitTile(kit: k, apps: store.apps(for: k)) }
                            .buttonStyle(PressScale())
                    }
                }
                .padding(.horizontal, 18)
                if store.kits.isEmpty { EmptyState(emoji: "🎒", title: "Kits load nahi hue", sub: "Net on karke dobara kholo.") }
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("Kits 🎒")
    }
}

struct KitTile: View {
    let kit: Kit
    let apps: [AppItem]
    @EnvironmentObject var theme: ThemeStore
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(kit.emoji).font(.system(size: 34))
            Text(kit.name).font(TKFont.display(15)).foregroundColor(theme.p.text).lineLimit(1).minimumScaleFactor(0.8)
            Text(kit.tagline).font(TKFont.body(12)).foregroundColor(theme.p.muted).lineLimit(3)
                .frame(height: 48, alignment: .topLeading)
            HStack(spacing: -8) {
                ForEach(apps.prefix(4)) { a in AppIconView(app: a, size: 30) }
                Spacer()
                Image(systemName: "arrow.right.circle.fill").font(.system(size: 22)).foregroundColor(Palette.lime)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(22, strong: true)
    }
}

struct KitDetailView: View {
    let kit: Kit
    @EnvironmentObject var store: Store
    @EnvironmentObject var theme: ThemeStore
    @State private var appear = false
    var body: some View {
        let apps = store.apps(for: kit)
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(kit.emoji).font(.system(size: 54)).scaleEffect(appear ? 1 : 0.4).rotationEffect(.degrees(appear ? 0 : -20))
                    Text(kit.name).font(TKFont.display(28)).foregroundColor(theme.p.text)
                    Text(kit.tagline).font(TKFont.body(15)).foregroundColor(theme.p.muted)
                    Text("\(apps.count) apps • har ek ka official link").font(TKFont.bodyBold(12)).foregroundColor(theme.p.lime)
                }
                .padding(.horizontal, 18)
                Text("iPhone pe ek saath install nahi hota, isliye har app ke saamne uska official link hai. Android-only apps pe \"Android\" likha hai.")
                    .font(TKFont.body(13)).foregroundColor(theme.p.muted)
                    .padding(14).card(16).padding(.horizontal, 18)
                VStack(spacing: 0) {
                    ForEach(Array(apps.enumerated()), id: \.element.slug) { i, a in
                        NavigationLink(value: Route.app(a.slug)) { AppRow(app: a) }
                            .buttonStyle(PressScale(scale: 0.98))
                            .offset(y: appear ? 0 : 30).opacity(appear ? 1 : 0)
                            .animation(.tk.delay(Double(i) * 0.05), value: appear)
                    }
                }
                .padding(.vertical, 6)
                .card(24)
                .padding(.horizontal, 12)
            }
            .padding(.vertical, 8)
        }
        .navigationTitle(kit.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { withAnimation(.tkBouncy) { appear = true } }
    }
}

struct FavsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var theme: ThemeStore
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                if store.favApps.isEmpty {
                    EmptyState(emoji: "🤍", title: "Abhi koi pasand nahi", sub: "Kisi bhi app pe ❤️ dabao — yahan aa jayega.")
                        .padding(.top, 60)
                } else {
                    ForEach(store.favApps) { a in
                        NavigationLink(value: Route.app(a.slug)) { AppRow(app: a) }
                            .buttonStyle(PressScale(scale: 0.98))
                            .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                    }
                }
            }
            .animation(.tk, value: store.favs)
            .padding(.vertical, 8)
        }
        .navigationTitle("Meri Pasand ❤️")
    }
}

struct VideosView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 18) {
                ForEach(store.videos) { v in
                    GeometryReader { g in VideoCard(video: v, width: g.size.width) }
                        .frame(height: (UIScreen.main.bounds.width - 36) * 9 / 16 + 50)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 8)
        }
        .navigationTitle("Tech Kadak Videos")
    }
}
