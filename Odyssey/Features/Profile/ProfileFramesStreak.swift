//
//  ProfileFramesStreak.swift
//  Odyssey
//
//  Streak frames, one per Globie form, earned at streak milestones. Each is
//  a glowing ring in the tier's color with that form's motif around it: a
//  pulse, orbiting sparks, flames, stars, golden rays, aurora ribbons, ice
//  shards, shockwaves, a corona or a rainbow orbit. From deco-streak.js.
//

import Foundation
import SwiftUI

enum ProfileFramesStreak {
    typealias K = ProfileFrameKit

    // Parsed once; these frames redraw up to 30 times a second.
    private static let ray = SVGPath.path("M0 0L-1.6 -9L1.6 -9Z")
    private static let crystal = SVGPath.path("M0 -8L3 0L0 4L-3 0Z")

    static func draw(_ tier: StreakTier, _ ctx: GraphicsContext, t: Double) {
        K.glowRing(ctx, 53, tier.color, 4)
        K.ring(ctx, 53, .white, 1, opacity: 0.6)
        switch tier.id {
        case "glow":
            K.ring(ctx, K.keys(t, 2.4, [55, 62, 55]), tier.color, 2, opacity: K.keys(t, 2.4, [0.6, 0, 0.6]))
        case "spark":
            let spin = K.rotated(ctx, K.cycle(t, 8) * 360)
            for i in 0..<6 {
                let p = K.at(58, Double(i) * 60)
                var s = spin
                s.opacity = K.keys(t, 1.8, [0, 1, 0], begin: Double(i) * 0.3)
                s.fill(K.sparkle(p.x, p.y, 5), with: .color(Color(hex: i % 2 == 1 ? "#fff3b0" : "#ffd23f")))
            }
        case "fire":
            for i in 0..<9 {
                let deg = Double(i) * 40
                let h = 10 + 9 * max(0, cos(deg * .pi / 180))
                var flame = Path()
                flame.move(to: CGPoint(x: -5, y: 0))
                flame.addQuadCurve(to: CGPoint(x: 0, y: -h), control: CGPoint(x: -2, y: -h * 0.6))
                flame.addQuadCurve(to: CGPoint(x: 5, y: 0), control: CGPoint(x: 2, y: -h * 0.6))
                flame.closeSubpath()
                var layer = K.placed(ctx, K.at(55, deg), rotation: deg)
                layer.opacity = K.keys(t, 0.6 + Double(i % 3) * 0.2, [0.6, 1, 0.6])
                layer.fill(flame, with: .color(Color(hex: i % 2 == 1 ? "#ff3d00" : "#ff9a1f")))
            }
        case "galaxy":
            let spin = K.rotated(ctx, K.cycle(t, 20) * 360)
            for i in 0..<14 {
                let p = K.at(59, Double(i) * 360 / 14)
                var dot = spin
                dot.opacity = K.twinkle(t, i, 2)
                dot.fill(K.circle(i % 3 == 0 ? 1.8 : 1, p.x, p.y), with: .color(.white))
            }
        case "gold":
            var spin = K.rotated(ctx, K.cycle(t, 18) * 360)
            spin.opacity = 0.7
            for i in 0..<16 {
                let deg = Double(i) * 22.5
                K.placed(spin, K.at(60, deg), rotation: deg).fill(ProfileFramesStreak.ray, with: .color(Color(hex: "#ffd23f")))
            }
        case "aurora":
            for (i, hex) in ["#2ee6a6", "#7cf7ff", "#b896ff"].enumerated() {
                let direction: Double = i % 2 == 1 ? -1 : 1
                let layer = K.rotated(ctx, Double(i) * 120 + direction * K.cycle(t, 6 + Double(i) * 2) * 360)
                K.ring(layer, 58 + Double(i) * 3, Color(hex: hex), 2.5, opacity: 0.8, dash: [30, 60])
            }
        case "crystal":
            for i in 0..<8 {
                let deg = Double(i) * 45 + 22
                var layer = K.placed(ctx, K.at(59, deg), rotation: deg)
                layer.opacity = K.keys(t, 2.4, [0.6, 1, 0.6], begin: Double(i) * 0.3)
                layer.fill(ProfileFramesStreak.crystal, with: .color(Color(hex: i % 2 == 1 ? "#e8fbff" : "#8fe3ff")))
            }
        case "supernova":
            for i in 0..<2 {
                let k = K.cycle(t, 2, Double(i))
                K.ring(ctx, 53 + 13 * k, Color(hex: "#ffb703"), 2, opacity: 1 - k)
            }
        case "eclipse":
            K.ring(ctx, 55, Color(hex: "#ffb703"), 5, opacity: 0.9)
            var spin = K.rotated(ctx, -K.cycle(t, 30) * 360)
            spin.opacity = 0.6
            for i in 0..<20 {
                let deg = Double(i) * 18
                let length: Double = i % 2 == 1 ? 6 : 10
                var ray = Path()
                ray.move(to: .zero)
                ray.addLine(to: CGPoint(x: -1, y: -length))
                ray.addLine(to: CGPoint(x: 1, y: -length))
                ray.closeSubpath()
                K.placed(spin, K.at(59, deg), rotation: deg).fill(ray, with: .color(Color(hex: "#ffd166")))
            }
        case "legend":
            let spin = K.rotated(ctx, K.cycle(t, 5) * 360)
            for (i, hex) in ["#ff4fd8", "#ffd23f", "#7cf7ff", "#9b6bff"].enumerated() {
                K.ring(spin, 58, Color(hex: hex), 3, dash: [22, 69], phase: CGFloat(i * 23), round: true)
            }
        default:
            break
        }
    }
}
