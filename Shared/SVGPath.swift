//
//  SVGPath.swift
//  Shared by the app and the widgets.
//
//  A small SVG path data reader, so the artwork from the HTML mockup
//  (Globie's face, the Odyssey mark, map glyphs) can be drawn from the very
//  same path strings instead of being redrawn by hand. It understands
//  move, line, horizontal, vertical, quadratic, smooth quadratic, cubic,
//  smooth cubic, circular arcs and close, in absolute and relative form.
//

import Foundation
import SwiftUI

nonisolated enum SVGPath {
    private nonisolated enum Token {
        case command(Character)
        case number(CGFloat)
    }

    /// Builds a SwiftUI path from SVG path data such as "M35 47q5-7 10 0".
    static func path(_ data: String) -> Path {
        var path = Path()
        let tokens = tokenize(data)
        var index = 0
        var command: Character = "M"
        var current = CGPoint.zero
        var start = CGPoint.zero
        var lastControl: CGPoint?
        var lastWasQuad = false
        var lastWasCubic = false

        func next() -> CGFloat {
            guard index < tokens.count, case .number(let value) = tokens[index] else { return 0 }
            index += 1
            return value
        }
        func hasNumber() -> Bool {
            guard index < tokens.count, case .number = tokens[index] else { return false }
            return true
        }

        while index < tokens.count {
            if case .command(let c) = tokens[index] {
                command = c
                index += 1
            } else if command == "M" {
                command = "L"
            } else if command == "m" {
                command = "l"
            }
            let relative = command.isLowercase
            let base = relative ? current : .zero
            var quad = false
            var cubic = false

            switch command {
            case "M", "m":
                let point = CGPoint(x: base.x + next(), y: base.y + next())
                path.move(to: point)
                current = point
                start = point
            case "L", "l":
                let point = CGPoint(x: base.x + next(), y: base.y + next())
                path.addLine(to: point)
                current = point
            case "H", "h":
                current = CGPoint(x: (relative ? current.x : 0) + next(), y: current.y)
                path.addLine(to: current)
            case "V", "v":
                current = CGPoint(x: current.x, y: (relative ? current.y : 0) + next())
                path.addLine(to: current)
            case "Q", "q":
                let control = CGPoint(x: base.x + next(), y: base.y + next())
                let end = CGPoint(x: base.x + next(), y: base.y + next())
                path.addQuadCurve(to: end, control: control)
                lastControl = control
                current = end
                quad = true
            case "T", "t":
                let control = lastWasQuad && lastControl != nil
                    ? CGPoint(x: 2 * current.x - lastControl!.x, y: 2 * current.y - lastControl!.y)
                    : current
                let end = CGPoint(x: base.x + next(), y: base.y + next())
                path.addQuadCurve(to: end, control: control)
                lastControl = control
                current = end
                quad = true
            case "C", "c":
                let c1 = CGPoint(x: base.x + next(), y: base.y + next())
                let c2 = CGPoint(x: base.x + next(), y: base.y + next())
                let end = CGPoint(x: base.x + next(), y: base.y + next())
                path.addCurve(to: end, control1: c1, control2: c2)
                lastControl = c2
                current = end
                cubic = true
            case "S", "s":
                let c1 = lastWasCubic && lastControl != nil
                    ? CGPoint(x: 2 * current.x - lastControl!.x, y: 2 * current.y - lastControl!.y)
                    : current
                let c2 = CGPoint(x: base.x + next(), y: base.y + next())
                let end = CGPoint(x: base.x + next(), y: base.y + next())
                path.addCurve(to: end, control1: c1, control2: c2)
                lastControl = c2
                current = end
                cubic = true
            case "A", "a":
                let radius = next()
                _ = next() // ry, the artwork only uses circular arcs
                _ = next() // rotation
                let largeArc = next() != 0
                let sweep = next() != 0
                let end = CGPoint(x: base.x + next(), y: base.y + next())
                addArc(to: &path, from: current, to: end, radius: radius, largeArc: largeArc, sweep: sweep)
                current = end
            case "Z", "z":
                path.closeSubpath()
                current = start
            default:
                // Unknown command: skip its numbers so parsing can carry on.
                while hasNumber() { index += 1 }
            }
            lastWasQuad = quad
            lastWasCubic = cubic
            if command == "Z" || command == "z" {
                // A bare close has no numbers; stop it from swallowing the next ones.
                if hasNumber() { command = "L" }
            }
        }
        return path
    }

    /// Endpoint arc to center arc, following the SVG implementation notes.
    private static func addArc(to path: inout Path, from p1: CGPoint, to p2: CGPoint,
                               radius: CGFloat, largeArc: Bool, sweep: Bool) {
        guard radius > 0, p1 != p2 else {
            path.addLine(to: p2)
            return
        }
        let x1 = (p1.x - p2.x) / 2
        let y1 = (p1.y - p2.y) / 2
        var r = radius
        let lambda = (x1 * x1 + y1 * y1) / (r * r)
        if lambda > 1 { r *= lambda.squareRoot() }
        let numerator = max(0, r * r * r * r - r * r * y1 * y1 - r * r * x1 * x1)
        let denominator = r * r * y1 * y1 + r * r * x1 * x1
        let coef = (denominator == 0 ? 0 : (numerator / denominator).squareRoot()) * (largeArc == sweep ? -1 : 1)
        let cxp = coef * y1
        let cyp = -coef * x1
        let center = CGPoint(x: cxp + (p1.x + p2.x) / 2, y: cyp + (p1.y + p2.y) / 2)
        let startAngle = atan2((y1 - cyp) / r, (x1 - cxp) / r)
        let endAngle = atan2((-y1 - cyp) / r, (-x1 - cxp) / r)
        // SwiftUI measures clockwise in flipped coordinates, the opposite of SVG's sweep flag.
        path.addArc(center: center, radius: r, startAngle: .radians(Double(startAngle)),
                    endAngle: .radians(Double(endAngle)), clockwise: !sweep)
    }

    private static func tokenize(_ data: String) -> [Token] {
        var tokens: [Token] = []
        var number = ""
        var hasDot = false
        var hasExponent = false

        func flush() {
            if let value = Double(number) { tokens.append(.number(CGFloat(value))) }
            number = ""
            hasDot = false
            hasExponent = false
        }

        for char in data {
            if char.isLetter && char != "e" && char != "E" {
                flush()
                tokens.append(.command(char))
            } else if char == "e" || char == "E" {
                number.append(char)
                hasExponent = true
            } else if char == "-" || char == "+" {
                if let last = number.last, last == "e" || last == "E" {
                    number.append(char)
                } else {
                    flush()
                    number.append(char)
                }
            } else if char == "." {
                if hasDot || hasExponent { flush() }
                number.append(char)
                hasDot = true
            } else if char.isNumber {
                number.append(char)
            } else {
                flush()
            }
        }
        flush()
        return tokens
    }
}
