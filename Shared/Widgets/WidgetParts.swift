//
//  WidgetParts.swift
//  Shared by the app and the widgets.
//
//  Small drawings the widgets share: the week of streak marks, the point
//  under a map pin and a little stack of coins.
//

import Foundation
import SwiftUI

/// The little point under a map pin.
nonisolated struct WidgetPointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A short stack of gold coins seen from the side, with the Odyssey diamond on top.
struct WidgetCoinStack: View {
    var width: CGFloat = 40

    var body: some View {
        let height = width * 0.34
        VStack(spacing: -height * 0.55) {
            ForEach(0..<3, id: \.self) { index in
                ZStack {
                    Ellipse().fill(Color(hex: index == 0 ? "#ffe08a" : "#ffd25a"))
                    Ellipse().strokeBorder(Color(hex: "#c98a00"), lineWidth: 1.5)
                    if index == 0 {
                        Image(systemName: "diamond.fill").font(.system(size: height * 0.5, weight: .bold))
                            .foregroundStyle(Color(hex: "#c98a00"))
                    }
                }
                .frame(width: width, height: height)
                .zIndex(Double(3 - index))
            }
        }
    }
}

/// Seven days with the streak's check marks.
struct WidgetWeek: View {
    var snapshot: WidgetSnapshot
    var colors: WidgetColors
    var dot: CGFloat = 18
    var letters = true

    var body: some View {
        HStack(spacing: dot * 0.28) {
            ForEach(Array(snapshot.week().enumerated()), id: \.offset) { _, day in
                VStack(spacing: 2) {
                    ZStack {
                        Circle().fill(day.done ? Palette.flame : colors.chip)
                        if day.done {
                            Image(systemName: "checkmark").font(.system(size: dot * 0.45, weight: .heavy)).foregroundStyle(.white)
                        }
                        if day.today && !day.done {
                            Circle().strokeBorder(Palette.flame, lineWidth: 1.5)
                        }
                    }
                    .frame(width: dot, height: dot)
                    if letters {
                        Text(day.letter).font(.system(size: 8.5, weight: .semibold)).foregroundStyle(colors.secondary)
                    }
                }
            }
        }
    }
}
