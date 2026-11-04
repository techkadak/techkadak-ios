import SwiftUI

/// Android jaisa splash: lime screen → black TK mark bounce → "TECH KADAK" type → dot me simatna →
/// dot uchhalta hai, upar jaata hai → gol circle khul ke app dikhata hai. ~2.8 s, tap = skip.
enum Ease {
    static func seg(_ t: Double, _ a: Double, _ b: Double) -> Double { min(max((t - a) / (b - a), 0), 1) }
    /// cubic-bezier(x1,y1,x2,y2) — CSS/Compose jaisa.
    static func bezier(_ x: Double, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        var t = x
        for _ in 0..<8 {
            let cx = 3 * x1 * t * (1 - t) * (1 - t) + 3 * x2 * t * t * (1 - t) + t * t * t - x
            let dx = 3 * x1 * (1 - t) * (1 - t) + 6 * (x2 - x1) * t * (1 - t) + 3 * (1 - x2) * t * t
            if abs(dx) < 1e-6 { break }
            t = min(max(t - cx / dx, 0), 1)
        }
        return 3 * y1 * t * (1 - t) * (1 - t) + 3 * y2 * t * t * (1 - t) + t * t * t
    }
    static func ez(_ x: Double) -> Double { bezier(x, 0.4, 0, 0.2, 1) }           // FastOutSlowIn
    static func back(_ x: Double) -> Double { bezier(x, 0.34, 1.56, 0.64, 1) }      // overshoot pop
}

struct SplashHost<Content: View>: View {
    let content: Content
    @State private var start = Date()
    @State private var done = false
    @State private var skipped = false
    private let duration = 2.8
    private let frozen: Double? = Config.arg("tkSplashAt").flatMap { Double($0) }
    private let noSplash = Config.arg("tkNoSplash") == "1"

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        let finished = done || noSplash
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: nil, paused: finished || frozen != nil)) { ctx in
                let t: Double = finished ? 1 : (frozen ?? min(ctx.date.timeIntervalSince(start) / duration, 1))
                stack(t: t, finished: finished, geo: geo)
            }
        }
        .task {
            if frozen != nil || noSplash { return }
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000) + 80_000_000)
            done = true
        }
    }

    @ViewBuilder
    private func stack(t: Double, finished: Bool, geo: GeometryProxy) -> some View {
        let w = geo.size.width, h = geo.size.height
        let top = geo.safeAreaInsets.top, bottom = geo.safeAreaInsets.bottom
        let fullH = h + top + bottom
        let dy = dotY(t, fullH)
        // full-screen center, host (safe-area) coordinates me
        let center = CGPoint(x: w / 2, y: fullH / 2 - top + dy)
        let reveal = Ease.ez(Ease.seg(t, 0.80, 1))
        let fx = max(center.x, w - center.x)
        let fy = max(center.y + top, fullH - (center.y + top))
        let r = sqrt(fx * fx + fy * fy) * CGFloat(reveal)
        let pad: CGFloat = 400
        ZStack {
            if !finished {
                LimeLayer(t: t, dotY: dy)
                    .contentShape(Rectangle())
                    .onTapGesture { skip() }
            }
            content
                .mask(
                    ZStack {
                        if finished {
                            Color.black
                        } else {
                            Circle()
                                .frame(width: max(r * 2, 0.1), height: max(r * 2, 0.1))
                                .position(x: center.x + pad, y: center.y + pad)
                        }
                    }
                    .frame(width: w + pad * 2, height: h + pad * 2)
                )
                .opacity(finished || reveal > 0 ? 1 : 0)
                .allowsHitTesting(finished)
        }
    }

    private func dotY(_ t: Double, _ h: CGFloat) -> CGFloat {
        let bounce = Ease.seg(t, 0.58, 0.72)
        let shoot = Ease.ez(Ease.seg(t, 0.72, 0.80))
        let b = bounce < 0.5 ? Ease.ez(bounce * 2) : 1 - Ease.ez((bounce - 0.5) * 2) * 0.35
        let bounceY = CGFloat(b) * 70
        let topY = -(h / 2 - 90)
        return shoot > 0 ? bounceY * 0.65 + (topY - bounceY * 0.65) * CGFloat(shoot) : bounceY
    }

    private func skip() {
        guard frozen == nil, !skipped, !done else { return }
        skipped = true
        Haptics.soft()
        let now = Date()
        let target = duration * 0.8
        if now.timeIntervalSince(start) < target { start = now.addingTimeInterval(-target) }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 0.2 * 1_000_000_000) + 80_000_000)
            done = true
        }
    }
}

private struct LimeLayer: View {
    let t: Double
    let dotY: CGFloat
    private let word = Array("TECH KADAK")

    var body: some View {
        let pop = Ease.seg(t, 0, 0.14)
        let popScale = pop < 1 ? Ease.back(pop) : 1
        let type = Ease.seg(t, 0.16, 0.44)
        let collapse = Ease.ez(Ease.seg(t, 0.47, 0.58))
        let shrink = Ease.ez(Ease.seg(t, 0.16, 0.30))
        let markSize = CGFloat(96 - 42 * shrink)
        let n = min(max(Int(type * Double(word.count)), 0), word.count)
        ZStack {
            Palette.lime
            if collapse < 1 {
                HStack(spacing: n > 0 ? 10 : 0) {
                    ZStack {
                        RoundedRectangle(cornerRadius: CGFloat(28 - 12 * shrink), style: .continuous).fill(Palette.ink)
                        Text("TK").font(TKFont.display(CGFloat(38 - 17 * shrink))).foregroundColor(Palette.lime)
                    }
                    .frame(width: markSize, height: markSize)
                    .scaleEffect(CGFloat(popScale))
                    if n > 0 {
                        Text(String(word.prefix(n)))
                            .font(TKFont.display(26))
                            .foregroundColor(Palette.ink)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
                .scaleEffect(x: CGFloat(max(1 - collapse, 0.02)), y: CGFloat(1 - collapse * 0.8))
                .opacity(1 - collapse * 0.6)
            }
            if collapse > 0.6 {
                let s = 0.4 + 0.6 * Ease.seg(collapse, 0.6, 1)
                Circle().fill(Palette.ink)
                    .frame(width: 18, height: 18)
                    .scaleEffect(CGFloat(s))
                    .offset(y: dotY)
            }
        }
        .ignoresSafeArea()
    }
}
