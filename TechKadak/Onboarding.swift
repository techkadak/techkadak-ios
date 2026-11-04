import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var theme: ThemeStore
    var onDone: () -> Void
    @State private var page = Int(Config.arg("tkOnboardPage") ?? "0") ?? 0

    private let titles = ["Paid apps ka\nFREE jawab", "Har app official\nlink se, 100% safe", "Roz naya app,\nkhud update", "Apni pasand\nka look"]
    private let subs = [
        "Mehenge apps ki jagah kaam ke free / open-source apps — check karke.",
        "GET dabao → app ka official page ya App Store khulta hai. Koi fake link, fake rating nahi.",
        "Website ka bot har din naya app daalta hai — app me apne aap aa jaata hai.",
        "AMOLED, Dark, Light ya naya Liquid Glass — sab tumhare haath me.",
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(colors: [Palette.lime.opacity(0.22), .clear], center: .top, startRadius: 10, endRadius: 420)
                .ignoresSafeArea()
            TabView(selection: $page) {
                ForEach(0..<4, id: \.self) { i in
                    OnboardPage(index: i, title: titles[i], sub: subs[i], active: page == i)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            VStack {
                HStack {
                    Spacer()
                    if page < 3 {
                        Button("Skip  ›") { finish() }
                            .font(TKFont.bodyBold(15)).foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 20).padding(.top, 8)
                    }
                }
                Spacer()
                HStack(alignment: .center) {
                    HStack(spacing: 7) {
                        ForEach(0..<4, id: \.self) { i in
                            Capsule().fill(i == page ? Palette.lime : Color.white.opacity(0.25))
                                .frame(width: i == page ? 26 : 8, height: 8)
                        }
                    }
                    .animation(.tkBouncy, value: page)
                    Spacer()
                    Button {
                        Haptics.tap()
                        if page < 3 { withAnimation(.tk) { page += 1 } } else { finish() }
                    } label: {
                        HStack(spacing: 8) {
                            Text(page < 3 ? "Continue" : "Shuru karo").font(TKFont.display(15))
                            Image(systemName: "arrow.right").font(.system(size: 15, weight: .heavy))
                        }
                        .foregroundColor(Palette.ink)
                        .padding(.horizontal, 22).frame(height: 54)
                        .background(Capsule().fill(Palette.lime))
                        .shadow(color: Palette.lime.opacity(0.45), radius: 16, y: 4)
                    }
                    .buttonStyle(PressScale(scale: 0.94))
                }
                .padding(.horizontal, 24).padding(.bottom, 18)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func finish() {
        Haptics.soft()
        onDone()
    }
}

private struct OnboardPage: View {
    let index: Int
    let title: String
    let sub: String
    let active: Bool
    @EnvironmentObject var store: Store
    @State private var appear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                switch index {
                case 0: PaidFreeMock(apps: iconApps, appear: appear)
                case 1: OrbitMock(apps: iconApps, count: store.apps.count, appear: appear)
                case 2: DailyMock(app: store.apps.first, appear: appear)
                default: LookMock(appear: appear)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 50)
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(TKFont.display(31)).foregroundColor(.white).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .offset(y: appear ? 0 : 24).opacity(appear ? 1 : 0)
                    .animation(.tk.delay(0.05), value: appear)
                Text(sub).font(TKFont.body(16)).foregroundColor(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .offset(y: appear ? 0 : 24).opacity(appear ? 1 : 0)
                    .animation(.tk.delay(0.12), value: appear)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 120)
        }
        .onAppear { if active { appear = false; withAnimation { appear = true } } }
        .onChange(of: active) { a in
            if a { appear = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { appear = true } }
        }
        .task { if active { appear = true } }
    }

    private var iconApps: [AppItem] { store.apps.filter { $0.icon != nil } }
}

private struct PaidFreeMock: View {
    let apps: [AppItem]
    let appear: Bool
    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                tag("PAID ₹₹₹", strike: true)
                    .rotationEffect(.degrees(appear ? -6 : 0))
                Image(systemName: "arrow.right").font(.system(size: 22, weight: .heavy)).foregroundColor(.white.opacity(0.6))
                tag("FREE ✓", strike: false)
                    .scaleEffect(appear ? 1 : 0.4)
                    .animation(.tkBouncy.delay(0.25), value: appear)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(64), spacing: 14), count: 4), spacing: 14) {
                ForEach(Array(apps.prefix(8).enumerated()), id: \.element.slug) { i, a in
                    AppIconView(app: a, size: 64)
                        .scaleEffect(appear ? 1 : 0.2)
                        .opacity(appear ? 1 : 0)
                        .rotationEffect(.degrees(appear ? 0 : Double((i % 3) - 1) * 25))
                        .animation(.tkBouncy.delay(0.3 + Double(i) * 0.05), value: appear)
                }
            }
        }
        .animation(.tk, value: appear)
    }
    private func tag(_ s: String, strike: Bool) -> some View {
        Text(s).font(TKFont.display(18))
            .strikethrough(strike, color: .red)
            .foregroundColor(strike ? .white.opacity(0.55) : Palette.ink)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(strike ? Color.white.opacity(0.1) : Palette.lime))
    }
}

