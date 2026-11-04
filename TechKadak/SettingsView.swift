import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var theme: ThemeStore
    @AppStorage("tk.onboarded") private var onboarded = true
    @State private var cleared = false

    var body: some View {
        let p = theme.p
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Theme").font(TKFont.display(17)).foregroundColor(p.text).padding(.horizontal, 18)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(ThemeMode.allCases) { m in ThemeTile(mode: m, selected: theme.mode == m) {
                            Haptics.tap()
                            withAnimation(.tk) { theme.mode = m }
                        } }
                    }
                    .padding(.horizontal, 18)
                }

                group("App") {
                    row("arrow.clockwise", "Apps refresh karo", store.loading ? "Load ho raha hai…" : sourceText) {
                        Task { await store.refresh() }
                    }
                    line
                    row("sparkles.rectangle.stack", "Intro dobara dekho", "Shuruaat wali screens") {
                        withAnimation(.tk) { onboarded = false }
                    }
                    line
                    row("trash", "Cache saaf karo", cleared ? "Saaf ho gaya ✓" : "Icons aur saved list hatao") {
                        store.clearCache(); withAnimation(.tk) { cleared = true }
                    }
                }

                group("Tech Kadak") {
                    NavigationLink(value: Route.about) {
                        rowLabel("info.circle", "About", "Developer, version, links")
                    }.buttonStyle(PressScale(scale: 0.98))
                    line
                    link("camera", "Instagram", "@techkadak", Config.instagram)
                    line
                    link("play.rectangle", "YouTube", "Tech Kadak channel", Config.youtube)
                    line
                    link("paperplane", "Telegram", "t.me/techkadak", Config.telegram)
                    line
                    link("globe", "Website", "techkadak.github.io", Config.website)
                }

                Text("Tech Kadak v\(Config.version) • iPhone • Made in India 🇮🇳")
                    .font(TKFont.body(12)).foregroundColor(p.faint)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("Settings")
    }

    private var sourceText: String {
        switch store.source {
        case .live: return "Live list • \(store.apps.count) apps"
        case .cache: return "Saved list • \(store.apps.count) apps"
        case .bundled: return "Built-in list • \(store.apps.count) apps"
        case .none: return "Koi list nahi"
        }
    }

    private var line: some View { Rectangle().fill(theme.p.stroke.opacity(0.5)).frame(height: 1).padding(.leading, 60) }

    private func group<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(TKFont.display(17)).foregroundColor(theme.p.text).padding(.horizontal, 18)
            VStack(spacing: 0) { c() }.card(22).padding(.horizontal, 18)
        }
    }

    private func rowLabel(_ icon: String, _ t: String, _ s: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundColor(Palette.ink)
                .frame(width: 32, height: 32).background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.lime))
            VStack(alignment: .leading, spacing: 2) {
                Text(t).font(TKFont.bodyBold(15)).foregroundColor(theme.p.text)
                Text(s).font(TKFont.body(12)).foregroundColor(theme.p.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundColor(theme.p.faint)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func row(_ icon: String, _ t: String, _ s: String, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: { rowLabel(icon, t, s) }.buttonStyle(PressScale(scale: 0.98))
    }

    private func link(_ icon: String, _ t: String, _ s: String, _ url: String) -> some View {
        Group {
            if let u = URL(string: url) {
                Link(destination: u) { rowLabel(icon, t, s) }.buttonStyle(PressScale(scale: 0.98))
            }
        }
    }
}

struct ThemeTile: View {
    let mode: ThemeMode
    let selected: Bool
    let action: () -> Void
    @EnvironmentObject var theme: ThemeStore

    var body: some View {
        let pal = Palette.of(mode)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    preview(pal)
                    if selected {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundColor(Palette.lime)
                            .background(Circle().fill(Palette.ink).padding(3))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .topTrailing)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(selected ? Palette.lime : Color.gray.opacity(0.3), lineWidth: selected ? 2.5 : 1))
                Text(mode.title).font(TKFont.bodyBold(14)).foregroundColor(theme.p.text)
                Text(mode.subtitle).font(TKFont.body(11)).foregroundColor(theme.p.muted).lineLimit(1).minimumScaleFactor(0.8)
            }
            .padding(10)
            .card(22, strong: selected)
            .scaleEffect(selected ? 1.0 : 0.97)
        }
        .buttonStyle(PressScale())
        .animation(.tkBouncy, value: selected)
    }

    @ViewBuilder
    private func preview(_ pal: Palette) -> some View {
        ZStack {
            if mode == .glass {
                LinearGradient(colors: [Color(hex: 0x0B1A08), Color(hex: 0x030503)], startPoint: .top, endPoint: .bottom)
                Circle().fill(Palette.lime.opacity(0.7)).frame(width: 90).blur(radius: 30).offset(x: -30, y: -20)
                Circle().fill(Color(hex: 0x2EFFB4).opacity(0.4)).frame(width: 80).blur(radius: 30).offset(x: 40, y: 30)
            } else {
                pal.bg
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 6).fill(Palette.lime).frame(width: 22, height: 22)
                    RoundedRectangle(cornerRadius: 4).fill(pal.text.opacity(0.7)).frame(width: 50, height: 7)
                }
                ZStack {
                    if mode == .glass { RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial) }
                    RoundedRectangle(cornerRadius: 10).fill(mode == .glass ? Color.white.opacity(0.08) : pal.surface)
                }
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(mode == .glass ? Color.white.opacity(0.35) : pal.stroke, lineWidth: 1))
                .frame(height: 34)
            }
            .padding(10)
        }
        .environment(\.colorScheme, mode == .light ? .light : .dark)
    }
}

