import SwiftUI

@main
struct TechKadakApp: App {
    @StateObject private var store = Store()
    @StateObject private var theme = ThemeStore()

    init() {
        URLCache.shared = URLCache(memoryCapacity: 20 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            SplashHost {
                RootView()
            }
            .environmentObject(store)
            .environmentObject(theme)
            .preferredColorScheme(theme.p.scheme)
            .tint(Palette.lime)
        }
    }
}

enum TKTab: String, CaseIterable, Hashable {
    case home, search, kits, favs, settings
    var title: String {
        switch self {
        case .home: return "Home"
        case .search: return "Search"
        case .kits: return "Kits"
        case .favs: return "Pasand"
        case .settings: return "Settings"
        }
    }
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .kits: return "square.stack.3d.up.fill"
        case .favs: return "heart.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

enum Route: Hashable {
    case app(String)
    case kit(String)
    case category(String)
    case newApps
    case allApps
    case videos
    case about
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var theme: ThemeStore
    @AppStorage("tk.onboarded") private var onboarded = false
    @State private var tab: TKTab = TKTab(rawValue: Config.arg("tkTab") ?? "") ?? .home
    @State private var paths: [TKTab: NavigationPath] = [:]
    private let forceOnboard = Config.arg("tkOnboard") == "1"
    private let skipOnboard = Config.arg("tkOnboard") == "0"

    var body: some View {
        ZStack {
            if (!onboarded || forceOnboard) && !skipOnboard {
                OnboardingView { withAnimation(.tk) { onboarded = true } }
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
            } else {
                main
                    .transition(.opacity)
            }
        }
    }

    private var main: some View {
        ZStack(alignment: .bottom) {
            ThemedBackground()
            Group {
                switch tab {
                case .home: stack(.home) { HomeView() }
                case .search: stack(.search) { SearchView() }
                case .kits: stack(.kits) { KitsView() }
                case .favs: stack(.favs) { FavsView() }
                case .settings: stack(.settings) { SettingsView() }
                }
            }
            TKTabBar(tab: $tab) { t in
                // dobara tap = upar/root pe wapas
                if t == tab { paths[t] = NavigationPath() }
            }
        }
        .environment(\.switchTab, { t in withAnimation(.tkBouncy) { tab = t } })
        .task {
            await store.refresh()
            store.markHomeReached()
        }
        .onAppear {
            store.markHomeReached()
            if let slug = Config.arg("tkOpenApp") { var p = NavigationPath(); p.append(Route.app(slug)); paths[tab] = p }
            if let k = Config.arg("tkOpenKit") { var p = NavigationPath(); p.append(Route.kit(k)); paths[tab] = p }
        }
    }

    private func binding(_ t: TKTab) -> Binding<NavigationPath> {
        Binding(get: { paths[t] ?? NavigationPath() }, set: { paths[t] = $0 })
    }

    private func stack<V: View>(_ t: TKTab, @ViewBuilder _ root: () -> V) -> some View {
        NavigationStack(path: binding(t)) {
            root()
                .tkScreen()
                .navigationDestination(for: Route.self) { r in destination(r).tkScreen() }
        }
    }

    @ViewBuilder
    private func destination(_ r: Route) -> some View {
        switch r {
        case .app(let slug):
            if let a = store.app(slug) { AppDetailView(app: a) } else { EmptyState(emoji: "🤷", title: "App nahi mila", sub: "Shayad list update ho gayi hai.") }
        case .kit(let id):
            if let k = store.kits.first(where: { $0.id == id }) { KitDetailView(kit: k) } else { EmptyState(emoji: "🎒", title: "Kit nahi mila", sub: "") }
        case .category(let c): AppListView(title: Cat.emoji(c) + " " + Cat.short(c), subtitle: Cat.tagline(c), apps: store.apps(in: c))
        case .newApps: AppListView(title: "Naye apps 🔥", subtitle: "Sabse naye upar", apps: store.apps, ranked: false)
        case .allApps: AppListView(title: "Sab apps", subtitle: "\(store.apps.count) apps", apps: store.apps)
        case .videos: VideosView()
        case .about: AboutView()
        }
    }
}

/// Floating glass tab bar — har theme me.
struct TKTabBar: View {
    @Binding var tab: TKTab
    var reselect: (TKTab) -> Void
    @EnvironmentObject var theme: ThemeStore
    @Namespace private var ns

    var body: some View {
        let p = theme.p
        HStack(spacing: 4) {
            ForEach(TKTab.allCases, id: \.self) { t in
                Button {
                    Haptics.tap()
                    reselect(t)
                    withAnimation(.tkBouncy) { tab = t }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: t.icon).font(.system(size: 18, weight: .semibold))
                            .scaleEffect(tab == t ? 1.1 : 1)
                        Text(t.title).font(TKFont.bodyBold(10))
                    }
                    .foregroundColor(tab == t ? Palette.ink : p.muted)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background {
                        if tab == t {
                            Capsule().fill(Palette.lime)
                                .shadow(color: Palette.lime.opacity(p.isGlass ? 0.6 : 0.25), radius: 10)
                                .matchedGeometryEffect(id: "tabpill", in: ns)
                        }
                    }
                }
                .buttonStyle(PressScale(scale: 0.9))
            }
        }
        .padding(6)
        .background {
            Capsule().fill(.ultraThinMaterial)
            Capsule().fill(p.isLight ? Color.white.opacity(0.6) : (p.isGlass ? Color.white.opacity(0.06) : Color.black.opacity(0.35)))
        }
        .overlay(Capsule().strokeBorder(p.isLight ? Color.black.opacity(0.08) : Color.white.opacity(p.isGlass ? 0.3 : 0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 20, y: 8)
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }
}

private struct SwitchTabKey: EnvironmentKey {
    static let defaultValue: (TKTab) -> Void = { _ in }
}
extension EnvironmentValues {
    var switchTab: (TKTab) -> Void {
        get { self[SwitchTabKey.self] }
        set { self[SwitchTabKey.self] = newValue }
    }
}
