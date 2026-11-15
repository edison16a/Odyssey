//
//  TasteGem.swift
//  Odyssey
//
//  Your taste gem: a faceted gem in the slanted shape of the Odyssey mark,
//  coloured by what you like and growing with every place you save. The
//  colours come from your strongest kinds of places (cafes are amber, parks
//  green, nightlife indigo...), so no two explorers' gems look the same.
//  Onboarding builds it, Explore grows it, Profile shows it off.
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
        let top = score.filter { $0.value > 0 }.sorted { $0.value > $1.value }.prefix(3).map(\.key)
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

/// The gem itself: a slanted, cleanly cut stone in the shape of the Odyssey mark.
/// One main colour shaded per facet, a hint of your second taste in the table,
/// and a single slow glint. No glow, wobble or sparkles.
struct TasteGemView: View {
    var gem: TasteGem
    var size: CGFloat = 120
    /// Run the slow glint across the table. Off for small or many-at-once gems.
    var animated = true
    /// 0...1 override for how built the gem is (onboarding assembles it); nil uses the gem's growth.
    var build: Double? = nil

    var body: some View {
        Group {
            if animated {
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    gemBody(t: context.date.timeIntervalSinceReferenceDate)
                }
            } else {
                gemBody(t: nil)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(gem.persona) taste gem")
    }

    private func gemBody(t: Double?) -> some View {
        let grown = build ?? (0.82 + 0.18 * gem.growth)
        return Canvas { ctx, canvas in draw(&ctx, canvas, t: t) }
            .scaleEffect(max(0.05, grown))
            .shadow(color: gem.colors[0].adjusted(-0.3).opacity(size > 60 ? 0.35 : 0.25), radius: size * 0.06, y: size * 0.04)
    }

    /// Unit-square corners of the slanted gem, like the Odyssey mark.
    private static let a = CGPoint(x: 0.34, y: 0.10), b = CGPoint(x: 0.92, y: 0.02)
    private static let c = CGPoint(x: 0.66, y: 0.90), d = CGPoint(x: 0.08, y: 0.98)

    private func draw(_ ctx: inout GraphicsContext, _ canvas: CGSize, t: Double?) {
        let s = canvas.width
        func p(_ u: CGPoint) -> CGPoint { CGPoint(x: u.x * s, y: u.y * s) }
        let mid = CGPoint(x: 0.5, y: 0.5)
        func inner(_ u: CGPoint) -> CGPoint { CGPoint(x: mid.x + (u.x - mid.x) * 0.5, y: mid.y + (u.y - mid.y) * 0.5) }
        let outer = [Self.a, Self.b, Self.c, Self.d]
        let table = outer.map(inner)
        let main = gem.colors[0]
        let second = gem.colors.count > 1 ? gem.colors[1] : main

        // Crown facets: one colour, lit from the top left (top, right, bottom, left).
        let shades: [Double] = [0.28, -0.12, -0.38, 0.08]
        for i in 0..<4 {
            var facet = Path()
            facet.move(to: p(outer[i]))
            facet.addLine(to: p(outer[(i + 1) % 4]))
            facet.addLine(to: p(table[(i + 1) % 4]))
            facet.addLine(to: p(table[i]))
            facet.closeSubpath()
            ctx.fill(facet, with: .color(main.adjusted(shades[i])))
        }
        // The table: the brightest face, leaning toward your second taste.
        var top = Path()
        top.addLines(table.map(p))
        top.closeSubpath()
        ctx.fill(top, with: .linearGradient(Gradient(colors: [main.adjusted(0.42), main.adjusted(0.12), second.adjusted(0.05)]),
                                            startPoint: p(table[0]), endPoint: p(table[2])))
        // A fixed highlight on the top-left corner of the table.
        var spec = Path()
        spec.move(to: p(table[0]))
        spec.addLine(to: p(CGPoint(x: table[0].x + (table[1].x - table[0].x) * 0.45, y: table[0].y + (table[1].y - table[0].y) * 0.45)))
        spec.addLine(to: p(CGPoint(x: table[0].x + (table[3].x - table[0].x) * 0.45, y: table[0].y + (table[3].y - table[0].y) * 0.45)))
        spec.closeSubpath()
        ctx.fill(spec, with: .color(.white.opacity(0.28)))

        // One slow glint every few seconds.
        if let t {
            let cycle = (t / 4.5).truncatingRemainder(dividingBy: 1)
            if cycle < 0.3 {
                let q = cycle / 0.3
                ctx.drawLayer { layer in
                    layer.clip(to: top)
                    let x = (-0.2 + 1.4 * q) * s
                    var band = Path()
                    band.move(to: CGPoint(x: x, y: 0))
                    band.addLine(to: CGPoint(x: x + s * 0.07, y: 0))
                    band.addLine(to: CGPoint(x: x - s * 0.13, y: s))
                    band.addLine(to: CGPoint(x: x - s * 0.2, y: s))
                    band.closeSubpath()
                    layer.fill(band, with: .color(.white.opacity(0.4 * sin(q * .pi))))
                }
            }
        }

        // Hairline facet edges only; no heavy outline.
        var edges = Path()
        for i in 0..<4 {
            edges.move(to: p(outer[i])); edges.addLine(to: p(table[i]))
        }
        edges.addPath(top)
        ctx.stroke(edges, with: .color(.white.opacity(0.35)), lineWidth: max(0.5, s * 0.005))
    }
}

/// Gem, explorer type and level in one row, for headers.
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
