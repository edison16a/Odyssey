//
//  ProfileFramesLegend.swift
//  Odyssey
//
//  Prestige frames: Gilded, Halo, Cosmos, the Steward Crown and the Rank
//  frame, which takes your tier color so it changes on its own as you
//  climb. Ported from deco-legend.js.
//

import Foundation
import SwiftUI

enum ProfileFramesLegend {
    typealias K = ProfileFrameKit

    // Parsed once; these frames redraw up to 30 times a second.
    private static let gem = SVGPath.path("M0 -4.5L4 0L0 4.5L-4 0Z")
    private static let wing = SVGPath.path("M20 78C6 78 -2 66 1 52C6 60 11 62 16 62C8 58 5 50 7 42C12 52 17 55 22 56C16 52 15 46 17 40C22 50 26 54 30 56Z")
    private static let tail = SVGPath.path("M68 6l-10 -2 10 4z")
    private static let crownShape = SVGPath.path("M46 20L42 -2L56 10L68 -6L80 10L94 -2L90 20Z")
    private static let crownBase = SVGPath.path("M44 20H92")

    static func draw(_ id: String, _ ctx: GraphicsContext, t: Double, tier: Int) -> Bool {
        switch id {
        case "gilded": gilded(ctx, t)
        case "halo": halo(ctx, t)
        case "cosmos": cosmos(ctx, t)
        case "crown": crown(ctx, t)
        case "rank": rank(ctx, t, tier: tier)
        default: return false
        }
        return true
    }

    private static func gilded(_ ctx: GraphicsContext, _ t: Double) {
        K.ring(ctx, 54, Color(hex: "#e0a614"), 7)
        K.ring(ctx, 54, Color(hex: "#ffe08a"), 1.4, opacity: 0.7)
        K.ring(ctx, 54, Color(hex: "#7a5200"), 0.8, opacity: 0.6)
        let gems = ["#e5484d", "#2b59ff", "#17a35a", "#8a5cff"].map { Color(hex: $0) }
        let gem = ProfileFramesLegend.gem
        for i in 0..<8 {
            let deg = Double(i) * 45 + 22.5
            let layer = K.placed(ctx, K.at(54, deg), rotation: deg)
            layer.fill(gem, with: .color(gems[i % 4]))
            layer.stroke(gem, with: .color(Color(hex: "#fff4c2")), lineWidth: 1.2)
        }
        K.sweep(ctx, 54, t: t)
    }

    private static func halo(_ ctx: GraphicsContext, _ t: Double) {
        let bob = K.keys(t, 2.6, [0, -3, 0])
        let ring = Path(ellipseIn: CGRect(x: 42, y: 3.5 + bob, width: 52, height: 13))
        ctx.stroke(ring, with: .color(Color(hex: "#fde68a").opacity(0.3)), lineWidth: 9)
        ctx.stroke(ring, with: .color(Color(hex: "#fde68a")), lineWidth: 4)
        let wing = ProfileFramesLegend.wing
        for mirrored in [false, true] {
            var layer = ctx
            if mirrored {
                layer.translateBy(x: 136, y: 0)
                layer.scaleBy(x: -1, y: 1)
            }
            layer.fill(wing, with: .color(.white))
            layer.stroke(wing, with: .color(Color(hex: "#cbd5e1")), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
        }
        K.ring(ctx, 53, Color(hex: "#fde68a"), 2.5)
        for i in 0..<5 {
            var dot = ctx
            dot.opacity = K.twinkle(t, i)
            let p = K.at(60, Double(i) * 72 + 100)
            dot.fill(K.circle(1.6, p.x, p.y), with: .color(Color(hex: "#fde68a")))
        }
    }

    private static func cosmos(_ ctx: GraphicsContext, _ t: Double) {
        K.ring(ctx, 53, Color(hex: "#1e1b4b"), 4)
        for i in 0..<12 {
            var dot = ctx
            dot.opacity = K.twinkle(t, i, 1.8 + Double(i % 4) * 0.5)
            let p = K.at(61, Double(i) * 30 + 7)
            dot.fill(K.circle(i % 3 == 0 ? 1.6 : 0.9, p.x, p.y), with: .color(.white))
        }
        let tilt = K.rotated(ctx, -24)
        let band = Path(ellipseIn: CGRect(x: 2, y: 52, width: 132, height: 32))
        tilt.stroke(band, with: .color(Color(hex: "#a78bfa").opacity(0.25)), style: StrokeStyle(lineWidth: 7, dash: [150, 30]))
        tilt.stroke(band, with: .color(Color(hex: "#8f9bff")), style: StrokeStyle(lineWidth: 3, dash: [150, 30]))
        let comet = K.rotated(ctx, K.cycle(t, 5) * 360)
        comet.fill(K.circle(3, 68, 6), with: .color(.white))
        var tail = comet
        tail.opacity = 0.8
        tail.fill(ProfileFramesLegend.tail, with: .color(Color(hex: "#a5f3fc")))
    }

    private static func crown(_ ctx: GraphicsContext, _ t: Double) {
        K.ring(ctx, 53, Color(hex: "#e0a614"), 4.5)
        let tilted = K.rotated(ctx, -14)
        let shape = ProfileFramesLegend.crownShape
        tilted.fill(shape, with: .color(Color(hex: "#e0a614")))
        tilted.stroke(shape, with: .color(Color(hex: "#7a5200")), style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
        tilted.fill(K.circle(3, 68, 12), with: .color(Palette.danger))
        tilted.fill(K.circle(2.2, 54, 15), with: .color(Palette.accent))
        tilted.fill(K.circle(2.2, 82, 15), with: .color(Palette.success))
        tilted.stroke(ProfileFramesLegend.crownBase, with: .color(Color(hex: "#7a5200")), lineWidth: 1.5)
        K.sweep(ctx, 53, t: t)
    }

    private static func rank(_ ctx: GraphicsContext, _ t: Double, tier: Int) {
        let color = RankEmblem.color(for: tier)
        K.glowRing(ctx, 53, color, 4.5)
        for i in 0..<6 {
            var dot = ctx
            dot.opacity = K.twinkle(t, i, 3)
            let p = K.at(58, Double(i) * 60 + 30)
            dot.fill(K.circle(1.8, p.x, p.y), with: .color(color))
        }
        var emblem = ctx
        emblem.translateBy(x: 51, y: 104)
        emblem.scaleBy(x: 34 / 48, y: 34 / 48)
        RankEmblem.draw(in: emblem, tier: tier, fill: color, mark: .white, shine: true)
    }
}