private struct OrbitMock: View {
    let apps: [AppItem]
    let count: Int
    let appear: Bool
    var body: some View {
        TimelineView(.animation) { ctx in
            let s = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 1).frame(width: 260, height: 260)
                Circle().stroke(Palette.lime.opacity(0.18), lineWidth: 1).frame(width: 170, height: 170)
                ForEach(Array(apps.prefix(8).enumerated()), id: \.element.slug) { i, a in
                    let ring: Double = i % 2 == 0 ? 130 : 85
                    let ang = s * (i % 2 == 0 ? 0.25 : -0.35) + Double(i) * .pi / 4
                    AppIconView(app: a, size: i % 2 == 0 ? 50 : 42)
                        .offset(x: cos(ang) * ring * (appear ? 1 : 0.2), y: sin(ang) * ring * (appear ? 1 : 0.2))
                        .opacity(appear ? 1 : 0)
                }
                VStack(spacing: 4) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.lime)
                        Text("TK").font(TKFont.display(30)).foregroundColor(Palette.ink)
                    }
                    .frame(width: 84, height: 84)
                    .shadow(color: Palette.lime.opacity(0.6), radius: 24)
                    Text("\(max(count, 1))+ apps").font(TKFont.bodyBold(13)).foregroundColor(.white.opacity(0.8)).padding(.top, 6)
                }
                .scaleEffect(appear ? 1 : 0.5)
            }
        }
        .animation(.tkBouncy, value: appear)
    }
}

private struct DailyMock: View {
    let app: AppItem?
    let appear: Bool
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill").foregroundColor(Palette.lime)
                Text("Roz ka naya app").font(TKFont.bodyBold(14)).foregroundColor(.white)
                Spacer()
                Text("abhi").font(TKFont.body(12)).foregroundColor(.white.opacity(0.5))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.08)))
            .offset(y: appear ? 0 : -60).opacity(appear ? 1 : 0)
            .animation(.tkBouncy.delay(0.1), value: appear)
            if let a = app {
                VStack(alignment: .leading, spacing: 12) {
                    Text("AAJ KA APP").font(TKFont.display(12)).foregroundColor(Palette.ink)
                        .padding(.horizontal, 10).padding(.vertical, 5).background(Capsule().fill(Palette.lime))
                    HStack(spacing: 14) {
                        AppIconView(app: a, size: 64)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(a.name).font(TKFont.display(20)).foregroundColor(.white).lineLimit(1)
                            Text(a.what).font(TKFont.body(13)).foregroundColor(.white.opacity(0.7)).lineLimit(2)
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.lime.opacity(0.35), lineWidth: 1))
                .scaleEffect(appear ? 1 : 0.7).opacity(appear ? 1 : 0)
                .animation(.tkBouncy.delay(0.3), value: appear)
            }
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 6).fill(i == 6 ? Palette.lime : Color.white.opacity(0.12))
                        .frame(height: appear ? 34 : 4)
                        .animation(.tkBouncy.delay(0.45 + Double(i) * 0.04), value: appear)
                }
            }
            Text("7 din, 7 apps").font(TKFont.body(12)).foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 28)
    }
}

private struct LookMock: View {
    let appear: Bool
    private let modes: [(String, Color, Color)] = [
        ("AMOLED", .black, .white), ("Dark", Color(hex: 0x1D201D), .white), ("Light", Color(hex: 0xF5F6F1), .black), ("Glass", Color.white.opacity(0.12), .white),
    ]
    var body: some View {
        ZStack {
            Circle().fill(Palette.lime.opacity(0.35)).frame(width: 220).blur(radius: 60)
            ForEach(0..<4, id: \.self) { i in
                let m = modes[i]
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 6).fill(Palette.lime).frame(width: 40, height: 10)
                    RoundedRectangle(cornerRadius: 6).fill(m.2.opacity(0.5)).frame(width: 80, height: 8)
                    RoundedRectangle(cornerRadius: 6).fill(m.2.opacity(0.3)).frame(width: 60, height: 8)
                    Spacer()
                    Text(m.0).font(TKFont.display(13)).foregroundColor(m.2)
                }
                .padding(14)
                .frame(width: 120, height: 190, alignment: .leading)
                .background(
                    ZStack {
                        if i == 3 { RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.ultraThinMaterial) }
                        RoundedRectangle(cornerRadius: 22, style: .continuous).fill(m.1)
                    }
                )
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
                .rotationEffect(.degrees(appear ? Double(i) * 9 - 13.5 : 0), anchor: .bottom)
                .offset(x: appear ? CGFloat(i) * 38 - 57 : 0)
                .animation(.tkBouncy.delay(0.1 + Double(i) * 0.06), value: appear)
            }
        }
    }
}
