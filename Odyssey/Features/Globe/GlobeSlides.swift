//
//  GlobeSlides.swift
//  Odyssey
//
//  The Odyssey Globe slides: a year in places, told one stat per screen.
//  Numbers come from your saved state where they exist (places explored,
//  km, first finds, standings) so the recap changes after you explore.
//  Ported from features/globe/globe-slides.js and globe.css.
//

import Foundation
import SwiftUI

enum GlobeSlide: Int, CaseIterable {
    case opener, places, walked, top, firsts, twin, friend, rank, summary

    var ink: Bool { self == .walked }
    var final: Bool { self == .summary }

    func background(_ store: AppStore) -> Color {
        switch self {
        case .opener, .summary: return .black
        case .places: return Color(hex: "#2b59ff")
        case .walked: return Color(hex: "#f5e6c8")
        case .top: return Color(hex: "#0b0b0c")
        case .firsts: return Color(hex: "#8a5cff")
        case .twin: return Color(hex: GlobeData.twin(store).color)
        case .friend: return Color(hex: "#17a35a")
        case .rank: return Color(hex: "#ff6a2b")
        }
    }
}

/// The numbers behind the slides.
enum GlobeData {
    /// The explorer whose trait lines up with your interests, like explorer-icon.js.
    static func twin(_ store: AppStore) -> Explorer {
        let i = store.state.interests
        let id: String
        if i["books"] == true { id = "xuanzang" }
        else if i["outdoors"] == true { id = "tenzing-norgay" }
        else if i["culture"] == true { id = "ida-pfeiffer" }
        else if i["nightlife"] == true { id = "nellie-bly" }
        else { id = "ibn-battuta" }
        return store.seed.explorer(id) ?? store.seed.explorers[0]
    }

    /// The kind of place you visited most, and those places.
    static func topCategory(_ store: AppStore) -> (label: String, places: [Place]) {
        let visited = store.state.visited.compactMap { store.place($0) }
        var order: [String] = []
        var counts: [String: Int] = [:]
        for place in visited {
            let label = store.placeKind(place).label
            if counts[label] == nil { order.append(label) }
            counts[label, default: 0] += 1
        }
        let top = order.enumerated().sorted { a, b in
            let countA: Int = counts[a.element] ?? 0
            let countB: Int = counts[b.element] ?? 0
            return countA != countB ? countA > countB : a.offset < b.offset
        }.first?.element ?? "Library"
        return (top, visited.filter { store.placeKind($0).label == top })
    }
}

struct GlobeSlideView: View {
    var slide: GlobeSlide
    var replay: () -> Void
    @Environment(AppStore.self) private var store
    @State private var shown = false

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(parts.enumerated()), id: \.offset) { i, part in
                part
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown ? 0 : 14)
                    .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.46).delay(Double(min(i, 4)) * 0.08), value: shown)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .onAppear { shown = true }
    }

    private var parts: [AnyView] {
        let s = store.state
        switch slide {
        case .opener:
            return [AnyView(GlobeArt(size: 200).padding(.bottom, 18)), eyebrow("Odyssey Globe"), big("Your 2026\nin places"), sub("Tap to begin")]
        case .places:
            let visited = s.visited.compactMap { store.place($0) }
            return [eyebrow("This year you explored"), number("\(s.stats.explored)"), h2("places"),
                    sub("12 more than last year. Most of them on foot."), AnyView(GlobePhotos(places: visited))]
        case .walked:
            return [eyebrow("You walked"), number(Format.number(store.kmWalked), small: "km"),
                    sub("Roughly Berkeley to Monterey. Not bad for someone who said they would just get coffee."), AnyView(GlobeRoute())]
        case .top:
            let cat = GlobeData.topCategory(store)
            let visited = s.visited.compactMap { store.place($0) }
            return [eyebrow("Your top kind of place"), big(cat.label),
                    sub("\(cat.places.count) visits. You always knew where the quiet seats were."),
                    AnyView(GlobePhotos(places: cat.places.isEmpty ? visited : cat.places))]
        case .firsts:
            let box = Image(systemName: "star.fill").font(.system(size: 40))
                .frame(width: 104, height: 104)
                .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            return [AnyView(box), eyebrow("First explorer"), number("\(s.firsts.count)"),
                    h2("places you discovered first on Odyssey"), sub("Your name is on every one of them, for good.")]
        case .twin:
            let twin = GlobeData.twin(store)
            let portrait = ExplorerPortrait(explorerID: twin.id, width: 150)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 20, y: 18)
                .rotationEffect(.degrees(-3))
            return [eyebrow("Your explorer twin"), AnyView(portrait), big(twin.name), sub(twin.trait + ". " + twin.known)]
        case .friend:
            return [eyebrow("Your closest explorer"), AnyView(GlobePair()), big(store.person("nina")?.name ?? "Nina Park"),
                    sub("14 adventures together, including the night you both found the rooftop at Soda Hall.")]
        case .rank:
            let rank = store.rank()
            let best = store.bestStanding
            return [eyebrow("You finished the year"), AnyView(RankEmblem(tier: rank.tier, size: 96, inverse: true)), big(rank.current.name),
                    sub("Top \(ProfileTravel.pct(best.pct))% in \(best.scope.label). Your \(s.streak.days) day streak is still going.")]
        case .summary:
            return [AnyView(GlobeSummary()), AnyView(GlobeActions(replay: replay))]
        }
    }

    private func eyebrow(_ text: String) -> AnyView {
        AnyView(Text(text).font(.system(size: 11, weight: .bold)).tracking(1.3).textCase(.uppercase).opacity(0.75))
    }

    private func big(_ text: String) -> AnyView {
        AnyView(Text(text).font(.system(size: 40, weight: .bold)).tracking(-1.6))
    }

    private func h2(_ text: String) -> AnyView {
        AnyView(Text(text).font(.system(size: 22, weight: .bold)).tracking(-0.4))
    }

    private func sub(_ text: String) -> AnyView {
        AnyView(Text(text).font(.system(size: 17)).opacity(0.85).frame(maxWidth: 290))
    }

    private func number(_ value: String, small: String? = nil) -> AnyView {
        AnyView(HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value).font(.system(size: 120, weight: .heavy)).tracking(-7).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.5)
            if let small { Text(small).font(.system(size: 34, weight: .heavy)).tracking(-0.7) }
        })
    }
}
