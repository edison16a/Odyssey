//
//  StreakTiers.swift
//  Shared by the app and the widgets.
//
//  Globie takes a new form at each streak milestone: glowing at 10 days,
//  sparks at 25, on fire at 50, a galaxy at 100 and on up to legendary at
//  a thousand. The widgets need this table without loading the app's
//  seed data, so it lives here.
//

import Foundation
import SwiftUI

nonisolated struct StreakTier: Identifiable, Hashable, Sendable {
    let days: Int
    let id: String
    let name: String
    let colorHex: String
    let bgHex: String
    let line: String

    var color: Color { Color(hex: colorHex) }
    var background: Color { Color(hex: bgHex) }
    /// "Glowing" for "Glowing Globie", used where space is tight.
    var shortName: String { name.replacingOccurrences(of: " Globie", with: "") }
}

nonisolated enum StreakTiers {
    static let all: [StreakTier] = [
        StreakTier(days: 0, id: "classic", name: "Globie", colorHex: "#3d7bff", bgHex: "#0b1530", line: "Every streak starts somewhere."),
        StreakTier(days: 10, id: "glow", name: "Glowing Globie", colorHex: "#5b95ff", bgHex: "#0b1a3d", line: "Ten days in and Globie is glowing."),
        StreakTier(days: 25, id: "spark", name: "Sparkler Globie", colorHex: "#ffd23f", bgHex: "#1b1530", line: "Sparks fly when you keep going."),
        StreakTier(days: 50, id: "fire", name: "Blazing Globie", colorHex: "#ff6a2b", bgHex: "#260c04", line: "Fifty days. Globie is on fire."),
        StreakTier(days: 100, id: "galaxy", name: "Galaxy Globie", colorHex: "#9b6bff", bgHex: "#090520", line: "A hundred days turned Globie into a galaxy."),
        StreakTier(days: 200, id: "gold", name: "Golden Globie", colorHex: "#f2b21b", bgHex: "#1f1503", line: "Two hundred days, pure gold."),
        StreakTier(days: 300, id: "aurora", name: "Aurora Globie", colorHex: "#2ee6a6", bgHex: "#03171a", line: "The northern lights follow you now."),
        StreakTier(days: 400, id: "crystal", name: "Crystal Globie", colorHex: "#8fe3ff", bgHex: "#05182a", line: "Four hundred days, clear as ice."),
        StreakTier(days: 500, id: "supernova", name: "Supernova Globie", colorHex: "#ffd166", bgHex: "#1a0818", line: "Five hundred days. Globie went supernova."),
        StreakTier(days: 750, id: "eclipse", name: "Eclipse Globie", colorHex: "#ffb703", bgHex: "#000000", line: "Seven hundred fifty days. A rare eclipse."),
        StreakTier(days: 1000, id: "legend", name: "Legendary Globie", colorHex: "#ff4fd8", bgHex: "#12001c", line: "A thousand days. You are a legend."),
    ]

    static var milestones: [Int] { all.filter { $0.days > 0 }.map(\.days) }

    /// The form a streak of this many days has earned.
    static func tier(for days: Int) -> StreakTier {
        all.last { $0.days <= days } ?? all[0]
    }

    static func next(after days: Int) -> StreakTier? {
        all.first { $0.days > days }
    }

    static func tier(id: String) -> StreakTier {
        all.first { $0.id == id } ?? all[0]
    }
}
