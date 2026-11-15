//
//  WidgetBoardData.swift
//  Shared by the app and the widgets.
//
//  What the Leaderboard widget reads: this week's board of friends and you
//  ranked by XP, and your best standing in a city or wider area.
//

import Foundation

/// One row of the weekly board.
nonisolated struct BoardEntry: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var name: String
    var xp: Int
    var rank: Int
    var isMe: Bool
    var imageFile: String?

    var firstName: String { isMe ? "You" : (name.split(separator: " ").first.map(String.init) ?? name) }
    var xpText: String { xp >= 10_000 ? "\(xp / 1000)k" : xp.formatted(.number) }
}

/// Where you stand in an area, such as #87 in San Francisco, top 4%.
nonisolated struct StandingSnapshot: Codable, Hashable, Sendable {
    var position: Int
    var pct: Double
    var scope: String

    var pctText: String { pct < 1 ? String(format: "top %.1f%%", pct) : "top \(Int(pct.rounded()))%" }
}

nonisolated extension BoardEntry {
    /// A sample board for the widget picker, with faces from the widget's own assets.
    static let samples: [BoardEntry] = [
        BoardEntry(id: "diego", name: "Diego Reyes", xp: 1710, rank: 1, isMe: false, imageFile: "asset:widget-placeholder-face-1"),
        BoardEntry(id: "nina", name: "Nina Park", xp: 1180, rank: 2, isMe: false, imageFile: "asset:widget-placeholder-face-2"),
        BoardEntry(id: "hana", name: "Hana Sato", xp: 1040, rank: 3, isMe: false, imageFile: "asset:widget-placeholder-face-3"),
        BoardEntry(id: "jordan", name: "Jordan Ellis", xp: 720, rank: 4, isMe: false, imageFile: "asset:widget-placeholder-face-4"),
        BoardEntry(id: "me", name: "Edison Law", xp: 640, rank: 5, isMe: true, imageFile: nil),
    ]
}

nonisolated extension WidgetSnapshot {
    /// The board, falling back to just you when the app has not written one yet.
    var boardRows: [BoardEntry] {
        if let board, !board.isEmpty { return board }
        return [BoardEntry(id: "me", name: name, xp: xp, rank: 1, isMe: true, imageFile: nil)]
    }

    var myBoardRow: BoardEntry? { boardRows.first { $0.isMe } }
}
