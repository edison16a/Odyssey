//
//  ProfileFrameKit.swift
//  Odyssey
//
//  Drawing helpers shared by every avatar frame. Frames are drawn in the
//  mockup's 136 by 136 box around a face of radius 50 centered at (68, 68),
//  so the numbers in the frame files read the same as the SVG they came
//  from. Timing helpers stand in for SMIL: cycles, keyframes and twinkles.
//

import Foundation
import SwiftUI

enum ProfileFrameKit {
    static let center = CGPoint(x: 68, y: 68)

    /// Point on a circle around the center, degrees clockwise from 12 o'clock.
    static func at(_ radius: Double, _ degrees: Double) -> CGPoint {
        let a = (degrees - 90) * .pi / 180
        return CGPoint(x: 68 + radius * cos(a), y: 68 + radius * sin(a))
    }

    static func circle(_ radius: Double, _ cx: Double = 68, _ cy: Double = 68) -> Path {
        Path(ellipseIn: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2))
    }

    static func ring(_ ctx: GraphicsContext, _ radius: Double, _ color: Color, _ width: Double,
                     opacity: Double = 1, dash: [CGFloat] = [], phase: CGFloat = 0, round: Bool = false) {
        var layer = ctx
        layer.opacity = opacity
        layer.stroke(circle(radius), with: .color(color),
                     style: StrokeStyle(lineWidth: CGFloat(width), lineCap: round ? .round : .butt, dash: dash, dashPhase: phase))
    }

    /// A ring with a soft halo, standing in for the SVG blur glow.
    static func glowRing(_ ctx: GraphicsContext, _ radius: Double, _ color: Color, _ width: Double) {
        ring(ctx, radius, color, width * 2.8, opacity: 0.18)
        ring(ctx, radius, color, width)
    }

    /// A copy of the context turned around a point.
    static func rotated(_ ctx: GraphicsContext, _ degrees: Double, around point: CGPoint = center) -> GraphicsContext {
        var layer = ctx
        layer.translateBy(x: point.x, y: point.y)
        layer.rotate(by: .degrees(degrees))
        layer.translateBy(x: -point.x, y: -point.y)
        return layer
    }

    /// A copy of the context moved to a point, turned and scaled, for drawing a motif at the origin.
    static func placed(_ ctx: GraphicsContext, _ point: CGPoint, rotation degrees: Double = 0,
                       scaleX: Double = 1, scaleY: Double = 1) -> GraphicsContext {
        var layer = ctx
        layer.translateBy(x: point.x, y: point.y)
        layer.rotate(by: .degrees(degrees))
        layer.scaleBy(x: scaleX, y: scaleY)
        return layer
    }

    /// 0 to 1 through a repeating cycle that starts at begin seconds.
    static func cycle(_ t: Double, _ duration: Double, _ begin: Double = 0) -> Double {
        guard duration > 0 else { return 0 }
        let value = (t - begin).truncatingRemainder(dividingBy: duration) / duration
        return value < 0 ? value + 1 : value
    }

    /// Linear keyframes like SMIL values with optional keyTimes.
    static func keys(_ t: Double, _ duration: Double, _ values: [Double], times: [Double]? = nil, begin: Double = 0) -> Double {
        guard values.count > 1 else { return values.first ?? 0 }
        let stops = times ?? values.indices.map { Double($0) / Double(values.count - 1) }
        let p = cycle(t, duration, begin)
        for i in 1..<values.count where p <= stops[i] {
            let span = stops[i] - stops[i - 1]
            let k = span > 0 ? (p - stops[i - 1]) / span : 1
            return values[i - 1] + (values[i] - values[i - 1]) * k
        }
        return values[values.count - 1]
    }

    /// The mockup's twinkle: opacity from 0.2 up to 1 and back, staggered by index.
    static func twinkle(_ t: Double, _ index: Int, _ duration: Double = 2.4) -> Double {
        keys(t, duration, [0.2, 1, 0.2], begin: Double(index) * 0.37)
    }

    /// A circle with a gentle wobble, for contour lines and waves.
    static func wavy(_ radius: Double, amp: Double, lobes: Double, phase: Double, second: Bool = true) -> Path {
        var path = Path()
        for i in 0...120 {
            let a = Double(i) / 120 * .pi * 2
            var r = radius + amp * sin(lobes * a + phase)
            if second { r += amp * 0.5 * sin((lobes + 2) * a) }
            let p = CGPoint(x: 68 + r * cos(a), y: 68 + r * sin(a))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }

    /// A flame rooted at the origin, pointing up.
    static func flame(height h: Double) -> (outer: Path, inner: Path) {
        var outer = Path()
        outer.move(to: CGPoint(x: 0, y: 2))
        outer.addCurve(to: CGPoint(x: 0, y: -h), control1: CGPoint(x: -7, y: -3), control2: CGPoint(x: -7, y: -h * 0.55))
        outer.addCurve(to: CGPoint(x: 0, y: 2), control1: CGPoint(x: 7, y: -h * 0.55), control2: CGPoint(x: 7, y: -3))
        outer.closeSubpath()
        var inner = Path()
        inner.move(to: CGPoint(x: 0, y: 1))
        inner.addCurve(to: CGPoint(x: 0, y: -h * 0.62), control1: CGPoint(x: -3.5, y: -2), control2: CGPoint(x: -3.5, y: -h * 0.35))
        inner.addCurve(to: CGPoint(x: 0, y: 1), control1: CGPoint(x: 3.5, y: -h * 0.35), control2: CGPoint(x: 3.5, y: -2))
        inner.closeSubpath()
        return (outer, inner)
    }

    /// Draws a flickering flame at a point on the ring.
    static func drawFlame(_ ctx: GraphicsContext, at point: CGPoint, degrees: Double, index: Int, t: Double,
                          outer: Color, inner: Color, height: Double) {
        let dur = 0.9 + Double(index % 3) * 0.17
        let sx = keys(t, dur, [1, 1.08, 0.92, 1, 1])
        let sy = keys(t, dur, [1, 1.3, 0.95, 1.15, 1])
        let layer = placed(ctx, point, rotation: degrees, scaleX: sx, scaleY: sy)
        let shape = flame(height: height)
        layer.fill(shape.outer, with: .color(outer))
        layer.fill(shape.inner, with: .color(inner))
    }

    static let shard = SVGPath.path("M0 -13L4 0L0 4L-4 0Z")
    static let shardLine = SVGPath.path("M0 -13L0 4")

    static func drawShard(_ ctx: GraphicsContext, at point: CGPoint, degrees: Double, color: Color) {
        let layer = placed(ctx, point, rotation: degrees)
        layer.fill(shard, with: .color(color))
        layer.stroke(shard, with: .color(.white), lineWidth: 0.8)
        var line = layer
        line.opacity = 0.7
        line.stroke(shardLine, with: .color(.white), lineWidth: 0.6)
    }

    static let star = SVGPath.path("M0 -6L1.4 -1.4L6 0L1.4 1.4L0 6L-1.4 1.4L-6 0L-1.4 -1.4Z")

    /// The four point sparkle from the streak frames, with curved sides.
    static func sparkle(_ x: Double, _ y: Double, _ r: Double) -> Path {
        var p = Path()
        let c = CGPoint(x: x, y: y)
        p.move(to: CGPoint(x: x, y: y - r))
        p.addQuadCurve(to: CGPoint(x: x + r, y: y), control: c)
        p.addQuadCurve(to: CGPoint(x: x, y: y + r), control: c)
        p.addQuadCurve(to: CGPoint(x: x - r, y: y), control: c)
        p.addQuadCurve(to: CGPoint(x: x, y: y - r), control: c)
        p.closeSubpath()
        return p
    }

    /// A white highlight running round a ring, like the gilded sweep.
    static func sweep(_ ctx: GraphicsContext, _ radius: Double, t: Double, duration: Double = 3) {
        let length = 2 * Double.pi * radius
        ring(ctx, radius, .white, 2.5, opacity: 0.85, dash: [12, CGFloat(length)], phase: CGFloat(-cycle(t, duration) * (length + 12)))
    }
}
