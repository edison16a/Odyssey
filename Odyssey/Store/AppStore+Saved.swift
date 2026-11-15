//
//  AppStore+Saved.swift
//  Odyssey
//
//  Starred places and Explore's recommendations. A star keeps a place on
//  your map until you take it off. Every place Explore shows you is noted,
//  and checking in at one of them later pays a recommendation bonus.
//

import Foundation

extension AppStore {
    func isStarred(_ place: Place) -> Bool { state.starred[place.id] != nil }

    /// Star or unstar a place. Returns true when it is now starred.
    @discardableResult
    func toggleStar(_ place: Place) -> Bool {
        let on = !isStarred(place)
        update { s in s.starred[place.id] = on ? place : nil }
        Cloud.shared.recordStar(place, on: on)
        return on
    }

    /// Starred places, the latest first by name for a steady order.
    var starredPlaces: [Place] {
        state.starred.values.sorted { $0.name < $1.name }
    }

    /// Note places Explore just showed you. The newest 400 are kept.
    func markRecommended(_ places: [Place]) {
        let fresh = places.map(\.id).filter { !state.recommended.contains($0) }
        guard !fresh.isEmpty else { return }
        // Quietly: no screen shows this list, and it changes while you swipe the feed.
        updateQuietly { s in
            s.recommended += fresh
            if s.recommended.count > 400 { s.recommended.removeFirst(s.recommended.count - 400) }
        }
    }

    /// True when Explore recommended the place or you starred it from there.
    func isRecommended(_ place: Place) -> Bool {
        state.recommended.contains(place.id) || isStarred(place)
    }
}
