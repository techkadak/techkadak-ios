import SwiftUI
import UIKit

/// App ka icon: cache se, warna initials wala lime tile.
struct AppIconView: View {
    let app: AppItem
    var size: CGFloat = 56
    @State private var img: UIImage?
    @EnvironmentObject var theme: ThemeStore

    var body: some View {
        let r = size * 0.26
        ZStack {
            if let img = img {
                Image(uiImage: img).resizable().scaledToFill()
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                LinearGradient(colors: [Palette.lime, Color(hex: 0x6FD400)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(app.initials).font(TKFont.display(size * 0.3)).foregroundColor(Palette.ink)
            }
        }
        .frame(width: size, height: size)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: r, style: .continuous).strokeBorder(Color.white.opacity(theme.p.isLight ? 0 : 0.08), lineWidth: 1))
        .task(id: app.slug) {
            guard let u = app.iconURL else { return }
            if let c = ImageCache.shared.cached(u) { img = c; return }
            if let l = await ImageCache.shared.load(u) { withAnimation(.easeOut(duration: 0.25)) { img = l } }
        }
    }
}

struct RemoteImage: View {
    let url: URL?
    @State private var img: UIImage?
    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
            if let img = img { Image(uiImage: img).resizable().scaledToFill().transition(.opacity) }
        }
        .task(id: url?.absoluteString ?? "") {
            guard let u = url else { return }
            if let c = ImageCache.shared.cached(u) { img = c; return }
            if let l = await ImageCache.shared.load(u) { withAnimation(.easeOut(duration: 0.3)) { img = l } }
        }
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var action: (() -> Void)? = nil
    @EnvironmentObject var theme: ThemeStore
    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(TKFont.display(19)).foregroundColor(theme.p.text)
                if let s = subtitle { Text(s).font(TKFont.body(13)).foregroundColor(theme.p.muted) }
            }
            Spacer()
            if let action = action {
                Button(action: action) {
                    Image(systemName: "arrow.right").font(.system(size: 14, weight: .bold))
                        .foregroundColor(theme.p.text)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(theme.p.isGlass ? Color.white.opacity(0.12) : theme.p.surface2))
                }.buttonStyle(PressScale())
            }
        }
        .padding(.horizontal, 18)
    }
}

struct Pill: View {
    let text: String
    var filled = false
    @EnvironmentObject var theme: ThemeStore
    var body: some View {
        Text(text)
            .font(TKFont.bodyBold(12))
            .lineLimit(1)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .foregroundColor(filled ? Palette.ink : theme.p.text)
            .background(Capsule().fill(filled ? Palette.lime : (theme.p.isGlass ? Color.white.opacity(0.12) : theme.p.surface2)))
    }
}

struct AvailabilityBadge: View {
    let app: AppItem
    @EnvironmentObject var theme: ThemeStore
    var body: some View {
        switch app.availability {
        case .iphone: label("iPhone pe bhi", "iphone", true)
        case .web: label("Browser me chalega", "safari", true)
        case .pc: label("PC ke liye", "desktopcomputer", false)
        case .android: label("Android ke liye", "smartphone", false)
        }
    }
    private func label(_ t: String, _ icon: String, _ ok: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold))
            Text(t).font(TKFont.bodyBold(11))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .foregroundColor(ok ? Palette.ink : theme.p.muted)
        .background(Capsule().fill(ok ? Palette.lime.opacity(0.9) : (theme.p.isGlass ? Color.white.opacity(0.1) : theme.p.surface2)))
    }
}

/// "Get" button — iPhone pe dusre apps install nahi hote, isliye official link khulta hai.
struct GetButton: View {
    let app: AppItem
    var compact = true
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var theme: ThemeStore
    var body: some View {
        let l = label
        let title = l.0
        let primary = l.1
        Button {
            Haptics.tap()
            if let u = app.officialURL { openURL(u) }
        } label: {
            Text(title)
                .font(compact ? TKFont.bodyBold(13) : TKFont.display(15))
                .lineLimit(1)
                .padding(.horizontal, compact ? 14 : 22)
                .frame(height: compact ? 32 : 52)
                .frame(maxWidth: compact ? nil : .infinity)
                .foregroundColor(primary ? Palette.ink : theme.p.text)
                .background(Capsule().fill(primary ? Palette.lime : (theme.p.isGlass ? Color.white.opacity(0.14) : theme.p.surface2)))
                .shadow(color: primary && theme.p.isGlass ? Palette.lime.opacity(0.45) : .clear, radius: 12)
        }
        .buttonStyle(PressScale(scale: 0.93))
    }
    private var label: (String, Bool) {
        switch app.availability {
        case .iphone: return (app.appStoreLink != nil ? (compact ? "GET" : "App Store pe kholo") : (compact ? "GET" : "Official site kholo"), true)
        case .web: return (compact ? "KHOLO" : "Browser me kholo", true)
        case .pc: return (compact ? "PC ke liye" : "PC ke liye • Official site", false)
        case .android: return (compact ? "Android" : "Android ke liye • Official site", false)
        }
    }
}

struct AppRow: View {
    let app: AppItem
    var rank: Int? = nil
    @EnvironmentObject var theme: ThemeStore
    var body: some View {
        HStack(spacing: 14) {
            if let r = rank {
                Text("\(r)").font(TKFont.display(16)).foregroundColor(theme.p.faint).frame(width: 22)
            }
            AppIconView(app: app, size: 58)
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name).font(TKFont.bodyBold(16)).foregroundColor(theme.p.text).lineLimit(1)
                Text(app.what).font(TKFont.body(13)).foregroundColor(theme.p.muted).lineLimit(2)
                HStack(spacing: 6) {
                    Text(app.pricing).font(TKFont.bodyBold(11)).foregroundColor(theme.p.lime)
                    if let c = app.categories.first { Text("• " + Cat.short(c)).font(TKFont.body(11)).foregroundColor(theme.p.faint).lineLimit(1) }
                }
            }
            Spacer(minLength: 6)
            GetButton(app: app)
        }
        .padding(.horizontal, 18).padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

enum Cat {
    static func short(_ c: String) -> String {
        switch c {
        case "Open Source/GitHub": return "Open Source"
        case "Paid ka FREE Jawab": return "Paid ka FREE"
        default: return c
        }
    }
    static func tagline(_ c: String) -> String {
        switch c {
        case "Android Apps": return "Phone ke liye kadak apps"
        case "AI Tools": return "AI se kaam fatafat"
        case "Open Source/GitHub": return "Code khula, data tera"
        case "Paid ka FREE Jawab": return "Paise bachao, same kaam"
        case "Student Tech": return "Padhai ke liye best"
        default: return "Kaam ke apps"
        }
    }
    static func emoji(_ c: String) -> String {
        switch c {
        case "Android Apps": return "📱"
        case "AI Tools": return "🤖"
        case "Open Source/GitHub": return "🧑‍💻"
        case "Paid ka FREE Jawab": return "💸"
        case "Student Tech": return "🎓"
        default: return "✨"
        }
    }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
}

/// UIActivityViewController wrapper (poster / link share).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct EmptyState: View {
    let emoji: String
    let title: String
    let sub: String
    @EnvironmentObject var theme: ThemeStore
    var body: some View {
        VStack(spacing: 10) {
            Text(emoji).font(.system(size: 54))
            Text(title).font(TKFont.display(18)).foregroundColor(theme.p.text).multilineTextAlignment(.center)
            Text(sub).font(TKFont.body(14)).foregroundColor(theme.p.muted).multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}
