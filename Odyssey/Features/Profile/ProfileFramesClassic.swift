//
//  ProfileFramesClassic.swift
//  Odyssey
//
//  Classic and elemental frames: Mono, Explorer Blue, Orbit, Topographic,
//  Compass Rose, Laurel, Tide, Frostbite, Lightning, Wildfire, Dual
//  Element and Neon Night. Ported from deco-classic.js and deco-elements.js.
//

import Foundation
import SwiftUI

enum ProfileFramesClassic {
    typealias K = ProfileFrameKit

    // Parsed once; these frames redraw up to 30 times a second.
    private static let tagShape = SVGPath.path("M63 116 74 113 72 124 61 127z")
    private static let ribbon = SVGPath.path("M58 122q10 -6 20 0l-4 10-6-4-6 4z")
    private static let bolt = SVGPath.path("M2 -16L-5 -2H0L-3 12L6 -4H1Z")
    private static let iceArc = SVGPath.path("M68 15A53 53 0 0 1 68 121")
    private static let fireArc = SVGPath.path("M68 121A53 53 0 0 1 68 15")

    /// Draws the frame if it is one of these. Returns false for other ids.
    static func draw(_ id: String, _ ctx: GraphicsContext, t: Double) -> Bool {
        switch id {
        case "mono":
            K.ring(ctx, 53, Palette.ink, 4.5)
            K.ring(ctx, 59, Palette.ink, 1.2, opacity: 0.5)
        case "accent":
            K.ring(ctx, 53, Palette.accent, 4.5)
            ctx.fill(ProfileFramesClassic.tagShape, with: .color(Palette.accent))
            ctx.stroke(ProfileFramesClassic.tagShape, with: .color(.white), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        case "orbit": orbit(ctx, t)
        case "topo": topo(ctx, t)
        case "compass": compass(ctx, t)
        case "laurel": laurel(ctx, t)
        case "tide": tide(ctx, t)
        case "frost": frost(ctx, t)
        case "lightning": lightning(ctx, t)
        case "fire": fire(ctx, t)
        case "dual": dual(ctx, t)
        case "neon": neon(ctx, t)
        default: return false
        }
        return true
    }

    private static func orbit(_ ctx: GraphicsContext, _ t: Double) {
        K.ring(ctx, 59, Palette.ink, 1.2, opacity: 0.55, dash: [2, 4])
        K.ring(ctx, 53, Palette.ink, 3)
        let moon = K.rotated(ctx, K.cycle(t, 7) * 360)
        moon.fill(K.circle(6, 68, 9), with: .color(Palette.accent))
        moon.stroke(K.circle(6, 68, 9), with: .color(.white), lineWidth: 2)
        var shine = moon
        shine.opacity = 0.7
        shine.fill(K.circle(1.6, 66, 7.5), with: .color(.white))
        let small = K.rotated(ctx, -K.cycle(t, 11) * 360)
        small.fill(K.circle(3, 68, 128), with: .color(Palette.gold))
    }

    private static func topo(_ ctx: GraphicsContext, _ t: Double) {
        let colors = ["#2b59ff", "#4f78ff", "#8ea8ff", "#c9d6ff"]
        for (i, hex) in colors.enumerated() {
            let swing = K.keys(t, 8 + Double(i) * 2, [0, i % 2 == 1 ? -8 : 8, 0])
            let layer = K.rotated(ctx, swing)
            layer.stroke(K.wavy(54 + Double(i) * 3.4, amp: 1.8, lobes: 5, phase: Double(i)),
                         with: .color(Color(hex: hex)), lineWidth: i == 0 ? 2.4 : 1.2)
        }
    }

    private static func compass(_ ctx: GraphicsContext, _ t: Double) {
        K.ring(ctx, 59, Color(hex: "#f6f1e4"), 14, opacity: 0.95)
        let wobble = K.keys(t, 6, [0, 10, -7, 3, 0])
        let dial = K.rotated(ctx, wobble)
        for i in 0..<48 {
            let deg = Double(i) * 7.5
            var tick = Path()
            tick.move(to: K.at(58, deg))
            tick.addLine(to: K.at(i % 12 == 0 ? 51 : i % 4 == 0 ? 54 : 56, deg))
            dial.stroke(tick, with: .color(Palette.ink), lineWidth: i % 12 == 0 ? 2 : 0.9)
        }
        for (letter, deg) in [("N", 0.0), ("E", 90.0), ("S", 180.0), ("W", 270.0)] {
            let text = Text(letter).font(.system(size: 9, weight: .heavy))
                .foregroundColor(letter == "N" ? Palette.danger : Palette.ink)
            dial.draw(text, at: K.at(64.5, deg), anchor: .center)
        }
        K.ring(ctx, 52, Palette.ink, 2.5)
    }

    private static func laurel(_ ctx: GraphicsContext, _ t: Double) {
        K.ring(ctx, 52, Color(hex: "#d9a520"), 3)
        let leaf = Path(ellipseIn: CGRect(x: -3.4, y: -8, width: 6.8, height: 16))
        var angles: [(Double, Double)] = []
        for deg in stride(from: 200.0, through: 330, by: 13) { angles.append((deg, deg - 50)) }
        for deg in stride(from: 30.0, through: 160, by: 13) { angles.append((deg, deg + 50)) }
        for (deg, tilt) in angles {
            let layer = K.placed(ctx, K.at(57, deg), rotation: tilt)
            layer.fill(leaf, with: .color(Color(hex: "#d9a520")))
            layer.stroke(leaf, with: .color(Color(hex: "#9a6a00")), lineWidth: 0.8)
        }
        let ribbon = ProfileFramesClassic.ribbon
        ctx.fill(ribbon, with: .color(Color(hex: "#c0392b")))
        ctx.stroke(ribbon, with: .color(Color(hex: "#7f1d1d")), lineWidth: 0.8)
        ctx.fill(K.circle(3.5, 68, 120), with: .color(Palette.gold))
        ctx.stroke(K.circle(3.5, 68, 120), with: .color(Color(hex: "#9a6a00")), lineWidth: 0.8)
        K.ring(ctx, 56, .white, 3, opacity: 0.8, dash: [14, 340], phase: CGFloat(-K.cycle(t, 3.5) * 354))
    }

    private static func tide(_ ctx: GraphicsContext, _ t: Double) {
        let inner = K.rotated(ctx, K.cycle(t, 16) * 360)
        inner.stroke(K.wavy(53, amp: 2.4, lobes: 9, phase: 0, second: false), with: .color(Color(hex: "#0369a1")), lineWidth: 3)
        let outer = K.rotated(ctx, -K.cycle(t, 22) * 360)
        outer.stroke(K.wavy(58, amp: 2.4, lobes: 9, phase: 0, second: false), with: .color(Color(hex: "#38bdf8")), lineWidth: 3)
        for i in 0..<4 {
            let dur = 2.4 + Double(i) * 0.5
            let k = K.cycle(t, dur, Double(i) * 0.7)
            var bubble = ctx
            bubble.opacity = 1 - k
            let x = i % 2 == 1 ? 122.0 : 14.0
            bubble.stroke(K.circle(Double(2 + i % 2), x, 118 - 88 * k), with: .color(Color(hex: "#7dd3fc")), lineWidth: 1.2)
        }
    }

    private static func frost(_ ctx: GraphicsContext, _ t: Double) {
        K.glowRing(ctx, 53, Color(hex: "#bae6fd"), 4)
        K.ring(ctx, 53, .white, 1.2, dash: [1, 7])
        var shards = ctx
        shards.opacity = K.keys(t, 3, [0.7, 1, 0.7])
        for i in 0..<10 {
            let deg = Double(i) * 36 + 18
            K.drawShard(shards, at: K.at(57, deg), degrees: deg, color: Color(hex: i % 2 == 1 ? "#bae6fd" : "#7dd3fc"))
        }
        for i in 0..<3 {
            let k = K.cycle(t, 4 + Double(i), Double(i) * 1.3)
            let flake = Text("*").font(.system(size: 9)).foregroundColor(Color(hex: "#e0f2fe"))
            ctx.draw(flake, at: CGPoint(x: 30 + Double(i) * 36, y: -6 + 142 * k), anchor: .center)
        }
    }

    private static func lightning(_ ctx: GraphicsContext, _ t: Double) {
        K.glowRing(ctx, 53, Color(hex: "#38bdf8"), 3.5)
        K.ring(ctx, 53, Color(hex: "#e0f7ff"), 1.6, dash: [10, 6, 3, 9], phase: CGFloat(-K.cycle(t, 0.9) * 56))
        let bolt = ProfileFramesClassic.bolt
        for i in 0..<6 {
            let deg = Double(i) * 60 + 15
            var layer = K.placed(ctx, K.at(58, deg), rotation: deg)
            layer.opacity = K.keys(t, 1.1 + Double(i) * 0.13, [1, 0, 1, 1, 0.3, 1], times: [0, 0.1, 0.2, 0.6, 0.7, 1])
            layer.fill(bolt, with: .color(Color(hex: "#e0f7ff")))
            layer.stroke(bolt, with: .color(Color(hex: "#38bdf8")), style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
        }
    }

    private static func fire(_ ctx: GraphicsContext, _ t: Double) {
        var i = 0
        for deg in stride(from: -120.0, through: 120, by: 20) {
            K.drawFlame(ctx, at: K.at(51, deg), degrees: deg, index: i, t: t,
                        outer: Color(hex: i % 2 == 0 ? "#ff5a1f" : "#ff7a1f"), inner: Color(hex: "#ffe27a"), height: 18 + Double(i % 3) * 5)
            i += 1
        }
        for e in 0..<5 {
            let dur = 1.6 + Double(e) * 0.3
            let k = K.cycle(t, dur, Double(e) * 0.4)
            var ember = ctx
            ember.opacity = 1 - k
            ember.fill(K.circle(1.6, 40 + Double(e) * 14, 22 - 26 * k), with: .color(Color(hex: "#ffb347")))
        }
        K.ring(ctx, 52, Palette.flame, 3.5)
    }

    private static func dual(_ ctx: GraphicsContext, _ t: Double) {
        let spin = K.rotated(ctx, K.cycle(t, 14) * 360)
        var i = 0
        for deg in stride(from: 200.0, through: 340, by: 20) {
            K.drawFlame(spin, at: K.at(51, deg), degrees: deg, index: i, t: t,
                        outer: Color(hex: "#ff5a1f"), inner: Color(hex: "#ffd36b"), height: 16 + Double(i % 2) * 6)
            i += 1
        }
        for deg in stride(from: 20.0, through: 160, by: 20) {
            K.drawShard(spin, at: K.at(56, deg), degrees: deg, color: Color(hex: "#7dd3fc"))
        }
        spin.stroke(ProfileFramesClassic.iceArc, with: .color(Color(hex: "#38bdf8")), lineWidth: 4)
        spin.stroke(ProfileFramesClassic.fireArc, with: .color(Color(hex: "#ff5a1f")), lineWidth: 4)
    }

    private static func neon(_ ctx: GraphicsContext, _ t: Double) {
        var pink = ctx
        pink.opacity = K.keys(t, 3.2, [1, 1, 0.25, 1, 0.7, 1], times: [0, 0.5, 0.53, 0.56, 0.6, 1])
        K.glowRing(pink, 53, Color(hex: "#ff2bd6"), 3.2)
        var cyan = K.rotated(ctx, -K.cycle(t, 18) * 360)
        cyan.opacity = K.keys(t, 2.3, [1, 0.3, 1, 1], times: [0, 0.05, 0.1, 1])
        K.ring(cyan, 59, Color(hex: "#22d3ee"), 5, opacity: 0.18, dash: [40, 8])
        K.ring(cyan, 59, Color(hex: "#22d3ee"), 2, dash: [40, 8])
    }
}
