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

/// What a gem looks like for one explorer.
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
    var level: Int { min(9, 1 + likes / 4) }
    /// Saves until the next level.
    var toNext: Int { level >= 9 ? 0 : (level * 4) - likes }

    /// key: (persona, symbol, colour hex, trait label)
    static let kinds: [String: (String, String, String, String)] = [
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
        "food": "food", "books": "library", "outdoors": "park", "culture": "entertainment", "travel": "park",
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

/// The gem itself: a slanted parallelogram cut into facets, lit from the top left.
struct TasteGemView: View {
    var gem: TasteGem
    var size: CGFloat = 120
    /// Slowly sway and sparkle. Off for small or many-at-once gems.
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
                gemBody(t: 0)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(gem.persona) taste gem, level \(gem.level)")
    }

    private func gemBody(t: Double) -> some View {
        let grown = build ?? (0.72 + 0.28 * gem.growth)
        return ZStack {
            // Soft glow in the gem's main colour.
            Circle()
                .fill(RadialGradient(colors: [gem.colors[0].opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: size * 0.55))
                .scaleEffect(1 + 0.04 * sin(t * 1.6))
            Canvas { ctx, canvas in
                draw(&ctx, canvas, t: t)
            }
            .scaleEffect(max(0.05, grown))
            .rotation3DEffect(.degrees(animated ? 9 * sin(t * 0.8) : 0), axis: (x: 0.2, y: 1, z: 0), perspective: 0.6)
        }
    }

    /// Unit-square corners of the slanted gem, like the Odyssey mark.
    private static let a = CGPoint(x: 0.34, y: 0.10), b = CGPoint(x: 0.92, y: 0.02)
    private static let c = CGPoint(x: 0.66, y: 0.90), d = CGPoint(x: 0.08, y: 0.98)

    private func draw(_ ctx: inout GraphicsContext, _ canvas: CGSize, t: Double) {
        let s = canvas.width
        func p(_ u: CGPoint) -> CGPoint { CGPoint(x: u.x * s, y: u.y * s) }
        let mid = CGPoint(x: 0.5, y: 0.5)
        func inner(_ u: CGPoint) -> CGPoint { CGPoint(x: mid.x + (u.x - mid.x) * 0.52, y: mid.y + (u.y - mid.y) * 0.52) }
        let outer = [Self.a, Self.b, Self.c, Self.d]
        let table = outer.map(inner)
        let colors = gem.colors

        // Four crown facets between the outline and the table, each its own shade.
        let shades: [Double] = [0.18, 0.0, -0.22, -0.08]
        for i in 0..<4 {
            var path = Path()
            path.move(to: p(outer[i]))
            path.addLine(to: p(outer[(i + 1) % 4]))
            path.addLine(to: p(table[(i + 1) % 4]))
            path.addLine(to: p(table[i]))
            path.closeSubpath()
            let c1 = colors[i % colors.count], c2 = colors[(i + 1) % colors.count]
            ctx.fill(path, with: .linearGradient(
                Gradient(colors: [c1.adjusted(shades[i] + 0.08), c2.adjusted(shades[i] - 0.1)]),
                startPoint: p(outer[i]), endPoint: p(table[(i + 2) % 4])))
        }
        // The table: brightest, with a moving shine.
        var top = Path()
        top.addLines(table.map(p))
        top.closeSubpath()
        ctx.fill(top, with: .linearGradient(Gradient(colors: [colors[0].adjusted(0.32), colors[1].adjusted(0.1), colors[2 % colors.count].adjusted(0.18)]),
                                            startPoint: p(table[0]), endPoint: p(table[2])))
        let sweep = (sin(t * 0.9) + 1) / 2
        ctx.drawLayer { layer in
            layer.clip(to: top)
            let x = (0.15 + 0.7 * sweep) * s
            var band = Path()
            band.move(to: CGPoint(x: x - s * 0.08, y: 0))
            band.addLine(to: CGPoint(x: x + s * 0.02, y: 0))
            band.addLine(to: CGPoint(x: x - s * 0.18, y: s))
            band.addLine(to: CGPoint(x: x - s * 0.28, y: s))
            band.closeSubpath()
            layer.fill(band, with: .color(.white.opacity(0.35)))
        }
        // Facet edges and the outline.
        var edges = Path()
        for i in 0..<4 {
            edges.move(to: p(outer[i])); edges.addLine(to: p(table[i]))
        }
        ctx.stroke(edges, with: .color(.white.opacity(0.45)), lineWidth: max(0.6, s * 0.006))
        ctx.stroke(top, with: .color(.white.opacity(0.6)), lineWidth: max(0.6, s * 0.007))
        var outline = Path()
        outline.addLines(outer.map(p))
        outline.closeSubpath()
        ctx.stroke(outline, with: .color(.white.opacity(0.85)), lineWidth: max(1, s * 0.012))

        // Sparkles: more as the gem grows.
        guard animated else { return }
        let count = 2 + Int(gem.growth * 5)
        for i in 0..<count {
            let phase = t * 1.3 + Double(i) * 1.7
            let alpha = max(0, sin(phase))
            let u = CGPoint(x: 0.2 + 0.6 * ((Double(i) * 0.37).truncatingRemainder(dividingBy: 1)),
                            y: 0.15 + 0.7 * ((Double(i) * 0.61).truncatingRemainder(dividingBy: 1)))
            let r = s * 0.025 * alpha
            ctx.fill(Path(ellipseIn: CGRect(x: u.x * s - r, y: u.y * s - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(alpha * 0.9)))
        }
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
                Text("Level \(gem.level) gem · \(gem.traits.prefix(2).joined(separator: ", "))")
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
