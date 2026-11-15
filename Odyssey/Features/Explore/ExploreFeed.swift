//
//  ExploreFeed.swift
//  Odyssey
//
//  The endless stream behind the Explore deck. It starts with the places
//  around the Explore location, deals them a few at a time in the order
//  your taste ranks them, and when the nearby ones run low it loads the
//  next ring of map tiles outward, so there is always another card. Every
//  card dealt is noted as recommended, which is what makes a later check-in
//  there pay the bonus.
//

import Foundation
import Observation
import SwiftUI

/// What the deck is showing: everything, a quick filter, a category or a search.
enum ExploreFilter: Equatable {
    case all, beFirst, close
    case category(String)
    case search(ExploreQuery)

    var label: String {
        switch self {
        case .all: return "All"
        case .beFirst: return "Be first"
        case .close: return "Close by"
        case .category(let id): return id
        case .search(let q): return q.text
        }
    }
}

@Observable
final class ExploreFeed {
    private(set) var cards: [Place] = []
    /// How far into the cards you have swiped.
    var index = 0
    private(set) var loading = true
    private(set) var exhausted = false
    private(set) var note = ""
    private(set) var filter: ExploreFilter = .all

    @ObservationIgnored private var pool: [String: Place] = [:]
    @ObservationIgnored private var dealt: Set<String> = []
    @ObservationIgnored private var ring = 0
    /// Map tiles still to load on the current ring, nearest first.
    @ObservationIgnored private var tiles: [Coord] = []
    @ObservationIgnored private var misses = 0
    /// True when a search found nothing by name and fell back to its category.
    private(set) var broadened = false
    @ObservationIgnored private var growing = false
    @ObservationIgnored private(set) var loadedKey: String?

    private static let batch = 8
    private static let ringStep = 1300.0
    private static let maxRings = 6

    var remaining: Int { max(0, cards.count - index) }

    /// Load the places around the Explore location and deal the first cards.
    func start(store: AppStore, key: String) async {
        guard loadedKey != key || cards.isEmpty else { return }
        loading = true
        cards = []; index = 0; dealt = []; pool = [:]; ring = 0; tiles = []; misses = 0; exhausted = false; broadened = false
        let result = await NearbyService.around(store: store)
        for place in result.places { pool[place.id] = place }
        note = result.note
        absorbWorld(store)
        loadedKey = Task.isCancelled ? nil : key
        loading = false
        await topUp(store: store)
    }

    /// Switch what the deck shows, keeping the places already loaded.
    func apply(_ next: ExploreFilter, store: AppStore) {
        filter = next
        cards = []; index = 0; dealt = []; misses = 0; exhausted = false; broadened = false
        Task { await topUp(store: store) }
    }

    /// Keep a few cards ahead of you, growing outward when nearby runs dry.
    func topUp(store: AppStore) async {
        guard !growing, !loading, remaining < Self.batch else { return }
        growing = true
        defer { growing = false }
        while remaining < Self.batch {
            let open = candidates(store)
            // Places with real photos go first; photo-less map places only once those run out.
            let real = open.filter { !$0.realGallery.isEmpty }
            let fresh = real.isEmpty ? open : real
            if !fresh.isEmpty {
                let ranked = await store.rankForYouOnline(fresh).filter { !dealt.contains($0.id) }
                let next = Array(store.tasteMix(ranked, after: cards).prefix(Self.batch))
                if next.isEmpty { dealt.formUnion(fresh.map(\.id)); continue }
                dealt.formUnion(next.map(\.id))
                cards += next
                store.markRecommended(next)
                continue
            }
            if tiles.isEmpty {
                guard ring < Self.maxRings else { exhausted = remaining == 0; return }
                ring += 1
                tiles = ringTiles(store.exploreCenter)
            }
            // One tile at a time, so the free map services are not flooded.
            let tile = tiles.removeFirst()
            let before = store.osmPlaces.count
            await WorldPlaces.load(around: tile, store: store)
            absorbWorld(store)
            // Offline or nothing out there: stop after a few empty tiles instead of trying them all.
            misses = store.osmPlaces.count == before ? misses + 1 : 0
            if misses >= 3 { exhausted = remaining == 0; return }
        }
    }

    private func candidates(_ store: AppStore) -> [Place] {
        // A map place matched to an Odyssey place is the same spot: show the Odyssey one, with its photos.
        let open = pool.values.filter { place in
            !dealt.contains(place.id) && !(place.curated.map { pool[$0] != nil || dealt.contains($0) } ?? false)
        }
        switch filter {
        case .all: return open
        case .beFirst: return open.filter { store.status(of: $0).status == .new }
        case .close: return open.filter { store.exploreMetres(to: $0) <= 900 }
        case .category(let id): return open.filter { ($0.cats ?? store.tasteCategories($0)).contains(id) }
        case .search(let q):
            let hits = open.filter { Self.matches($0, q) }
            // Nothing by name nearby: after a ring of looking, show the category instead.
            if !hits.isEmpty || ring < 1 || (ring == 1 && !tiles.isEmpty) { return hits }
            broadened = true
            return open.filter { !Set(q.cats).isDisjoint(with: $0.cats ?? store.tasteCategories($0)) }
        }
    }

    /// The query's words in the name or tags, so "ramen" finds ramen shops.
    static func matches(_ place: Place, _ q: ExploreQuery) -> Bool {
        let t = place.tags ?? [:]
        let hay = ([place.name, place.category ?? ""] + ["cuisine", "shop", "amenity", "leisure", "sport", "tourism", "craft"].compactMap { t[$0] }
                   + (place.cats ?? [])).joined(separator: " ").lowercased().replacingOccurrences(of: "_", with: " ")
        return q.words.contains { word in
            let w = word.lowercased()
            let stem = w.count > 4 && w.hasSuffix("s") ? String(w.dropLast()) : w
            return hay.contains(stem)
        }
    }

    /// Eight tiles around the center at the current distance out.
    private func ringTiles(_ center: Coord) -> [Coord] {
        let d = Self.ringStep * Double(ring)
        let lat = d / 111_320
        let lng = d / (111_320 * max(0.2, cos(center.lat * .pi / 180)))
        let offsets = [(1.0, 0.0), (0.0, 1.0), (-1.0, 0.0), (0.0, -1.0), (0.7, 0.7), (-0.7, 0.7), (-0.7, -0.7), (0.7, -0.7)]
        return offsets.map { Coord(center.lat + lat * $0.0, center.lng + lng * $0.1) }
    }

    /// Odyssey's own places and the world places within the rings loaded so far join the pool.
    private func absorbWorld(_ store: AppStore) {
        let center = store.exploreCenter
        let reach = Self.ringStep * Double(ring + 1) + 400
        for place in store.seed.places where pool[place.id] == nil && place.coords.distance(to: center) < reach {
            pool[place.id] = place
        }
        for place in store.osmPlaces.values where pool[place.id] == nil && place.coords.distance(to: center) < reach {
            pool[place.id] = place
        }
    }
}

extension Place {
    /// Photos that really show this place. A stock photo picked for its category does not count,
    /// so the card shows the plain dark fallback instead of passing it off as the place.
    var realGallery: [String] { photoKind == "category" ? [] : gallery }
}

extension AppStore {
    /// Distance on an Explore card: from you, or from the Explore location when that is closer,
    /// so Odyssey's own places in a picked area read in walking minutes like the map places do.
    func exploreMetres(to place: Place) -> Double {
        min(metres(to: place), exploreCenter.distance(to: place.coords))
    }
}
