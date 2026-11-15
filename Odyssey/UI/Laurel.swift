//
//  Laurel.swift
//  Odyssey
//
//  The laurel wreath for leaderboard milestones. Two branches climb from
//  the bottom of a circle toward the top, one leaf at a time, so the
//  wreath can draw itself in on the top 10 moment and sit still around a
//  profile photo as the laurel frames.
//

import Foundation
import SwiftUI

enum Laurel {
    static let leavesPerSide = 9

    /// Draws the wreath around a center. progress 0 shows nothing, 1 the full wreath.
    static func draw(_ ctx: GraphicsContext, center: CGPoint, radius: Double, color: Color,
                     leaf: Double, progress: Double = 1) {
        let p = max(0, min(1, progress))
        for side in [-1.0, 1.0] {
            // Degrees clockwise from 12 o'clock: from just off the bottom to near the top.
            let start = 180 - side * 14, end = 180 - side * 150
            var stem = Path()
            let steps = 30
            for i in 0...Int(Double(steps) * p) {
                let deg = start + (end - start) * Double(i) / Double(steps)
                let point = at(center, radius, deg)
                if i == 0 { stem.move(to: point) } else { stem.addLine(to: point) }
            }
            ctx.stroke(stem, with: .color(color), style: StrokeStyle(lineWidth: leaf * 0.16, lineCap: .round))
            for i in 0..<leavesPerSide {
                let f = (Double(i) + 0.6) / Double(leavesPerSide)
                let grow = max(0, min(1, (p - f * 0.92) / 0.08))
                guard grow > 0 else { continue }
                let deg = start + (end - start) * f
                let size = leaf * (1.1 - f * 0.35) * grow
                let here = at(center, radius, deg), ahead = at(center, radius, deg + (end - start) * 0.01)
                let along = CGVector(dx: ahead.x - here.x, dy: ahead.y - here.y).unit
                let outward = CGVector(dx: here.x - center.x, dy: here.y - center.y).unit
                for out in [1.0, -1.0] {
                    // Leaves follow the branch and lean away from it, one outside and one inside.
                    let dx = along.dx * 0.82 + outward.dx * 0.57 * out
                    let dy = along.dy * 0.82 + outward.dy * 0.57 * out
                    var layer = ctx
                    layer.translateBy(x: here.x, y: here.y)
                    layer.rotate(by: .radians(atan2(dy, dx)))
                    let shape = Path(ellipseIn: CGRect(x: 0, y: -size * 0.21, width: size, height: size * 0.42))
                    layer.fill(shape, with: .color(color))
                    if out < 0 {
                        var shade = layer
                        shade.opacity = 0.18
                        shade.fill(shape, with: .color(.black))
                    }
                }
            }
        }
    }

    fileprivate static func at(_ c: CGPoint, _ r: Double, _ degrees: Double) -> CGPoint {
        let a = (degrees - 90) * .pi / 180
        return CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
    }
}

/// A wreath that draws itself in once when it appears.
struct LaurelWreath: View {
    @Environment(\.animationsPaused) private var animationsPaused
    var color: Color
    var duration = 1.4
    var delay = 0.0
    @State private var start = Date()
    @State private var done = false

    var body: some View {
        TimelineView(OdysseyMotion.schedule(paused: done || animationsPaused)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start) - delay
                let eased = done ? 1 : 1 - pow(1 - max(0, min(1, t / duration)), 3)
                let r = min(size.width, size.height) / 2
                Laurel.draw(context, center: CGPoint(x: size.width / 2, y: size.height / 2), radius: r * 0.82,
                            color: color, leaf: r * 0.26, progress: eased)
            }
        }
        .onAppear { start = Date() }
        .task {
            try? await Task.sleep(for: .seconds(delay + duration + 0.1))
            done = true
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private extension CGVector {
    var unit: CGVector {
        let length = max(0.0001, (dx * dx + dy * dy).squareRoot())
        return CGVector(dx: dx / length, dy: dy / length)
    }
}

/// A still wreath around a short label, like a seal ("TOP 10").
struct LaurelSeal: View {
    var label: String
    var color: Color

    var body: some View {
        ZStack {
            Canvas { context, size in
                let r = min(size.width, size.height) / 2
                Laurel.draw(context, center: CGPoint(x: size.width / 2, y: size.height / 2), radius: r * 0.82,
                            color: color, leaf: r * 0.26)
            }
            Text(label)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .padding(14)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel(label)
    }
}
