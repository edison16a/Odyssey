//
//  ProfileEffectEdges.swift
//  Odyssey
//
//  The profile effects that live on the edge itself: Constellation,
//  Frost, Energy, Neon, Aurora and Gilded. Ported in spirit from the
//  mockup's fx-energy.js and fx-explorer.js.
//

import Foundation
import SwiftUI

enum ProfileEffectEdges {
    typealias Scene = ProfileEffectScene

    /// Parsed once; effects redraw up to 30 times a second.
    private static let gem = SVGPath.path("M0 -6L5 0L0 6L-5 0Z")

    static func draw(_ id: String, _ ctx: GraphicsContext, _ s: Scene, _ k: Double) {
        switch id {
        case "constellation": constellation(ctx, s, k)
        case "frost": frost(ctx, s, k)
        case "energy": energy(ctx, s, k)
        case "neon": neon(ctx, s, k)
        case "aurora": aurora(ctx, s, k)
        case "gilded": gilded(ctx, s, k)
        default: break
        }
    }

    private static func constellation(_ ctx: GraphicsContext, _ s: Scene, _ k: Double) {
        let rand = s.random()
        let edge = s.edge(22 * k)
        let points = (0..<14).map { i -> CGPoint in
            let p = s.point(on: edge, Double(i) / 14 + rand() * 0.03)
            let dx: Double = (rand() - 0.5) * 18 * k
            let dy: Double = (rand() - 0.5) * 18 * k
            return CGPoint(x: Double(p.x) + dx, y: Double(p.y) + dy)
        }
        var lines = Path()
        for (i, p) in points.enumerated() {
            if i == 0 { lines.move(to: p) } else { lines.addLine(to: p) }
        }
        lines.closeSubpath()
        ctx.stroke(lines, with: .color(Color(hex: "#8a5cff").opacity(0.35)), lineWidth: 1 * k)
        for (i, p) in points.enumerated() {
            var star = ProfileFrameKit.placed(ctx, p, scaleX: k * (i % 3 == 0 ? 0.9 : 0.55), scaleY: k * (i % 3 == 0 ? 0.9 : 0.55))
            star.opacity = ProfileFrameKit.twinkle(s.t, i, 2.6)
            star.fill(ProfileFrameKit.star, with: .color(i % 3 == 0 ? .white : Color(hex: "#c4b5fd")))
        }
    }

    private static func frost(_ ctx: GraphicsContext, _ s: Scene, _ k: Double) {
        ProfileEffectArt.glowStroke(ctx, s.edge(3 * k), Color(hex: "#bae6fd"), 2 * k)
        let corners = [CGPoint(x: 0, y: 0), CGPoint(x: s.w, y: 0), CGPoint(x: 0, y: s.h), CGPoint(x: s.w, y: s.h)]
        for (i, c) in corners.enumerated() {
            var layer = ctx
            layer.opacity = 0.6 + 0.4 * s.wave(3, Double(i) * 0.7)
            let ix: Double = c.x == 0 ? 1 : -1
            let iy: Double = c.y == 0 ? 1 : -1
            for arm in 0..<5 {
                let angle = Double(arm) * 22.5 * .pi / 180
                let length = (34 + Double(arm % 2) * 16) * k
                let cx = Double(c.x)
                let cy = Double(c.y)
                let ex: Double = cx + ix * cos(angle) * length
                let ey: Double = cy + iy * sin(angle) * length
                let end = CGPoint(x: ex, y: ey)
                var line = Path()
                line.move(to: CGPoint(x: cx + ix * 6 * k, y: cy + iy * 6 * k))
                line.addLine(to: end)
                layer.stroke(line, with: .color(Color(hex: "#e0f2fe")), lineWidth: 1.3 * k)
                layer.fill(ProfileFrameKit.circle(1.6 * k, end.x, end.y), with: .color(.white))
            }
        }
    }

