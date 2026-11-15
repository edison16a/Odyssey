//
//  WidgetBoardBridge.swift
//  Odyssey
//
//  Builds the Leaderboard widget's data: friends and you ranked by XP, the
//  same board as This week on the Friends tab, and your best area standing.
//  Faces are copied into the App Group like the other widget photos.
//

import Foundation
import UIKit

extension WidgetBridge {
    /// The top five, with you swapped in as the fifth row when you are further down.
    @MainActor
    static func board(from store: AppStore) -> [BoardEntry] {
        let ranked = (store.friends + [store.me]).sorted { $0.xp > $1.xp }
        var shown = Array(ranked.enumerated().prefix(5))
        if !shown.contains(where: { $0.element.id == "me" }), let mine = ranked.enumerated().first(where: { $0.element.id == "me" }) {
            shown[shown.count - 1] = mine
        }
        return shown.map { index, person in
            BoardEntry(id: person.id, name: person.name, xp: person.xp, rank: index + 1, isMe: person.id == "me",
                       imageFile: face(person))
        }
    }

    @MainActor
    static func standing(from store: AppStore) -> StandingSnapshot {
        let best = store.bestStanding
        return StandingSnapshot(position: best.position, pct: best.pct, scope: best.scope.label)
    }

    /// Copy a face into the shared folder and name the file, or nil for the initial.
    @MainActor
    private static func face(_ person: Person) -> String? {
        guard let value = person.avatar.value, !value.isEmpty else { return nil }
        let file = "widget-board-\(person.id).jpg"
        switch person.avatar.kind {
        case "photo":
            copy(asset: Media.name(for: value), to: file, maxSide: 160)
        case "local", "upload":
            copy(path: PhotoStore.folder.appendingPathComponent(value), to: file, maxSide: 160)
        default:
            return nil
        }
        return file
    }
}
