//
//  TasteProfileData.swift
//  Odyssey
//
//  Everything the "What Odyssey knows about you" page shows, worked out
//  once when it opens: an explorer type from your strongest category, your
//  taste weights in plain words, the kinds of places you actually go, when
//  in the day you tend to explore, and your recent thumbs.
//

import Foundation
import SwiftUI

struct TasteProfile {
    struct Weight: Identifiable {
        var id: String
        var label: String
        var value: Double
    }

    struct Thumb: Identifiable {
        var id: String
        var name: String
        var up: Bool
        var date: Date
    }

    var persona: (name: String, icon: String, color: Color)
    var likes: [Weight]
    var dislikes: [Weight]
    var visitedKinds: [(label: String, icon: String, count: Int)]
    var interests: [String]
    /// Morning, afternoon, evening and night, as shares of your thumbs.
    var dayParts: [Double]
    var thumbs: [Thumb]

    @MainActor
    init(store: AppStore) {
        let w = store.state.taste.weights
        func label(_ f: String) -> String {
            if let p = AppStore.phrase[f] { return p.prefix(1).uppercased() + p.dropFirst() }
            if f.hasPrefix("cat:") { return store.seed.discoverCategory(String(f.dropFirst(4)))?.label ?? String(f.dropFirst(4)) }
            if f.hasPrefix("cuisine:") { return String(f.dropFirst(8)).replacingOccurrences(of: "_", with: " ").capitalized + " food" }
            return f
        }
        let readable = w.filter { AppStore.phrase[$0.key] != nil || $0.key.hasPrefix("cat:") || $0.key.hasPrefix("cuisine:") }
        likes = readable.filter { $0.value > 0.2 }.sorted { $0.value > $1.value }.prefix(8)
            .map { Weight(id: $0.key, label: label($0.key), value: $0.value) }
        dislikes = readable.filter { $0.value < -0.2 }.sorted { $0.value < $1.value }.prefix(6)
            .map { Weight(id: $0.key, label: label($0.key), value: $0.value) }

        var kinds: [String: Int] = [:]
        for place in store.myPlaces {
            for cat in store.tasteCategories(place) { kinds[cat, default: 0] += 1 }
        }
        visitedKinds = kinds.sorted { $0.value > $1.value }.prefix(6).compactMap { pair in
            store.seed.discoverCategory(pair.key).map { ($0.label, $0.icon, pair.value) }
        }

        // Same explorer type as the badge that opened this page (Cafe Hopper by default).
        let gem = TasteGem.of(store)
        persona = (gem.persona, gem.icon, gem.colors.first ?? Palette.accent)

        interests = store.state.interests.filter(\.value).keys.sorted().map { store.seed.interestLabels[$0] ?? $0.capitalized }

        let votes = store.state.taste.votes
        thumbs = votes.map { Thumb(id: $0.key, name: $0.value.name, up: $0.value.v > 0, date: Date(timeIntervalSince1970: $0.value.at / 1000)) }
            .sorted { $0.date > $1.date }
        var parts = [0.0, 0, 0, 0]
        for thumb in thumbs {
            let hour = Calendar.current.component(.hour, from: thumb.date)
            parts[hour >= 5 && hour < 12 ? 0 : hour < 17 && hour >= 12 ? 1 : hour >= 17 && hour < 22 ? 2 : 3] += 1
        }
        let total = parts.reduce(0, +)
        dayParts = total > 0 ? parts.map { $0 / total } : []
    }

    /// "You explore most in the evening", when there is enough to say.
    var dayLine: String? {
        guard thumbs.count >= 3, let top = dayParts.indices.max(by: { dayParts[$0] < dayParts[$1] }) else { return nil }
        return "You explore most " + ["in the morning", "in the afternoon", "in the evening", "late at night"][top]
    }
}
