//
//  GlobieView.swift
//  Shared by the app and the widgets.
//
//  Globie, the streak buddy: a little globe with a face that reacts to the
//  exploring streak. Happy once today counts, sleepy while today is still
//  open, sad when the streak is gone and over the moon on a milestone.
//  Its form grows with the streak (glowing, sparks, on fire, a galaxy...).
//
//  Everything is drawn in the same 100 by 100 box as the mockup's SVG, from
//  the same path data. In the app it animates; widgets pass animated: false.
//

import Foundation
import SwiftUI

nonisolated enum GlobieMood: String, Codable, CaseIterable, Sendable {
    case happy, ecstatic, sleepy, sad
}

struct GlobieView: View {
    @Environment(\.animationsPaused) private var animationsPaused
    var mood: GlobieMood = .happy
    var form: String = "classic"
    var size: CGFloat = 64
    var animated: Bool = true

    var body: some View {
        Color.clear
            .frame(width: size, height: size)
            .overlay {
                Group {
                    // Small Globies in grids hold still; the big ones animate.
                    if animated && size >= 56 {
                        TimelineView(OdysseyMotion.schedule(paused: animationsPaused)) { timeline in
                            art(time: timeline.date.timeIntervalSinceReferenceDate)
                        }
                    } else if Self.inWidget {
                        // Widgets never draw the Canvas: they show a ready picture
                        // from their asset catalog (GlobieStill.swift).
                        GlobieStill(mood: mood, form: form)
                    } else {
                        art(time: 0.8)
                    }
                }
                .frame(width: size * 1.3, height: size * 1.3)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private static let inWidget = Bundle.main.bundlePath.hasSuffix(".appex")

    private func art(time: Double) -> some View {
        Canvas { context, canvasSize in
            let scale = canvasSize.width / 130
            context.translateBy(x: 15 * scale, y: 15 * scale)
            context.scaleBy(x: scale, y: scale)
            GlobieArt.draw(in: context, mood: mood, form: GlobieForm.named(form), time: time)
        }
        .hueRotation(.degrees(form == "legend" ? (time * 60).truncatingRemainder(dividingBy: 360) : 0))
    }
}

/// Colors and layers for one of Globie's forms.
nonisolated struct GlobieForm: Sendable {
    let id: String
    let ocean: Color
    let land: Color?
    let ink: Color

    static func named(_ id: String) -> GlobieForm {
        switch id {
        case "fire": return GlobieForm(id: id, ocean: Color(hex: "#ff7a29"), land: Color(hex: "#ffcf5a"), ink: Palette.ink)
        case "galaxy": return GlobieForm(id: id, ocean: Color(hex: "#241056"), land: nil, ink: .white)
        case "gold": return GlobieForm(id: id, ocean: Color(hex: "#f2b21b"), land: Color(hex: "#ffe58a"), ink: Palette.ink)
        case "aurora": return GlobieForm(id: id, ocean: Color(hex: "#0f4c5c"), land: Color(hex: "#2ee6a6"), ink: .white)
        case "crystal": return GlobieForm(id: id, ocean: Color(hex: "#9fe6ff"), land: Color(hex: "#e8fbff"), ink: Palette.ink)
        case "supernova": return GlobieForm(id: id, ocean: Color(hex: "#fff3c4"), land: Color(hex: "#ffd166"), ink: Palette.ink)
        case "eclipse": return GlobieForm(id: id, ocean: Color(hex: "#15121c"), land: Color(hex: "#2a2433"), ink: .white)
        case "legend": return GlobieForm(id: id, ocean: Color(hex: "#ff4fd8"), land: Color(hex: "#7cf7ff"), ink: Palette.ink)
        case "glow", "spark": return GlobieForm(id: id, ocean: Color(hex: "#3d7bff"), land: Color(hex: "#6fe0a0"), ink: Palette.ink)
        default: return GlobieForm(id: "classic", ocean: Color(hex: "#3d7bff"), land: Color(hex: "#6fe0a0"), ink: Palette.ink)
        }
    }
}

nonisolated enum GlobieArt {
    static let land = [
        SVGPath.path("M14 30c8-6 16-4 20 2s1 12-6 14-10 8-16 6z"),
        SVGPath.path("M58 14c8 0 16 4 20 10-6 2-9 7-15 6s-9-6-11-10z"),
        SVGPath.path("M64 62c6-3 14-1 19 4-2 8-8 14-15 16-4-4-8-14-4-20z"),
        SVGPath.path("M24 74c5-2 11 0 13 5-4 4-9 6-14 5z"),
    ]
    static let shine = SVGPath.path("M28 30a30 30 0 0 1 14-10")
    static let ball = Path(ellipseIn: CGRect(x: 16, y: 16, width: 68, height: 68))

    // Faces, straight from the mockup.
    static let happyEyes = SVGPath.path("M35 47q5-7 10 0M55 47q5-7 10 0")
    static let happyMouth = SVGPath.path("M41 58q9 9 18 0")
    static let starEyes = SVGPath.path("m40 39 1.9 4.1 4.4.5-3.3 3 .9 4.4-3.9-2.2-3.9 2.2.9-4.4-3.3-3 4.4-.5zM60 39l1.9 4.1 4.4.5-3.3 3 .9 4.4-3.9-2.2-3.9 2.2.9-4.4-3.3-3 4.4-.5z")
    static let openMouth = SVGPath.path("M39 56h22q-2 12-11 12t-11-12z")
    static let sparkles = SVGPath.path("M14 22l1.5 3.5L19 27l-3.5 1.5L14 32l-1.5-3.5L9 27l3.5-1.5zM86 14l1.2 2.8 2.8 1.2-2.8 1.2L86 22l-1.2-2.8-2.8-1.2 2.8-1.2z")
    static let sleepyEyes = SVGPath.path("M35 47q5 4 10 0M55 47q5 4 10 0")
    static let sadBrows = SVGPath.path("M33 40l9 3M67 40l-9 3")
    static let sadMouth = SVGPath.path("M42 63q8-6 16 0")
    static let tear = SVGPath.path("M37 54q-2.5 4 0 6.5 2.5-2.5 0-6.5z")

    static let blush = Color(hex: "#ff8fa8").opacity(0.85)
    static let yellow = Color(hex: "#ffd23f")

    /// Smooth 0...1...0 wave over a period, like a CSS ease-in-out alternate.
    static func wave(_ time: Double, _ period: Double, _ delay: Double = 0) -> Double {
        (1 - cos(2 * .pi * (time + delay) / period)) / 2
    }

    /// 0...1 progress through a repeating cycle.
    static func cycle(_ time: Double, _ period: Double, _ delay: Double = 0) -> Double {
        let value = (time - delay).truncatingRemainder(dividingBy: period) / period
        return value < 0 ? value + 1 : value
    }

    static func at(_ radius: Double, _ degrees: Double) -> CGPoint {
        let rad = degrees * .pi / 180
        return CGPoint(x: 50 + radius * sin(rad), y: 50 - radius * cos(rad))
    }

    static func star(_ x: Double, _ y: Double, _ r: Double) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: x, y: y - r))
        p.addLine(to: CGPoint(x: x + r * 0.3, y: y - r * 0.3))
        p.addLine(to: CGPoint(x: x + r, y: y))
        p.addLine(to: CGPoint(x: x + r * 0.3, y: y + r * 0.3))
        p.addLine(to: CGPoint(x: x, y: y + r))
        p.addLine(to: CGPoint(x: x - r * 0.3, y: y + r * 0.3))
        p.addLine(to: CGPoint(x: x - r, y: y))
        p.addLine(to: CGPoint(x: x - r * 0.3, y: y - r * 0.3))
        p.closeSubpath()
        return p
    }

    static func circle(_ cx: Double, _ cy: Double, _ r: Double) -> Path {
        Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    }

    static func draw(in context: GraphicsContext, mood: GlobieMood, form: GlobieForm, time t: Double) {
        // Body motion: a soft bob, a slower one when sleepy, a hop on milestones.
        var dy = 0.0, rotation = 0.0, sx = 1.0, sy = 1.0
        switch mood {
        case .happy:
            let p = wave(t, 3.2); dy = -3 * p; rotation = -2 * p
        case .sleepy:
            let p = wave(t, 4.6); dy = -3 * p; rotation = -2 * p
        case .ecstatic:
            let c = cycle(t, 0.9)
            if c < 0.3 { let k = c / 0.3; dy = -8 * k; sx = 1 - 0.03 * k; sy = 1 + 0.03 * k }
            else if c < 0.6 { let k = (c - 0.3) / 0.3; dy = -8 * (1 - k); sx = 0.97 + 0.07 * k; sy = 1.03 - 0.07 * k }
            else { let k = (c - 0.6) / 0.4; sx = 1.04 - 0.04 * k; sy = 0.96 + 0.04 * k }
        case .sad:
            break
        }

        // Shadow under the globe.
        var shadow = context
        let squash = mood == .sad ? 1 : 1 - 0.14 * wave(t, 3.2)
        shadow.opacity = mood == .sad ? 1 : 1 - 0.3 * wave(t, 3.2)
        shadow.fill(Path(ellipseIn: CGRect(x: 50 - 22 * squash, y: 88.5, width: 44 * squash, height: 7)),
                    with: .color(Palette.ink.opacity(0.12)))

        drawBack(context, form: form, t: t)

        var body = context
        body.translateBy(x: 50, y: 90)
        body.rotate(by: .degrees(rotation))
        body.scaleBy(x: sx, y: sy)
        body.translateBy(x: -50, y: -90 + dy)

        body.fill(ball, with: .color(form.ocean))
        var inside = body
        inside.clip(to: ball)
        drawInside(inside, form: form, t: t)
        if let land = form.land {
            for shape in GlobieArt.land { inside.fill(shape, with: .color(land)) }
        }
        body.stroke(shine, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        drawFace(body, mood: mood, ink: form.ink, t: t)

        drawFront(context, form: form, t: t)
    }

    private static func line(_ ink: Color) -> (Path, GraphicsContext) -> Void {
        { path, ctx in
            ctx.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: 3.4, lineCap: .round, lineJoin: .round))
        }
    }

    private static func drawFace(_ ctx: GraphicsContext, mood: GlobieMood, ink: Color, t: Double) {
        let stroke = line(ink)
        switch mood {
        case .happy:
            // A blink every five seconds.
            let c = cycle(t, 5)
            let blink = c > 0.92 && c < 0.98 ? 0.2 : 1.0
            var eyes = ctx
            eyes.translateBy(x: 0, y: 45)
            eyes.scaleBy(x: 1, y: blink)
            eyes.translateBy(x: 0, y: -45)
            stroke(happyEyes, eyes)
            stroke(happyMouth, ctx)
            ctx.fill(Path(ellipseIn: CGRect(x: 26.5, y: 53.4, width: 9, height: 5.2)), with: .color(blush))
            ctx.fill(Path(ellipseIn: CGRect(x: 64.5, y: 53.4, width: 9, height: 5.2)), with: .color(blush))
        case .ecstatic:
            ctx.fill(starEyes, with: .color(yellow))
            ctx.stroke(starEyes, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
            ctx.fill(openMouth, with: .color(ink))
            ctx.fill(Path(ellipseIn: CGRect(x: 25.5, y: 54.4, width: 9, height: 5.2)), with: .color(blush))
            ctx.fill(Path(ellipseIn: CGRect(x: 65.5, y: 54.4, width: 9, height: 5.2)), with: .color(blush))
            var spark = ctx
            spark.opacity = 1 - 0.6 * wave(t, 1.6)
            spark.fill(sparkles, with: .color(yellow))
        case .sleepy:
            stroke(sleepyEyes, ctx)
            ctx.fill(Path(ellipseIn: CGRect(x: 46.5, y: 58.2, width: 7, height: 5.6)), with: .color(ink))
            for (delay, x, y, size) in [(0.0, 72.0, 30.0, 12.0), (0.6, 80.0, 20.0, 9.0)] {
                let c = cycle(t, 2.4, delay)
                var z = ctx
                z.opacity = c < 0.4 ? c / 0.4 : 1 - (c - 0.4) / 0.6
                let text = Text("z").font(.system(size: size, weight: .heavy)).foregroundColor(Color(hex: "#8d8d96"))
                z.draw(text, at: CGPoint(x: x + 4 * c, y: y + 4 - 10 * c), anchor: .bottomLeading)
            }
        case .sad:
            ctx.fill(circle(40, 47, 4.2), with: .color(ink))
            ctx.fill(circle(60, 47, 4.2), with: .color(ink))
            stroke(sadBrows, ctx)
            stroke(sadMouth, ctx)
            ctx.fill(tear, with: .color(Color(hex: "#8fd3ff")))
        }
    }

    private static func drawBack(_ ctx: GraphicsContext, form: GlobieForm, t: Double) {
        switch form.id {
        case "glow":
            var c = ctx
            let p = wave(t, 2.4)
            c.opacity = 0.45 - 0.33 * p
            c.fill(circle(50, 50, 38 + 9 * p), with: .color(Color(hex: "#5b95ff")))
        case "spark":
            var c = ctx
            c.translateBy(x: 50, y: 50)
            c.rotate(by: .degrees(cycle(t, 9) * 360))
            c.translateBy(x: -50, y: -50)
            c.opacity = 0.9
            c.stroke(circle(50, 50, 44), with: .color(yellow), style: StrokeStyle(lineWidth: 1.6, dash: [2, 6]))
        case "fire":
            for i in 0..<11 {
                let deg = -120 + Double(i) * 24
                let tall = 12 + 16 * max(0, cos(deg * .pi / 180))
                let base = at(31, deg)
                var flame = Path()
                flame.move(to: CGPoint(x: base.x - 6, y: base.y))
                flame.addQuadCurve(to: CGPoint(x: base.x, y: base.y - tall), control: CGPoint(x: base.x - 3, y: base.y - tall * 0.6))
                flame.addQuadCurve(to: CGPoint(x: base.x + 6, y: base.y), control: CGPoint(x: base.x + 3, y: base.y - tall * 0.6))
                flame.closeSubpath()
                var c = ctx
                c.opacity = 0.55 + 0.45 * wave(t, 0.5 + Double(i % 3) * 0.2)
                c.translateBy(x: base.x, y: base.y)
                c.rotate(by: .degrees(deg))
                c.translateBy(x: -base.x, y: -base.y)
                c.fill(flame, with: .color(Color(hex: i % 2 == 1 ? "#ff3d00" : "#ff9a1f")))
            }
        case "galaxy":
            var c = ctx
            c.opacity = 0.35 - 0.23 * wave(t, 3)
            c.fill(circle(50, 50, 42), with: .color(Color(hex: "#9b6bff")))
        case "gold":
            var c = ctx
            c.opacity = 0.6
            c.translateBy(x: 50, y: 50)
            c.rotate(by: .degrees(cycle(t, 16) * 360))
            c.translateBy(x: -50, y: -50)
            for k in 0..<12 {
                var ray = c
                ray.translateBy(x: 50, y: 50)
                ray.rotate(by: .degrees(Double(k) * 30))
                ray.translateBy(x: -50, y: -50)
                ray.fill(SVGPath.path("M50 50L48 6L52 6Z"), with: .color(yellow))
            }
        case "aurora":
            let colors = ["#2ee6a6", "#7cf7ff", "#b896ff"]
            for i in 0..<3 {
                let o = Double(i) * 8
                let p = wave(t, 4, Double(i) * 0.6)
                func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * p }
                let start = CGPoint(x: 4, y: mix(30 + o, 26 + o))
                let control = CGPoint(x: 30, y: mix(14 + o, 36 + o))
                let middle = CGPoint(x: 50, y: mix(28 + o, 22 + o))
                let end = CGPoint(x: 96, y: mix(26 + o, 32 + o))
                var ribbon = Path()
                ribbon.move(to: start)
                ribbon.addQuadCurve(to: middle, control: control)
                ribbon.addQuadCurve(to: end, control: CGPoint(x: 2 * middle.x - control.x, y: 2 * middle.y - control.y))
                var c = ctx
                c.opacity = 0.7
                c.stroke(ribbon, with: .color(Color(hex: colors[i])), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }
        case "supernova":
            for i in 0..<3 {
                let k = cycle(t, 2.4, Double(i) * 0.8)
                var c = ctx
                c.opacity = 1 - k
                c.stroke(circle(50, 50, 34 + 22 * k), with: .color(Color(hex: "#ffb703")), lineWidth: 2.5)
            }
            var glow = ctx
            glow.opacity = 0.6 - 0.4 * wave(t, 1.2)
            glow.fill(circle(50, 50, 40), with: .color(Color(hex: "#fff3c4")))
        case "eclipse":
            ctx.stroke(circle(50, 50, 37), with: .color(Color(hex: "#ffb703").opacity(0.9)), lineWidth: 6 + 4 * wave(t, 2.6))
            var rays = ctx
            rays.opacity = 0.55
            rays.translateBy(x: 50, y: 50)
            rays.rotate(by: .degrees(-cycle(t, 30) * 360))
            rays.translateBy(x: -50, y: -50)
            for k in 0..<16 {
                var ray = rays
                ray.opacity = k % 2 == 1 ? 0.5 : 1
                ray.translateBy(x: 50, y: 50)
                ray.rotate(by: .degrees(Double(k) * 22.5))
                ray.translateBy(x: -50, y: -50)
                ray.fill(SVGPath.path("M50 50L49 4L51 4Z"), with: .color(Color(hex: "#ffd166")))
            }
        case "legend":
            var ring = ctx
            ring.translateBy(x: 50, y: 50)
            ring.rotate(by: .degrees(cycle(t, 6) * 360))
            ring.translateBy(x: -50, y: -50)
            ring.stroke(circle(50, 50, 44), with: .color(yellow), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
            var glow = ctx
            glow.opacity = 0.3
            glow.fill(circle(50, 50, 38 + 8 * wave(t, 2)), with: .color(Color(hex: "#ff4fd8")))
        default:
            break
        }
    }

    private static func drawInside(_ ctx: GraphicsContext, form: GlobieForm, t: Double) {
        switch form.id {
        case "galaxy":
            var swirl = ctx
            swirl.opacity = 0.95
            swirl.translateBy(x: 50, y: 50)
            swirl.rotate(by: .degrees(cycle(t, 14) * 360))
            swirl.translateBy(x: -50, y: -50)
            var arms = swirl
            arms.opacity = 0.55
            arms.stroke(SVGPath.path("M50 50C62 40 76 46 78 58M50 50C38 60 24 54 22 42M50 50C40 38 46 24 58 22M50 50C60 62 54 76 42 78"),
                        with: .color(Color(hex: "#b896ff")), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            swirl.fill(circle(50, 50, 7), with: .color(Color(hex: "#e6d9ff").opacity(0.9)))
            for i in 0..<12 {
                let point = at(Double(10 + (i * 7) % 24), Double(i) * 30 + Double(i) * 17)
                var dot = ctx
                dot.opacity = 0.2 + 0.8 * wave(t, 1.6 + Double(i % 4) * 0.4)
                dot.fill(circle(point.x, point.y, i % 3 == 0 ? 1.3 : 0.8), with: .color(.white))
            }
        case "crystal":
            var facets = ctx
            facets.opacity = 0.8
            facets.stroke(SVGPath.path("M16 50L50 16L84 50L50 84Z M16 50L84 50 M50 16L50 84 M33 33L67 67 M67 33L33 67"),
                          with: .color(.white), lineWidth: 1.2)
        default:
            break
        }
    }

    private static func drawFront(_ ctx: GraphicsContext, form: GlobieForm, t: Double) {
        func twinkles(count: Int, radius: Double, offset: Double, size: Double, period: Double, step: Double, colors: [String], spin: Double? = nil) {
            var layer = ctx
            if let spin {
                layer.translateBy(x: 50, y: 50)
                layer.rotate(by: .degrees(cycle(t, spin) * 360))
                layer.translateBy(x: -50, y: -50)
            }
            for i in 0..<count {
                let point = at(radius, Double(i) * 360 / Double(count) + offset)
                let k = cycle(t, period, Double(i) * step)
                var s = layer
                s.opacity = k < 0.5 ? k * 2 : (1 - k) * 2
                s.fill(star(point.x, point.y, size), with: .color(Color(hex: colors[i % colors.count])))
            }
        }
        switch form.id {
        case "spark":
            twinkles(count: 5, radius: 46, offset: 0, size: 4, period: 1.8, step: 0.35, colors: ["#ffd23f", "#fff3b0"], spin: 6)
        case "fire":
            for i in 0..<4 {
                let period = 1.4 + Double(i) * 0.25
                let k = cycle(t, period)
                var ember = ctx
                ember.opacity = 1 - k
                ember.fill(circle(34 + Double(i) * 11, 24 - 26 * k, 1.6), with: .color(Color(hex: "#ffd166")))
            }
        case "gold":
            var s = ctx
            let k = cycle(t, 1.6)
            s.opacity = k < 0.5 ? k * 2 : (1 - k) * 2
            s.fill(star(80, 22, 4), with: .color(Color(hex: "#fff6c9")))
        case "crystal":
            twinkles(count: 4, radius: 44, offset: 45, size: 3.5, period: 2, step: 0.5, colors: ["#e8fbff"])
        case "legend":
            twinkles(count: 6, radius: 47, offset: 0, size: 3.5, period: 1.4, step: 0.23, colors: ["#ffd23f", "#7cf7ff", "#ffffff"])
        default:
            break
        }
    }
}