    private static func energy(_ ctx: GraphicsContext, _ s: Scene, _ k: Double) {
        let edge = s.edge(3 * k)
        ctx.stroke(edge, with: .color(Palette.accent.opacity(0.18)), lineWidth: 2 * k)
        let runners: [(Double, Double, Color, Double)] = [(0.14, 3.2, Palette.accent, 3.5), (0.08, 2.1, Color(hex: "#7cf7ff"), 2.5), (0.05, 4.4, .white, 2)]
        for (i, r) in runners.enumerated() {
            let start = s.cycle(r.1, Double(i) * 0.9)
            var segment = edge.trimmedPath(from: start, to: min(1, start + r.0))
            if start + r.0 > 1 { segment.addPath(edge.trimmedPath(from: 0, to: start + r.0 - 1)) }
            ProfileEffectArt.glowStroke(ctx, segment, r.2, r.3 * k)
        }
    }

    private static func neon(_ ctx: GraphicsContext, _ s: Scene, _ k: Double) {
        var pink = ctx
        pink.opacity = ProfileFrameKit.keys(s.t, 3.2, [1, 1, 0.25, 1, 0.7, 1], times: [0, 0.5, 0.53, 0.56, 0.6, 1])
        ProfileEffectArt.glowStroke(pink, s.edge(4 * k), Color(hex: "#ff2bd6"), 3 * k)
        ctx.stroke(s.edge(10 * k), with: .color(Color(hex: "#22d3ee")),
                   style: StrokeStyle(lineWidth: 2 * k, dash: [CGFloat(40 * k), CGFloat(10 * k)], dashPhase: CGFloat(s.t * 30 * k)))
    }

    private static func aurora(_ ctx: GraphicsContext, _ s: Scene, _ k: Double) {
        let colors = ["#34d399", "#22d3ee", "#a78bfa"].map { Color(hex: $0) }
        for (i, color) in colors.enumerated() {
            var ribbon = Path()
            let base = (26 + Double(i) * 18) * k
            for step in 0...40 {
                let x = s.w * Double(step) / 40
                let speed: Double = 0.5 + Double(i) * 0.15
                let phase: Double = x / (60 * k) + s.t * speed + Double(i)
                let y: Double = base + 12 * k * sin(phase)
                if step == 0 { ribbon.move(to: CGPoint(x: x, y: y)) } else { ribbon.addLine(to: CGPoint(x: x, y: y)) }
            }
            var layer = ctx
            layer.opacity = 0.35 + 0.35 * s.wave(5 + Double(i) * 2)
            layer.stroke(ribbon, with: .color(color.opacity(0.3)), style: StrokeStyle(lineWidth: 16 * k, lineCap: .round))
            layer.stroke(ribbon, with: .color(color), style: StrokeStyle(lineWidth: 5 * k, lineCap: .round))
        }
        for (i, x) in [0.0, s.w - 14 * k].enumerated() {
            var side = ctx
            side.opacity = 0.1 + 0.25 * s.wave(4 + Double(i), Double(i))
            side.fill(Path(CGRect(x: x, y: 0, width: 14 * k, height: s.h * 0.7)), with: .color(colors[i + 1]))
        }
    }

    private static func gilded(_ ctx: GraphicsContext, _ s: Scene, _ k: Double) {
        let edge = s.edge(4 * k)
        ctx.stroke(edge, with: .color(Color(hex: "#d9a520")), lineWidth: 3 * k)
        ctx.stroke(s.edge(9 * k), with: .color(Color(hex: "#a87b1f").opacity(0.6)), lineWidth: 0.8 * k)
        let start = s.cycle(4)
        ctx.stroke(edge.trimmedPath(from: start, to: min(1, start + 0.05)), with: .color(Color(hex: "#fffbe6")),
                   style: StrokeStyle(lineWidth: 3 * k, lineCap: .round))
        let gem = ProfileEffectEdges.gem
        let inset = 14 * k
        for c in [CGPoint(x: inset, y: inset), CGPoint(x: s.w - inset, y: inset), CGPoint(x: inset, y: s.h - inset), CGPoint(x: s.w - inset, y: s.h - inset)] {
            let layer = ProfileFrameKit.placed(ctx, c, rotation: 45, scaleX: k, scaleY: k)
            layer.fill(gem, with: .color(Color(hex: "#f2b21b")))
            layer.stroke(gem, with: .color(Color(hex: "#7a5200")), lineWidth: 1)
        }
    }
}