struct AboutView: View {
    @EnvironmentObject var theme: ThemeStore
    @State private var spin = false
    var body: some View {
        let p = theme.p
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                ZStack {
                    Circle().fill(Palette.lime.opacity(0.35)).frame(width: 170).blur(radius: 40)
                    Image("TKLogo").resizable().scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .rotationEffect(.degrees(spin ? 0 : -15))
                        .scaleEffect(spin ? 1 : 0.6)
                }
                .padding(.top, 20)
                Text("Tech Kadak").font(TKFont.display(28)).foregroundColor(p.text)
                Text("Paid apps ka FREE jawab — kaam ke free aur open-source apps, ek jagah.")
                    .font(TKFont.body(15)).foregroundColor(p.muted).multilineTextAlignment(.center).padding(.horizontal, 30)
                VStack(spacing: 0) {
                    kv("Developer", "Rohit Saini")
                    Rectangle().fill(p.stroke.opacity(0.5)).frame(height: 1)
                    kv("Version", Config.version + " (iPhone)")
                    Rectangle().fill(p.stroke.opacity(0.5)).frame(height: 1)
                    kv("Data", "techkadak.github.io")
                }
                .card(20).padding(.horizontal, 18)
                VStack(spacing: 10) {
                    linkBtn("Instagram", "@techkadak", Config.instagram)
                    linkBtn("YouTube", "Tech Kadak", Config.youtube)
                    linkBtn("Telegram", "t.me/techkadak", Config.telegram)
                    linkBtn("Website", "techkadak.github.io", Config.website)
                }
                .padding(.horizontal, 18)
                Text("Tech Kadak koi app khud host nahi karta. Har link app ke official source pe jaata hai. Har app ka trademark uske maalik ka hai.")
                    .font(TKFont.body(12)).foregroundColor(p.faint).multilineTextAlignment(.center).padding(.horizontal, 30)
                Text("Made with 💚 in India").font(TKFont.bodyBold(12)).foregroundColor(p.lime)
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { withAnimation(.tkBouncy.delay(0.1)) { spin = true } }
    }

    private func kv(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(TKFont.body(14)).foregroundColor(theme.p.muted)
            Spacer()
            Text(v).font(TKFont.bodyBold(14)).foregroundColor(theme.p.text)
        }
        .padding(16)
    }

    private func linkBtn(_ t: String, _ s: String, _ url: String) -> some View {
        Group {
            if let u = URL(string: url) {
                Link(destination: u) {
                    HStack {
                        Text(t).font(TKFont.bodyBold(15)).foregroundColor(theme.p.text)
                        Spacer()
                        Text(s).font(TKFont.body(13)).foregroundColor(theme.p.muted)
                        Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .bold)).foregroundColor(theme.p.lime)
                    }
                    .padding(16).card(18)
                }
                .buttonStyle(PressScale(scale: 0.97))
            }
        }
    }
}
