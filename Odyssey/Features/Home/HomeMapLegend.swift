//
//  HomeMapLegend.swift
//  Odyssey
//
//  The small key under the level switch: blue for explored, grey for not
//  yet. Ported from the legend in features/home/home-tab.js.
//

import Foundation
import SwiftUI

struct HomeMapLegend: View {
    var body: some View {
        HStack(spacing: 10) {
            item("Explored", fill: Palette.accent.opacity(0.3), stroke: Palette.accent, width: 1.5)
            item("Not yet", fill: Palette.ink.opacity(0.06), stroke: Color(hex: "#8d8d96").opacity(0.8), width: 1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.92), in: Capsule())
        .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
    }

    private func item(_ text: String, fill: Color, stroke: Color, width: CGFloat) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(fill)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(stroke, lineWidth: width))
                .frame(width: 10, height: 10)
            Text(text).font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.ink)
        }
    }
}
