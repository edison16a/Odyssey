//
//  ProfileFramesNature.swift
//  Odyssey
//
//  Nature frames: Sakura, Autumn Trail, Butterflies, Starlight and
//  Aurora. Ported from deco-nature.js. Falling bits use staggered timing
//  so nothing moves in lockstep.
//

import Foundation
import SwiftUI

enum ProfileFramesNature {
    typealias K = ProfileFrameKit

    // Parsed once; these frames redraw up to 30 times a second.
    private static let branch = SVGPath.path("M8 74C14 46 30 26 56 14M24 40C30 36 36 36 40 38M40 22C40 16 44 12 48 10")
    private static let wing = SVGPath.path("M0 0C-8 -10 -14 -4 -10 2C-14 8 -6 10 0 2C6 10 14 8 10 2C14 -4 8 -10 0 0Z")

    static func draw(_ id: String, _ ctx: GraphicsContext, t: Double, tier: Int) -> Bool {
        switch id {
        case "sakura": sakura(ctx, t)
        case "leaves": leaves(ctx, t)
        case "butterflies": butterflies(ctx, t)
        case "starlight": starlight(ctx, t)
        case "aurora": aurora(ctx, t)
        default: return false
        }
        return true
    }

    /// Something drifting down past the frame, from the mockup's falling() helper.
    private static func falling(_ ctx: GraphicsContext, _ t: Double, index: Int, x: Double, duration: Double,
                                draw: (GraphicsContext) -> Void) {
        let begin = Double(index) * 1.1
        let dx = K.keys(t, duration, [0, 8, -4], begin: begin)
        let dy = K.keys(t, duration, [-8, 70, 150], begin: begin)
        var layer = K.placed(ctx, CGPoint(x: x + dx, y: dy))
        layer.opacity = K.keys(t, duration, [0, 1, 1, 0], begin: begin)
        draw(layer)
    }

    private static func blossom(_ ctx: GraphicsContext, _ x: Double, _ y: Double, _ scale: Double, _ color: Color) {
        let layer = K.placed(ctx, CGPoint(x: x, y: y), scaleX: scale, scaleY: scale)
        for i in 0..<5 {
            let petal = K.placed(layer, .zero, rotation: Double(i) * 72)
            petal.fill(Path(ellipseIn: CGRect(x: -2.6, y: -6.8, width: 5.2, height: 7.2)), with: .color(color))
        }
        layer.fill(K.circle(1.6, 0, 0), with: .color(Color(hex: "#fff4b8")))
    }

    private static func sakura(_ ctx: GraphicsContext, _ t: Double) {
        K.ring(ctx, 53, Color(hex: "#ff8fb8"), 3)
        ctx.stroke(ProfileFramesNature.branch,
                   with: .color(Color(hex: "#6b3f2a")), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
        let flowers: [(Double, Double, Double)] = [(10, 64, 1.3), (17, 47, 1.1), (30, 30, 1.4), (44, 20, 1), (58, 12, 1.2), (38, 38, 0.9), (49, 10, 0.8)]
        for (i, f) in flowers.enumerated() {
            blossom(ctx, f.0, f.1, f.2, Color(hex: i % 2 == 1 ? "#ffb7d0" : "#ff8fb8"))
        }
        for i in 0..<4 {
            falling(ctx, t, index: i, x: 70 + Double(i) * 14, duration: 4 + Double(i) * 0.6) { layer in
                let petal = K.placed(layer, .zero, rotation: 30)
                petal.fill(Path(ellipseIn: CGRect(x: -2.4, y: -3.4, width: 4.8, height: 6.8)), with: .color(Color(hex: "#ffb7d0")))
            }
        }
    }

    private static let leafShape = SVGPath.path("M0 -7C5 -5 6 1 0 7C-6 1 -5 -5 0 -7ZM0 -7V7")

    private static func leaves(_ ctx: GraphicsContext, _ t: Double) {
        K.ring(ctx, 53, Color(hex: "#b45309"), 3)
        let colors = ["#ea580c", "#f59e0b", "#b91c1c", "#d97706"].map { Color(hex: $0) }
        var i = 0
        for deg in stride(from: 120.0, through: 240, by: 15) {
            let layer = K.placed(ctx, K.at(57, deg), rotation: deg + 90)
            layer.fill(leafShape, with: .color(colors[i % 4]))
            layer.stroke(leafShape, with: .color(Color(hex: "#7c2d12")), lineWidth: 0.6)
            i += 1
        }
        for j in 0..<3 {
            falling(ctx, t, index: j, x: 24 + Double(j) * 40, duration: 5 + Double(j)) { layer in
                layer.fill(leafShape, with: .color(colors[j]))
            }
        }
    }

    private static func butterflies(_ ctx: GraphicsContext, _ t: Double) {
        K.ring(ctx, 53, Color(hex: "#8b5cf6"), 2.5)
        let wing = ProfileFramesNature.wing
        let flies: [(String, Double, Double, Double)] = [("#60a5fa", 60, 9, 0), ("#fb923c", 62, 12, -4), ("#f472b6", 58, 15, -9)]
        for fly in flies {
            let orbit = K.rotated(ctx, K.cycle(t, fly.2, fly.3) * 360)
            let flap = K.keys(t, 0.35, [1, 0.25, 1])
            let body = K.placed(orbit, CGPoint(x: 68, y: 68 - fly.1))
            let wings = K.placed(body, .zero, scaleX: flap)
            wings.fill(wing, with: .color(Color(hex: fly.0)))
            wings.stroke(wing, with: .color(Color(hex: "#1e1b4b")), lineWidth: 0.7)
            body.fill(Path(roundedRect: CGRect(x: -0.8, y: -4, width: 1.6, height: 9), cornerRadius: 0.8), with: .color(Color(hex: "#1e1b4b")))
        }
    }

    private static func starlight(_ ctx: GraphicsContext, _ t: Double) {
        K.ring(ctx, 53, Color(hex: "#1e293b"), 3.5)
        K.ring(ctx, 57, Palette.gold, 0.9, opacity: 0.7)
        for i in 0..<9 {
            let deg = Double(i) * 40 + 10
            let scale = i % 3 == 0 ? 1.3 : 0.8
            var layer = K.placed(ctx, K.at(60, deg), scaleX: scale, scaleY: scale)
            layer.opacity = K.twinkle(t, i, 2 + Double(i % 3) * 0.6)
            layer.fill(K.star, with: .color(Color(hex: "#fde68a")))
        }
    }

    private static func aurora(_ ctx: GraphicsContext, _ t: Double) {
        let bands: [(Double, String, Double, Double)] = [(56, "#34d399", 7, -110), (60, "#22d3ee", 9, -60), (55, "#a78bfa", 11, 20)]
        for band in bands {
            var arc = Path()
            arc.addArc(center: K.center, radius: band.0, startAngle: .degrees(band.3 - 90),
                       endAngle: .degrees(band.3 + 60), clockwise: false)
            var layer = K.rotated(ctx, K.keys(t, band.2, [0, 40, 0]))
            layer.opacity = K.keys(t, band.2 * 0.7, [0.35, 0.85, 0.35])
            layer.stroke(arc, with: .color(Color(hex: band.1).opacity(0.25)), style: StrokeStyle(lineWidth: 14, lineCap: .round))
            layer.stroke(arc, with: .color(Color(hex: band.1)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        }
        K.ring(ctx, 52, Color(hex: "#0f172a"), 2.5)
    }
}
