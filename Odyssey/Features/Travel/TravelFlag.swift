//
//  TravelFlag.swift
//  Odyssey
//
//  Small flags for the countries in the demo, drawn rather than emoji so
//  they look the same everywhere, plus the little honeycomb badge on the
//  profile's explored map card. Ported from ui/flags.js and the badge in
//  ui/hex-layer.js.
//

import Foundation
import SwiftUI

/// A country flag in a 30 by 20 box, scaled to the width asked for.
struct TravelFlag: View {
    var code: String
    var width: CGFloat = 24

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 30, y: size.height / 20)
            TravelFlag.draw(code, in: context)
        }
        .frame(width: width, height: (width * 2 / 3).rounded())
        .accessibilityHidden(true)
    }

    private static func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Path {
        Path(CGRect(x: x, y: y, width: w, height: h))
    }

    static func draw(_ code: String, in context: GraphicsContext) {
        switch code {
        case "mx":
            context.fill(rect(0, 0, 10, 20), with: .color(Color(hex: "#006847")))
            context.fill(rect(10, 0, 10, 20), with: .color(.white))
            context.fill(rect(20, 0, 10, 20), with: .color(Color(hex: "#ce1126")))
            context.fill(Path(ellipseIn: CGRect(x: 12.4, y: 7.4, width: 5.2, height: 5.2)), with: .color(Color(hex: "#8c6a2f")))
        case "jp":
            context.fill(rect(0, 0, 30, 20), with: .color(.white))
            context.fill(Path(ellipseIn: CGRect(x: 9, y: 4, width: 12, height: 12)), with: .color(Color(hex: "#bc002d")))
        case "ca":
            let red = Color(hex: "#d52b1e")
            context.fill(rect(0, 0, 30, 20), with: .color(.white))
            context.fill(rect(0, 0, 7.5, 20), with: .color(red))
            context.fill(rect(22.5, 0, 7.5, 20), with: .color(red))
            context.fill(SVGPath.path("M15 4l1.4 3 2.4-1-.8 3.6 2.2-.4-1.6 2.6 1.4.8-4 .8.3 2.6h-2.6l.3-2.6-4-.8 1.4-.8-1.6-2.6 2.2.4-.8-3.6 2.4 1z"), with: .color(red))
        case "fr":
            context.fill(rect(0, 0, 10, 20), with: .color(Color(hex: "#002395")))
            context.fill(rect(10, 0, 10, 20), with: .color(.white))
            context.fill(rect(20, 0, 10, 20), with: .color(Color(hex: "#ed2939")))
        default:
            context.fill(rect(0, 0, 30, 20), with: .color(.white))
            let stripe = 20.0 / 13
            for i in stride(from: 0, through: 12, by: 2) {
                context.fill(rect(0, Double(i) * stripe, 30, stripe), with: .color(Color(hex: "#b22234")))
            }
            context.fill(rect(0, 0, 13, 10.8), with: .color(Color(hex: "#3c3b6e")))
        }
    }
}

/// The honeycomb on the profile card: a few cells lit like a real map.
struct TravelHexBadge: View {
    var size: CGFloat = 44

    private static let lit: Set<String> = ["0,0", "1,0", "0,1", "-1,1", "1,-1", "2,-1", "-1,2"]

    var body: some View {
        Canvas { context, canvas in
            context.scaleBy(x: canvas.width / 64, y: canvas.height / 64)
            let s = 9.0
            let root3 = 3.0.squareRoot()
            for q in -3...3 {
                for r in -3...3 where abs(q + r) <= 3 {
                    let cx = 32 + s * root3 * (Double(q) + Double(r) / 2)
                    let cy = 32 + s * 1.5 * Double(r)
                    var hex = Path()
                    for i in 0..<6 {
                        let a = Double.pi / 180 * (60 * Double(i) - 30)
                        let point = CGPoint(x: cx + (s - 0.8) * cos(a), y: cy + (s - 0.8) * sin(a))
                        if i == 0 { hex.move(to: point) } else { hex.addLine(to: point) }
                    }
                    hex.closeSubpath()
                    let on = TravelHexBadge.lit.contains("\(q),\(r)")
                    context.fill(hex, with: .color(on ? Palette.accent.opacity(0.85) : Color.white.opacity(0.07)))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
