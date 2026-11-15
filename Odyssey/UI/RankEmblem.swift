//
//  RankEmblem.swift
//  Odyssey
//
//  The rank emblem. Each tier keeps its color from the seed but gets its
//  own silhouette, so climbing feels like earning a new badge and not a
//  repaint: a round compass for Explorer, a shield with one chevron for
//  Scout, a wider shield with two for Trailblazer, a hex crest with a four
//  point star for Pathfinder, the crest with wings for Voyager, and wings
//  plus a crown for Atlas.
//
//  Every emblem is two tones of its own color (a deeper rim around a
//  brighter face) with a soft shine across the top, drawn in a 48 point
//  box so it stays crisp from a chip to the rank up screen.
//
//  color nil uses the tier color, white (or inverse: true) gives the white
//  version for colored chips, any other color is a custom fill such as grey
//  for locked tiers.
//

import Foundation
import SwiftUI

struct RankEmblem: View {
    var tier: Int
    var size: CGFloat = 40
    var color: Color? = nil
    var inverse = false

    var body: some View {
        Canvas { context, canvas in
            let scale = canvas.width / 48
            context.scaleBy(x: scale, y: scale)
            let tierColor = RankEmblem.color(for: tier)
            let flipped = inverse || color == .white
            let fill: Color = flipped ? .white : (color ?? tierColor)
            let mark: Color = flipped ? tierColor : .white
            RankEmblem.draw(in: context, tier: tier, fill: fill, mark: mark, shine: !flipped)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// The color of a tier, from the seeded ranks.
    static func color(for tier: Int) -> Color {
        let ranks = Seed.shared.ranks
        guard !ranks.isEmpty else { return Palette.muted }
        return Color(hex: ranks[max(0, min(tier, ranks.count - 1))].color)
    }

    /// Draws the emblem for a tier in a 48 by 48 box. The rank frame reuses this.
    static func draw(in context: GraphicsContext, tier: Int, fill: Color, mark: Color, shine: Bool) {
        let t = max(0, min(tier, 5))
        let body = RankShapes.body(t)
        if t >= 4 {
            for wing in RankShapes.wings {
                context.fill(wing, with: .color(fill))
                var deep = context
                deep.opacity = 0.28
                deep.fill(wing, with: .color(.black))
            }
        }
        if t == 5 {
            context.fill(RankShapes.crown, with: .color(fill))
            var gloss = context
            gloss.opacity = 0.3
            gloss.fill(RankShapes.crown, with: .color(.white))
        }
        // Rim: the body in a deeper tone of the same color.
        context.fill(body, with: .color(fill))
        var rim = context
        rim.opacity = 0.24
        rim.fill(body, with: .color(.black))
        // Face: the body again, inset, in the bright tone.
        let face = body.applying(RankShapes.inset(for: body))
        context.fill(face, with: .color(fill))
        if shine {
            var gloss = context
            gloss.clip(to: face)
            gloss.opacity = 0.18
            gloss.fill(Path(ellipseIn: CGRect(x: -6, y: -22, width: 60, height: 42)), with: .color(.white))
        }
        // The mark, with a soft shadow so it sits on the face.
        var shadow = context
        shadow.opacity = 0.22
        shadow.translateBy(x: 0, y: 0.9)
        RankShapes.drawMark(t, in: shadow, color: .black)
        RankShapes.drawMark(t, in: context, color: mark)
    }
}

/// The shapes behind every tier, built once.
enum RankShapes {
    static let shield = rounded([(10, 8), (38, 8), (38, 24), (24, 42.5), (10, 24)], 5)
    static let heater = rounded([(8, 8.5), (24, 5), (40, 8.5), (40, 23), (24, 43), (8, 23)], 5)
    static let crest = rounded([(24, 5), (40, 14), (40, 34), (24, 43), (8, 34), (8, 14)], 5)
    static let crownCrest = rounded([(24, 9), (38.5, 17), (38.5, 34.5), (24, 43), (9.5, 34.5), (9.5, 17)], 4.5)
    static let crown = rounded([(15.5, 11), (14, 2.5), (19.5, 6.5), (24, 0.5), (28.5, 6.5), (34, 2.5), (32.5, 11)], 1.4)
    static let wings: [Path] = {
        let left = rounded([(12, 17), (1.5, 14), (5, 20.5), (1, 24.5), (6, 29), (3, 33.5), (12, 32)], 1.6)
        let right = left.applying(CGAffineTransform(translationX: 48, y: 0).scaledBy(x: -1, y: 1))
        return [left, right]
    }()

    static func body(_ tier: Int) -> Path {
        switch tier {
        case 0: return Path(ellipseIn: CGRect(x: 7, y: 7.5, width: 34, height: 34))
        case 1: return shield
        case 2: return heater
        case 3, 4: return crest
        default: return crownCrest
        }
    }

    /// Shrinks a body around its own middle so a rim shows all round.
    static func inset(for path: Path) -> CGAffineTransform {
        let box = path.boundingRect
        let k = 0.8
        return CGAffineTransform(translationX: box.midX, y: box.midY).scaledBy(x: k, y: k)
            .translatedBy(x: -box.midX, y: -box.midY)
    }

    static func drawMark(_ tier: Int, in ctx: GraphicsContext, color: Color) {
        let line = StrokeStyle(lineWidth: 3.4, lineCap: .round, lineJoin: .round)
        switch tier {
        case 0:
            ctx.fill(polygon([(24, 14.5), (27.4, 24.5), (20.6, 24.5)]), with: .color(color))
            var south = ctx
            south.opacity = 0.55
            south.fill(polygon([(24, 34.5), (27.4, 24.5), (20.6, 24.5)]), with: .color(color))
            ctx.fill(Path(ellipseIn: CGRect(x: 22.4, y: 22.9, width: 3.2, height: 3.2)), with: .color(color))
        case 1:
            ctx.stroke(chevron(y: 22.5), with: .color(color), style: line)
        case 2:
            ctx.stroke(chevron(y: 18.5), with: .color(color), style: line)
            ctx.stroke(chevron(y: 26.5), with: .color(color), style: line)
        case 3:
            ctx.fill(star(points: 4, at: CGPoint(x: 24, y: 24), outer: 10.5, inner: 3.6), with: .color(color))
        case 4:
            ctx.fill(star(points: 5, at: CGPoint(x: 24, y: 24.5), outer: 9.8, inner: 4.2), with: .color(color))
        default:
            let orbit = Path(ellipseIn: CGRect(x: 13, y: 21, width: 22, height: 9))
                .applying(CGAffineTransform(translationX: 24, y: 26).rotated(by: -0.42).translatedBy(x: -24, y: -26))
            ctx.stroke(orbit, with: .color(color), lineWidth: 1.6)
            ctx.fill(star(points: 5, at: CGPoint(x: 24, y: 26), outer: 8.4, inner: 3.6), with: .color(color))
        }
    }

    private static func chevron(y: Double) -> Path {
        polygon([(17, y + 3.5), (24, y - 3.5), (31, y + 3.5)], closed: false)
    }

    private static func star(points: Int, at c: CGPoint, outer: Double, inner: Double) -> Path {
        let count = points * 2
        let pts = (0..<count).map { i -> (Double, Double) in
            let r = i.isMultiple(of: 2) ? outer : inner
            let a = Double(i) * .pi / Double(points) - .pi / 2
            return (Double(c.x) + r * cos(a), Double(c.y) + r * sin(a))
        }
        return rounded(pts, 0.9)
    }

    static func polygon(_ pts: [(Double, Double)], closed: Bool = true) -> Path {
        var path = Path()
        for (i, p) in pts.enumerated() {
            let point = CGPoint(x: p.0, y: p.1)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        if closed { path.closeSubpath() }
        return path
    }

    /// A closed polygon with every corner rounded by the same radius.
    static func rounded(_ pts: [(Double, Double)], _ radius: Double) -> Path {
        let p = pts.map { CGPoint(x: $0.0, y: $0.1) }
        guard p.count > 2 else { return polygon(pts) }
        var path = Path()
        let start = CGPoint(x: (p[p.count - 1].x + p[0].x) / 2, y: (p[p.count - 1].y + p[0].y) / 2)
        path.move(to: start)
        for i in 0..<p.count {
            let next = p[(i + 1) % p.count]
            path.addArc(tangent1End: p[i], tangent2End: next, radius: radius)
        }
        path.closeSubpath()
        return path
    }
}
