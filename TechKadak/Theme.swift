import SwiftUI

enum ThemeMode: String, CaseIterable, Identifiable {
    case amoled, dark, light, glass
    var id: String { rawValue }
    var title: String {
        switch self {
        case .amoled: return "AMOLED"
        case .dark: return "Dark"
        case .light: return "Light"
        case .glass: return "Liquid Glass"
        }
    }
    var subtitle: String {
        switch self {
        case .amoled: return "Pure black, battery bachao"
        case .dark: return "Soft dark"
        case .light: return "Din ke liye"
        case .glass: return "Kaanch jaisa blur + lime glow ✨"
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }
}

struct Palette {
    let mode: ThemeMode
    static let lime = Color(hex: 0x9BFF2E)
    static let ink = Color(hex: 0x0A0A0A)
    var lime: Color { mode == .light ? Color(hex: 0x5BBF00) : Palette.lime }   // light pe thoda gehra (padhne layak)
    var limeFill: Color { Palette.lime }
    var onLime: Color { Palette.ink }
    let bg: Color
    let surface: Color
    let surface2: Color
    let stroke: Color
    let text: Color
    let muted: Color
    let faint: Color

    var isGlass: Bool { mode == .glass }
    var isLight: Bool { mode == .light }
    var scheme: ColorScheme { mode == .light ? .light : .dark }

    static func of(_ m: ThemeMode) -> Palette {
        switch m {
        case .amoled: return Palette(mode: m, bg: Color(hex: 0x000000), surface: Color(hex: 0x0E0E0E), surface2: Color(hex: 0x1A1A1A), stroke: Color(hex: 0x282828), text: .white, muted: Color(hex: 0xA3A3A3), faint: Color(hex: 0x6B6B6B))
        case .dark: return Palette(mode: m, bg: Color(hex: 0x141614), surface: Color(hex: 0x1D201D), surface2: Color(hex: 0x272A27), stroke: Color(hex: 0x353935), text: .white, muted: Color(hex: 0xADB2AD), faint: Color(hex: 0x7A7F7A))
        case .light: return Palette(mode: m, bg: Color(hex: 0xF5F6F1), surface: Color(hex: 0xFFFFFF), surface2: Color(hex: 0xEAECE4), stroke: Color(hex: 0xD6D9CE), text: Color(hex: 0x0A0A0A), muted: Color(hex: 0x52574D), faint: Color(hex: 0x878C80))
        case .glass: return Palette(mode: m, bg: Color(hex: 0x050806), surface: Color.white.opacity(0.08), surface2: Color.white.opacity(0.13), stroke: Color.white.opacity(0.18), text: .white, muted: Color.white.opacity(0.78), faint: Color.white.opacity(0.55))
        }
    }
}

final class ThemeStore: ObservableObject {
    @Published var mode: ThemeMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "tk.theme") }
    }
    init() {
        if let forced = Config.arg("tkTheme"), let m = ThemeMode(rawValue: forced) { mode = m }
        else { mode = ThemeMode(rawValue: UserDefaults.standard.string(forKey: "tk.theme") ?? "") ?? .dark }
    }
    var p: Palette { Palette.of(mode) }
}

// MARK: - Fonts (bundled Unbounded + DM Sans; na mile to system font)
enum TKFont {
    static func display(_ size: CGFloat) -> Font { .custom("TKDisplay-Black", size: size) }
    static func displayBold(_ size: CGFloat) -> Font { .custom("TKDisplay-Bold", size: size) }
    static func body(_ size: CGFloat) -> Font { .custom("TKBody-Regular", size: size) }
    static func bodyBold(_ size: CGFloat) -> Font { .custom("TKBody-Bold", size: size) }
}

// MARK: - Backgrounds

struct ThemedBackground: View {
    @EnvironmentObject var theme: ThemeStore
    var body: some View {
        let p = theme.p
        ZStack {
            p.bg
            if p.isGlass { GlassAurora() }
        }
        .ignoresSafeArea()
    }
}

/// Liquid Glass ke peeche: dheere hilti lime/teal roshni.
struct GlassAurora: View {
    @State private var phase = false
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                LinearGradient(colors: [Color(hex: 0x07120A), Color(hex: 0x030503), Color(hex: 0x0A1408)], startPoint: .top, endPoint: .bottom)
                Circle().fill(Palette.lime.opacity(0.55)).frame(width: w * 0.95).blur(radius: 90)
                    .offset(x: phase ? -w * 0.30 : -w * 0.18, y: phase ? -h * 0.30 : -h * 0.22)
                Circle().fill(Color(hex: 0x2EFFB4).opacity(0.30)).frame(width: w * 0.8).blur(radius: 100)
                    .offset(x: phase ? w * 0.35 : w * 0.25, y: phase ? h * 0.05 : h * 0.12)
                Circle().fill(Palette.lime.opacity(0.32)).frame(width: w * 0.9).blur(radius: 110)
                    .offset(x: phase ? -w * 0.1 : w * 0.05, y: phase ? h * 0.42 : h * 0.36)
            }
            .frame(width: w, height: h)
        }
        .onAppear { withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { phase = true } }
    }
}

// MARK: - Card style (glass = material + lime rim)

struct CardBackground: ViewModifier {
    @EnvironmentObject var theme: ThemeStore
    var radius: CGFloat = 20
    var strong = false
    @ViewBuilder
    func body(content: Content) -> some View {
        let p = theme.p
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if p.isGlass {
            content
                .background(shape.fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
                .background(shape.fill(Color.white.opacity(strong ? 0.10 : 0.05)))
                .overlay(shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(0.45), Palette.lime.opacity(0.25), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                .shadow(color: Palette.lime.opacity(strong ? 0.18 : 0.08), radius: strong ? 18 : 10, y: 6)
        } else {
            content
                .background(shape.fill(strong ? p.surface2 : p.surface))
                .overlay(shape.strokeBorder(p.stroke.opacity(p.isLight ? 1 : 0.6), lineWidth: 1))
        }
    }
}

extension View {
    func card(_ radius: CGFloat = 20, strong: Bool = false) -> some View { modifier(CardBackground(radius: radius, strong: strong)) }
}

/// Spring jo sab jagah use hoti hai.
extension Animation {
    static let tk = Animation.spring(response: 0.42, dampingFraction: 0.78)
    static let tkBouncy = Animation.spring(response: 0.5, dampingFraction: 0.62)
}

/// Dabane pe halka sa daba — har card/button pe.
struct PressScale: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
