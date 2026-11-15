//
//  StreakWeekRow.swift
//  Odyssey
//
//  This week as seven dots: orange with a check for each day that counted,
//  today ringed in orange while it is still open.
//

import Foundation
import SwiftUI

/// The last seven days as flame dots, today ringed.
struct StreakWeekRow: View {
    var week: [(letter: String, done: Bool, today: Bool)]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 5) {
                    ZStack {
                        Circle().fill(day.done ? Palette.flame : .white)
                        if !day.done {
                            Circle().strokeBorder(day.today ? Palette.flame : Palette.lineStrong, lineWidth: day.today ? 2 : 1.5)
                        }
                        if day.done {
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                        }
                    }
                    .frame(width: 30, height: 30)
                    .overlay {
                        if day.done && day.today { Circle().stroke(Palette.flame.opacity(0.25), lineWidth: 3).padding(-3) }
                    }
                    Text(day.letter).font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.muted)
                }
            }
        }
    }
}
