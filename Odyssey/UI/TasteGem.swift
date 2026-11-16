//
//  TasteGem.swift
//  Odyssey
//
//  Your explorer type: a personality like Cafe Hopper, shown as a badge
//  coloured by what you like. The colours come from your strongest kinds of
//  places (cafes are amber, parks green, nightlife indigo...). Everyone starts
//  as a Cafe Hopper; onboarding reveals it, Explore and check-ins shift it.
//

import Foundation
import SwiftUI

/// What a gem looks like for one explorer: a personality, not a level.
/// It changes over time as your saves and check-ins shift your taste.
struct TasteGem: Equatable {
    /// Two to three colours, strongest taste first.
    var colors: [Color]
    /// The explorer type, e.g. "Cafe Hopper".
    var persona: String
    var icon: String
    /// The kinds of places behind the colours, strongest first, e.g. ["Cafes", "Parks", "Night out"].
    var traits: [String]
    /// Places you saved (thumbs up). The gem grows with these.
    var likes: Int

    /// 0...1, how grown the gem is.
    var growth: Double { min(1, Double(likes) / 30) }
    /// Gems have no levels anymore; kept only so older callers still compile.
    var level: Int { 1 }
    var toNext: Int { 0 }

    /// key: (persona, symbol, colour hex, trait label)
    static let kinds: [String: (String, String, String, String)] = [
        "startup": ("Startup Scout", "lightbulb.fill", "#f26522", "Startups"),
        "coffee": ("Cafe Hopper", "cup.and.saucer.fill", "#c27a2c", "Cafes"),
        "food": ("Food Scout", "fork.knife", "#ef5a3c", "Good food"),
        "study": ("Deep Worker", "laptopcomputer", "#2b59ff", "Work spots"),
        "library": ("Bookworm", "book.fill", "#6b4bd8", "Books"),
        "park": ("Open Air Wanderer", "leaf.fill", "#18a85c", "Outdoors"),
        "shopping": ("Treasure Hunter", "bag.fill", "#e04a8a", "Shops"),
        "entertainment": ("Culture Seeker", "theatermasks.fill", "#9a5cff", "Culture"),
        "nightlife": ("Night Owl", "moon.stars.fill", "#3d43a8", "Night out"),
        "dessert": ("Sweet Tooth", "birthday.cake.fill", "#f47fa6", "Sweets"),
        "fitness": ("Mover", "figure.run", "#ff7a1a", "Moving"),
        "gas": ("Road Tripper", "car.fill", "#4a5568", "Road trips"),
    ]

    /// Onboarding answers mapped onto the same kinds.
    private static let interestKinds: [String: String] = [
        "startups": "startup", "food": "food", "books": "library", "outdoors": "park", "culture": "entertainment", "travel": "park",
        "coffee": "coffee", "nightlife": "nightlife", "shopping": "shopping", "fitness": "fitness",
    ]

    /// The gem for whoever is signed in, from their thumbs, check-ins and onboarding answers.
    @MainActor
    static func of(_ store: AppStore) -> TasteGem {
        var score: [String: Double] = [:]
        for (feature, weight) in store.state.taste.weights where feature.hasPrefix("cat:") {
            let key = String(feature.dropFirst(4))
            if kinds[key] != nil { score[key, default: 0] += weight }
        }
        for (answer, yes) in store.state.interests where yes {
            if let key = interestKinds[answer] { score[key, default: 0] += 0.8 }
        }
        for place in store.myPlaces {
            for cat in store.tasteCategories(place) where kinds[cat] != nil { score[cat, default: 0] += 0.3 }
        }
        // Everyone starts as a Cafe Hopper; saves and check-ins can grow other tastes past it.
        score["coffee", default: 0] += 2.5
        // Ties break the same way every time (Cafe Hopper first, then by name), so the
        // type never changes between launches just because dictionary order did.
        let top = score.filter { $0.value > 0 }.sorted {
            if $0.value != $1.value { return $0.value > $1.value }
            if ($0.key == "coffee") != ($1.key == "coffee") { return $0.key == "coffee" }
            return $0.key < $1.key
        }.prefix(3).map(\.key)
        let likes = store.state.taste.votes.values.filter { $0.v > 0 }.count
        guard let first = top.first, let main = kinds[first] else {
            return TasteGem(colors: [Palette.accent, Color(hex: "#8a5cff"), Color(hex: "#18a85c")],
                            persona: "Curious Explorer", icon: "safari.fill", traits: ["Everything"], likes: likes)
        }
        var colors = top.compactMap { kinds[$0].map { Color(hex: $0.2) } }
        while colors.count < 3 { colors.append(colors.count == 1 ? Palette.accent : Color(hex: "#8a5cff")) }
        return TasteGem(colors: colors, persona: main.0, icon: main.1,
                        traits: top.compactMap { kinds[$0]?.3 }, likes: likes)
    }
}

/// Your explorer type as a badge: its icon on a rounded tile shaded from your
/// strongest taste into your second. It pops in during onboarding, and a slow
/// sheen crosses it when animated.
struct TasteGemView: View {
    var gem: TasteGem
    var size: CGFloat = 120
    /// Run the slow sheen across the tile. Off for small or many-at-once badges.
    var animated = true
    /// 0...1 override for how far the badge has appeared (onboarding builds it).
    var build: Double? = nil

    var body: some View {
        let shown = build ?? 1
        // One flat colour and a white symbol, the same look as the taste page's banner.
        let main = gem.colors[0]
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(main)
            Image(systemName: gem.icon)
                .font(.system(size: size * 0.46, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .scaleEffect(max(0.05, shown))
        .opacity(min(1, shown * 1.6))
        .shadow(color: main.opacity(size > 60 ? 0.35 : 0), radius: size * 0.08, y: size * 0.05)
        .accessibilityLabel("Explorer type: \(gem.persona)")
    }
}

/// Explorer type badge and its traits in one row, for headers.
struct TasteGemBadge: View {
    var gem: TasteGem
    var size: CGFloat = 44

    var body: some View {
        HStack(spacing: 10) {
            TasteGemView(gem: gem, size: size, animated: true)
            VStack(alignment: .leading, spacing: 1) {
                Text(gem.persona).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                Text(gem.traits.prefix(3).joined(separator: " · "))
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.muted).lineLimit(1)
            }
        }
    }
}

extension Color {
    /// Lighter (positive) or darker (negative) by an amount in -1...1.
    func adjusted(_ amount: Double) -> Color {
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        let nb = min(1, max(0, b + CGFloat(amount) * (amount > 0 ? (1 - b) * 1.6 : b)))
        let ns = amount > 0 ? max(0, s - CGFloat(amount) * 0.35) : s
        return Color(hue: Double(h), saturation: Double(ns), brightness: Double(nb), opacity: Double(a))
    }
}
