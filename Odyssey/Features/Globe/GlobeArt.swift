//
//  GlobeArt.swift
//  Odyssey
//
//  The spinning dot globe from the Odyssey Globe opener and the small one
//  on the profile card: a dark sphere with a grid of blue dots and soft
//  land shapes drifting across, shaded at the edge so it reads as round.
//  Ported from globe-art.css (.globe) and explorer-icon.css (.mini-globe).
//

import Foundation
import SwiftUI

struct GlobeArt: View {
    @Environment(\.animationsPaused) private var animationsPaused
    var size: CGFloat = 180
    /// The small profile version: finer dots, no land, a little faster.
    var mini = false

    var body: some View {
        TimelineView(OdysseyMotion.schedule(paused: animationsPaused)) { timeline in
            Canvas { context, canvas in
                let t = timeline.date.timeIntervalSinceReferenceDate
                draw(in: context, size: canvas.width, time: t)
            }
        }
        .frame(width: size, height: size)
        .background(Color(hex: "#10162f"))
        .clipShape(Circle())
        .overlay {
            Circle().fill(RadialGradient(colors: [.white.opacity(0.1), .clear, .black.opacity(0.75)],
                                         center: UnitPoint(x: 0.36, y: 0.34), startRadius: 0, endRadius: size * 0.66))
        }
        .accessibilityHidden(true)
    }

    private func draw(in context: GraphicsContext, size: CGFloat, time: Double) {
        let period = mini ? 8.0 : 9.0
        let phase = (time / period).truncatingRemainder(dividingBy: 1)
        let shift = Double(size) * phase
        let step: Double = mini ? 7 : 10
        let dot: Double = mini ? 1.5 : 2
        var layer = context
        layer.translateBy(x: CGFloat(-shift), y: 0)
        let width = Double(size) * 2
        // Every dot goes into one path and one fill, instead of hundreds of fills a frame.
        var dots = Path()
        var y = step / 2
        while y < Double(size) {
            var x = step / 2
            while x < width {
                dots.addEllipse(in: CGRect(x: x - dot, y: y - dot, width: dot * 2, height: dot * 2))
                x += step
            }
            y += step
        }
        layer.fill(dots, with: .color(Color(hex: "#6f8cff")))
        guard !mini else { return }
        // Three land shapes, repeated in each half so the loop is seamless.
        let lands: [(x: Double, y: Double, w: Double, h: Double)] = [(0.2, 0.4, 0.22, 0.18), (0.48, 0.55, 0.16, 0.26), (0.72, 0.32, 0.2, 0.14)]
        let half = Double(size)
        for copy in 0..<2 {
            for land in lands {
                let cx = Double(copy) * half + land.x * half
                let cy = land.y * Double(size)
                let rx = land.w * half
                let ry = land.h * Double(size)
                let rect = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
                let shading = GraphicsContext.Shading.radialGradient(
                    Gradient(stops: [.init(color: Color(hex: "#2b59ff").opacity(0.9), location: 0),
                                     .init(color: Color(hex: "#2b59ff").opacity(0), location: 0.7)]),
                    center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: CGFloat(max(rx, ry)))
                layer.fill(Path(ellipseIn: rect), with: shading)
            }
        }
    }
}
