//
//  HomeMapWorld.swift
//  Odyssey
//
//  The two world layers of the home map. Footprints: every hex you have
//  walked through, in solid blue, the way a footprints map fills in as you
//  go. World pins: the shops, cafes and parks found around you through Apple
//  Maps and OpenStreetMap, so the map works wherever you are.
//
//  Both are worked out for what is on screen only. The hexes are built off
//  the main thread and capped, so a long walking history never slows the
//  map down.
//

import CoreLocation
import Foundation
import MapKit
import SwiftUI

nonisolated struct HomeFootHex: Identifiable, Sendable {
    var id: FootCell
    var coords: [CLLocationCoordinate2D]
}

/// The visible box of the map, as plain numbers that can cross threads.
nonisolated struct HomeMapBox: Sendable, Equatable {
    var minLat: Double, maxLat: Double, minLng: Double, maxLng: Double

    init(_ region: MKCoordinateRegion) {
        // Half a screen of margin on every side, so a small pan does not show a hard edge.
        let dLat = region.span.latitudeDelta, dLng = region.span.longitudeDelta
        minLat = region.center.latitude - dLat
        maxLat = region.center.latitude + dLat
        minLng = region.center.longitude - dLng
        maxLng = region.center.longitude + dLng
    }

    func contains(_ c: Coord) -> Bool {
        c.lat >= minLat && c.lat <= maxLat && c.lng >= minLng && c.lng <= maxLng
    }

    var center: Coord { Coord((minLat + maxLat) / 2, (minLng + maxLng) / 2) }
}

nonisolated enum HomeMapWorld {
    /// Footprint hexes show from neighbourhood level in.
    static func showsFootprints(_ zoom: Int) -> Bool { zoom >= 13 }

    /// The walked hexes inside the box, built in the background. Zoomed out, they are
    /// merged into hexes three times as wide, which reads the same and draws far fewer shapes.
    static func hexes(points: [Coord], box: HomeMapBox, zoom: Int) async -> [HomeFootHex] {
        await Task.detached(priority: .userInitiated) {
            let fine = FootGrid.cachedCells(points).filter { box.contains(FootGrid.center($0)) }
            let size = zoom >= 15 ? FootGrid.size : FootGrid.size * 3
            let cells = zoom >= 15 ? fine : Set(fine.map { FootGrid.cell(for: FootGrid.center($0), size: size) })
            let cap = zoom >= 15 ? 900 : 500
            return cells.prefix(cap).map { HomeFootHex(id: $0, coords: FootGrid.corners($0, size: size).map(\.location)) }
        }.value
    }

    /// A ready to draw pin for a place.
    @MainActor
    static func pin(_ place: Place, store: AppStore, label: Bool, starred: Bool = false) -> HomePin {
        let status = store.status(of: place).status
        let kind: HomePin.Kind = starred ? .star : (status == .new ? .new : (status == .mine ? .mine : .explored))
        let first = status == .mine && store.state.firsts.contains(place.id)
        let glyph = status == .new ? "star-fill" : (first ? "crown" : (status == .mine ? "check" : store.placeKind(place).icon))
        return HomePin(id: place.id, placeID: place.id, name: place.name, coord: place.coords,
                       kind: kind, glyph: glyph, pulses: false, label: label)
    }

    /// How many pins a zoom level gets. Like Google Maps: a few landmarks zoomed
    /// out, more places as you zoom in, never so many that MapKit chokes.
    static func budget(_ zoom: Int) -> Int {
        switch zoom {
        case ..<12: return 0
        case 12: return 6
        case 13: return 10
        case 14: return 16
        case 15: return 24
        case 16: return 32
        default: return 40
        }
    }

    /// The pins for the current view. Places are ranked (starred, curated, bounty,
    /// well reviewed first), then spread out on a screen grid so they never stack,
    /// and only the top ones carry their name.
    @MainActor
    static func pins(store: AppStore, box: HomeMapBox?, zoom: Int, filter: String) -> [HomePin] {
        let budget = budget(zoom)
        guard budget > 0, let box else { return [] }
        let keep = { (place: Place) in filter == "all" || store.status(of: place).status.rawValue == filter }
        let starred = Set(store.state.starred.keys)
        var candidates = store.seed.places.filter { keep($0) && box.contains($0.coords) }
        if zoom >= 14 {
            candidates += store.osmPlaces.values.filter { $0.curated == nil && keep($0) && box.contains($0.coords) }
        }
        let have = Set(candidates.map(\.id))
        candidates += store.starredPlaces.filter { box.contains($0.coords) && !have.contains($0.id) }
        // Worked out once: asking the store per place rebuilt the whole bounty list every time.
        let bounties = store.openBounties
        let ranked = candidates.map { ($0, rank($0, store: store, starred: starred, bounties: bounties)) }.sorted { $0.1 > $1.1 }.map(\.0)

        // The box is about two screens across; a 6 x 10 grid keeps pins about a thumb apart.
        let cols = 6.0, rows = 10.0
        let w = (box.maxLng - box.minLng) / cols, h = (box.maxLat - box.minLat) / rows
        var taken = Set<Int>()
        var out: [HomePin] = []
        for place in ranked {
            guard out.count < budget else { break }
            let cx = Int((place.coords.lng - box.minLng) / max(w, 1e-9))
            let cy = Int((place.coords.lat - box.minLat) / max(h, 1e-9))
            guard taken.insert(cy * 100 + cx).inserted else { continue }
            // Names on the top half; all of them once you are at street level.
            let label = zoom >= 16 || out.count < max(4, budget / 2)
            out.append(pin(place, store: store, label: label, starred: starred.contains(place.id)))
        }
        return out
    }

    /// How important a place is on the map.
    @MainActor
    private static func rank(_ place: Place, store: AppStore, starred: Set<String>, bounties: [Bounty]) -> Double {
        var score = 0.0
        if starred.contains(place.id) { score += 200 }
        if !place.isOSM { score += 100 }
        if store.bounty(for: place, in: bounties) != nil { score += 60 }
        if store.status(of: place).status == .mine { score += 20 }
        score += log(1 + Double(place.reviews ?? 0)) * 6 + (place.rating ?? 0) * 2
        return score
    }
}

/// How big your walked area is, shown over the map.
struct HomeFootprintChip: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let area = store.footprintArea
        if area > 0 {
            HStack(spacing: 6) {
                Image(systemName: "figure.walk").font(.system(size: 11, weight: .bold))
                Text(area < 1 ? String(format: "%.2f km² walked", area) : String(format: "%.1f km² walked", area))
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(Palette.accentInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white, in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        }
    }
}
