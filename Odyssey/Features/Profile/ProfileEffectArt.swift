//
//  ProfileEffectArt.swift
//  Odyssey
//
//  The drawing for the drifting profile effects, ported in spirit from the
//  mockup's fx-nature.js and fx-explorer.js: Explorer Trail, Vines,
//  Fireflies, Bubbles, Petal Fall and Embers. Sizes scale with the space,
//  so the same effect works on a whole profile and on a small shop card.
//

import Foundation
import SwiftUI

enum ProfileEffectArt {
    typealias Scene = ProfileEffectScene

    static func draw(_ id: String, _ ctx: GraphicsContext, _ s: Scene) {
        let k = max(0.3, min(1, min(s.w, s.h) / 360))
        switch id {
        case "trail": trail(ctx, s, k)
        case "vines": vines(ctx, s, k)
        case "fireflies": fireflies(ctx, s, k)
        case "bubbles": rising(ctx, s, k, count: 16, color: Color(hex: "#7dd3fc"), filled: false, duration: 7)
        case "embers": rising(ctx, s, k, count: 22, color: Palette.flame, filled: true, duration: 4.5)
        case "sakura": petals(ctx, s, k)
        default: ProfileEffectEdges.draw(id, ctx, s, k)
        }
    }

    static func glowStroke(_ ctx: GraphicsContext, _ path: Path, _ color: Color, _ width: Double) {
        ctx.stroke(path, with: .color(color.opacity(0.2)), style: StrokeStyle(lineWidth: width * 3, lineCap: .round, lineJoin: .round))
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private static func trail(_ ctx: GraphicsContext, _ s: Scene, _ k: Double) {
        let edge = s.edge(8 * k)
        ctx.stroke(edge, with: .color(Palette.accent.opacity(0.8)),
                   style: StrokeStyle(lineWidth: 3 * k, lineCap: .round, dash: [CGFloat(2 * k), CGFloat(9 * k)], dashPhase: CGFloat(-s.t * 18 * k)))
        let walker = s.point(on: edge, s.cycle(14))
        ctx.fill(ProfileFrameKit.circle(5 * k, walker.x, walker.y), with: .color(.white))
        ctx.stroke(ProfileFrameKit.circle(5 * k, walker.x, walker.y), with: .color(Palette.accent), lineWidth: 2.5 * k)
    }

    private static let leaf = SVGPath.path("M0 0C4-7 13-7 18 0C13 7 4 7 0 0Z")
    /// Parsed once; effects redraw up to 30 times a second.
    private static let branch = SVGPath.path("M8 74C14 46 30 26 56 14M24 40C30 36 36 36 40 38M40 22C40 16 44 12 48 10")

    private static func vines(_ ctx: GraphicsContext, _ s: Scene, _ k: Double) {
        let stem = Color(hex: "#1d5a2a")
        let greens = ["#2f8f46", "#4caf50", "#3b7d3a"].map { Color(hex: $0) }
        for side in [0.0, 1.0] {
            var vine = Path()
            let steps = 40
            for i in 0...steps {
                let y = s.h * Double(i) / Double(steps)
                let x = 7 * k + 4 * k * sin(y / (30 * k) + side * 2)
                let p = CGPoint(x: side == 0 ? x : s.w - x, y: y)
                if i == 0 { vine.move(to: p) } else { vine.addLine(to: p) }
            }
            ctx.stroke(vine, with: .color(stem.opacity(0.75)), lineWidth: 2 * k)
            let rand = s.random()
            let count = max(4, Int(s.h / (46 * k)))
            for i in 0..<count {
                let y = s.h * (Double(i) + 0.5) / Double(count)
                let x = 7 * k + 4 * k * sin(y / (30 * k) + side * 2)
                let out = i % 2 == 0
                let base = (side == 0 ? 0.0 : 180.0) + (out ? -35 : 35)
                let sway = 9 * sin(s.t * 1.4 + Double(i) + side)
                let scale = k * (0.7 + rand() * 0.5)
                let layer = ProfileFrameKit.placed(ctx, CGPoint(x: side == 0 ? x : s.w - x, y: y), rotation: base + sway, scaleX: scale, scaleY: scale)
                layer.fill(leaf, with: .color(greens[i % 3]))
            }
        }
    }

    private static func fireflies(_ ctx: GraphicsContext, _ s: Scene, _ k: Double) {
        let rand = s.random()
        let edge = s.edge(26 * k)
        for i in 0..<16 {
            let base = s.point(on: edge, rand())
            let speed = 0.3 + rand() * 0.5
            let px: Double = Double(base.x) + 14 * k * sin(s.t * speed + Double(i))
            let py: Double = Double(base.y) + 12 * k * cos(s.t * speed * 1.3 + Double(i) * 2)
            let p = CGPoint(x: px, y: py)
            let glow = s.wave(1.8 + rand() * 2, rand() * 3)
            var halo = ctx
            halo.opacity = 0.3 * glow
            halo.fill(ProfileFrameKit.circle(9 * k, p.x, p.y), with: .color(Color(hex: "#d8ec3a")))
            var core = ctx
            core.opacity = 0.35 + 0.65 * glow
            core.fill(ProfileFrameKit.circle(2.4 * k, p.x, p.y), with: .color(Color(hex: "#f1fb8a")))
        }
    }

    /// Bubbles or embers rising along both sides.
    private static func rising(_ ctx: GraphicsContext, _ s: Scene, _ k: Double, count: Int, color: Color, filled: Bool, duration: Double) {
        let rand = s.random()
        let palette = filled ? ["#ffd166", "#ff9f1c", "#ff6a2b"].map { Color(hex: $0) } : [color]
        for i in 0..<count {
            let left = i % 2 == 0
            let margin = (4 + rand() * 26) * k
            let dur = duration * (0.7 + rand() * 0.6)
            let p = s.cycle(dur, rand() * dur)
            let drift = 6 * k * sin(s.t * 2 + Double(i))
            let x = (left ? margin : s.w - margin) + drift
            let y = s.h * (1.04 - p * (filled ? 0.75 : 1.08))
            let r = (filled ? 1.2 + rand() * 2.2 : 2.5 + rand() * 4) * k
            var dot = ctx
            dot.opacity = filled ? (1 - p) : min(1, (1 - p) * 2)
            let shape = ProfileFrameKit.circle(r, x, y)
            if filled {
                dot.fill(ProfileFrameKit.circle(r * 2.6, x, y), with: .color(palette[i % 3].opacity(0.18)))
                dot.fill(shape, with: .color(palette[i % 3]))
            } else {
                dot.stroke(shape, with: .color(color), lineWidth: 1.2 * k)
                dot.fill(ProfileFrameKit.circle(r * 0.3, x - r * 0.35, y - r * 0.35), with: .color(.white.opacity(0.8)))
            }
        }
    }

    private static func petals(_ ctx: GraphicsContext, _ s: Scene, _ k: Double) {
        let branch = ProfileEffectArt.branch
        let blossoms: [(Double, Double)] = [(10, 64), (30, 30), (44, 20), (58, 12), (38, 38)]
        for mirrored in [false, true] {
            var corner = ctx
            if mirrored {
                corner.translateBy(x: s.w, y: 0)
                corner.scaleBy(x: -1, y: 1)
            }
            corner.scaleBy(x: 1.3 * k, y: 1.3 * k)
            corner.translateBy(x: -8, y: -10)
            corner.stroke(branch, with: .color(Color(hex: "#6b3f2a")), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
            for (i, f) in blossoms.enumerated() {
                corner.fill(ProfileFrameKit.circle(i % 2 == 0 ? 5 : 4, f.0, f.1), with: .color(Color(hex: i % 2 == 0 ? "#ff8fb8" : "#ffb7d0")))
                corner.fill(ProfileFrameKit.circle(1.4, f.0, f.1), with: .color(Color(hex: "#fff4b8")))
            }
        }
        let rand = s.random()
        for i in 0..<14 {
            let left = i % 2 == 0
            let dur = 6 + rand() * 4
            let p = s.cycle(dur, rand() * dur)
            let inset: Double = (10 + rand() * 40) * k
            let sway: Double = 14 * k * sin(p * 6 + Double(i))
            let x: Double = (left ? inset : s.w - inset) + sway
            let y: Double = s.h * (p * 1.1 - 0.05)
            var petal = ProfileFrameKit.placed(ctx, CGPoint(x: x, y: y), rotation: p * 360 + Double(i) * 30, scaleX: k, scaleY: k)
            petal.opacity = min(1, (1 - p) * 3)
            petal.fill(Path(ellipseIn: CGRect(x: -3, y: -4.5, width: 6, height: 9)), with: .color(Color(hex: i % 3 == 0 ? "#ff8fb8" : "#ffb7d0")))
        }
    }
}
