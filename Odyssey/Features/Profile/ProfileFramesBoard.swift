//
//  ProfileFramesBoard.swift
//  Odyssey
//
//  The leaderboard frames: a silver laurel for the top 100 and a golden
//  laurel for the top 10, each with a ring around the face and a small
//  star at the crown of the wreath that glints now and then.
//

import Foundation
import SwiftUI

enum ProfileFramesBoard {
    typealias K = ProfileFrameKit

    static func draw(_ id: String, _ ctx: GraphicsContext, t: Double) -> Bool {
        switch id {
        case "laurel-gold": laurel(ctx, t, main: Color(hex: "#f2b21b"), deep: Color(hex: "#a86f00"))
        case "laurel-silver": laurel(ctx, t, main: Color(hex: "#c9ced6"), deep: Color(hex: "#7d8693"))
        default: return false
        }
        return true
    }

    private static func laurel(_ ctx: GraphicsContext, _ t: Double, main: Color, deep: Color) {
        K.ring(ctx, 53, deep, 5)
        K.ring(ctx, 53, main, 2.6)
        Laurel.draw(ctx, center: K.center, radius: 58, color: main, leaf: 11)
        // A star where the branches meet, glinting every few seconds.
        let star = K.at(60, 0)
        var glint = ctx
        let pulse = 0.5 + 0.5 * sin(t * 2.2)
        glint.opacity = 0.25 + 0.35 * pulse
        glint.fill(K.circle(6 + pulse * 2, star.x, star.y + 2), with: .color(main))
        var points = Path()
        for i in 0..<10 {
            let r = i.isMultiple(of: 2) ? 5.5 : 2.3
            let a = Double(i) * .pi / 5 - .pi / 2
            let p = CGPoint(x: star.x + r * cos(a), y: star.y + 2 + r * sin(a))
            if i == 0 { points.move(to: p) } else { points.addLine(to: p) }
        }
        points.closeSubpath()
        ctx.fill(points, with: .color(.white))
    }
}
