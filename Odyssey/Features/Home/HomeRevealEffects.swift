//
//  HomeRevealEffects.swift
//  Odyssey
//
//  Motion for the daily reveal: the idle float, the tremble that grows
//  with the charge, the rare pulse, the spinning purple rays behind a rare
//  find, and confetti bursts in the mockup's colors. Ported from the
//  keyframes in daily-reveal.css and reveal-hold.css.
//

import Foundation
import SwiftUI

/// reveal-float, hold-shake and rare-pulse, chosen by what the card is doing.
struct HomeRevealMotion: ViewModifier {
    var time: Double
    var charge: Double
    var holding: Bool
    var revealed: Bool
    var burstStart: Date?

    func body(content: Content) -> some View {
        let m = motion
        return content
            .scaleEffect(CGFloat(m.scale))
            .rotationEffect(.degrees(m.rotation))
            .offset(x: CGFloat(m.x), y: CGFloat(m.y))
    }

    private var motion: (x: Double, y: Double, rotation: Double, scale: Double) {
        if let start = burstStart, !revealed {
            return pulse(Date().timeIntervalSince(start) / 1.3)
        }
        if revealed { return (0, 0, 0, 1) }
        if holding { return shake() }
        // 3 s ease in out between rotate(-1deg) and translateY(-8px) rotate(1deg).
        let p = GlobieArt.wave(time, 3)
        return (0, -8 * p, -1 + 2 * p, 1)
    }

    /// A 90 ms tremble whose reach grows with the charge, shrinking slightly.
    private func shake() -> (x: Double, y: Double, rotation: Double, scale: Double) {
        let c = charge
        let scale = 1 - c * 0.04
        let k = GlobieArt.cycle(time, 0.09)
        let keys: [(Double, Double, Double, Double)] = [(0, 0, 0, 0), (0.25, -5 * c, 2 * c, -1.5 * c), (0.75, 5 * c, -2 * c, 1.5 * c), (1, 0, 0, 0)]
        let v = HomeRevealMotion.interpolate(keys, k)
        return (v.0, v.1, v.2, scale)
    }

    private func pulse(_ e: Double) -> (x: Double, y: Double, rotation: Double, scale: Double) {
        let keys: [(Double, Double, Double, Double)] = [(0, 1, 0, 0), (0.2, 1.06, -2, 0), (0.4, 0.98, 2, 0), (0.6, 1.03, 0, 0), (1, 1, 0, 0)]
        let v = HomeRevealMotion.interpolate(keys, min(1, max(0, e)))
        return (0, 0, v.1, v.0)
    }

    /// Linear keyframes: each entry is (at, a, b, c).
    static func interpolate(_ keys: [(Double, Double, Double, Double)], _ k: Double) -> (Double, Double, Double) {
        for i in 1..<keys.count where k <= keys[i].0 {
            let a = keys[i - 1]
            let b = keys[i]
            let f = (k - a.0) / max(0.0001, b.0 - a.0)
            return (a.1 + (b.1 - a.1) * f, a.2 + (b.2 - a.2) * f, a.3 + (b.3 - a.3) * f)
        }
        let last = keys[keys.count - 1]
        return (last.1, last.2, last.3)
    }
}

/// Lilac rays fanning out from the card, fading out from the middle and spinning slowly.
struct HomeRevealRays: View {
    var spin: Double

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = Double(max(size.width, size.height))
            var wedge = context
            wedge.translateBy(x: center.x, y: center.y)
            wedge.rotate(by: .degrees(GlobieArt.cycle(spin, 10) * 360))
            for i in 0..<17 {
                let start = Double(i) * 22 - 90
                var path = Path()
                path.move(to: .zero)
                path.addArc(center: .zero, radius: CGFloat(radius), startAngle: .degrees(start), endAngle: .degrees(start + 7), clockwise: false)
                path.closeSubpath()
                wedge.fill(path, with: .color(Color(hex: "#c4b5fd").opacity(0.55)))
            }
        }
        .frame(width: 700, height: 700)
        .mask(RadialGradient(colors: [.black, .black, .clear], center: .center, startRadius: 0, endRadius: 350 * 0.58))
        .allowsHitTesting(false)
    }
}

/// A one off confetti burst from a point, in given colors.
struct HomeRevealConfetti: View {
    @Environment(\.animationsPaused) private var animationsPaused
    struct Burst: Identifiable {
        let id = UUID()
        var originY: Double
        var count: Int
        var colors: [String]
    }

    var burst: Burst
    @State private var start = Date()
    /// Once the burst has fallen, the clock stops instead of redrawing an empty canvas forever.
    @State private var finished = false

    var body: some View {
        TimelineView(OdysseyMotion.schedule(paused: animationsPaused || finished)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                guard t < 3.2 else { return }
                for i in 0..<burst.count {
                    let rand = StableHash.generator("reveal\(burst.id.uuidString)\(i)")
                    let angle: Double = rand() * 2 * Double.pi
                    let speed: Double = 260 + rand() * 420
                    let x: Double = Double(size.width) * 0.5 + cos(angle) * speed * t
                    let rise: Double = sin(angle) * speed * t
                    let y: Double = Double(size.height) * burst.originY + rise + 560 * t * t
                    var piece = context
                    piece.opacity = max(0, 1 - t / 3.2)
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .radians((rand() * 10 - 5) * t))
                    let color = Color(hex: burst.colors[i % max(1, burst.colors.count)])
                    piece.fill(Path(roundedRect: CGRect(x: -4, y: -2.5, width: 8, height: 5), cornerRadius: 1.2), with: .color(color))
                }
            }
        }
        .allowsHitTesting(false)
        .opacity(finished ? 0 : 1)
        .onAppear { start = Date() }
        .task {
            try? await Task.sleep(for: .seconds(3.3))
            finished = true
        }
    }
}
