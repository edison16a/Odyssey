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
    /// World pins need street level, or they crowd each other out.
    static func showsWorldPins(_ zoom: Int) -> Bool { zoom >= 15 }

    private static let maxPins = 120

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
    static func pin(_ place: Place, store: AppStore, pulses: Bool) -> HomePin {
        let status = store.status(of: place).status
        let kind: HomePin.Kind = status == .new ? .new : (status == .mine ? .mine : .explored)
        let first = status == .mine && store.state.firsts.contains(place.id)
        let glyph = status == .new ? "star-fill" : (first ? "crown" : (status == .mine ? "check" : store.placeKind(place).icon))
        return HomePin(id: place.id, placeID: place.id, name: place.name, coord: place.coords,
                       kind: kind, glyph: glyph, pulses: pulses)
    }

    /// Every pin for the current view: curated places, the world around you and your stars.
    @MainActor
    static func pins(store: AppStore, box: HomeMapBox?, zoom: Int, filter: String) -> [HomePin] {
        let keep = { (place: Place) in filter == "all" || store.status(of: place).status.rawValue == filter }
        var out: [HomePin] = []
        if zoom >= 13 {
            out += store.seed.places.filter { keep($0) && (box?.contains($0.coords) ?? true) }
                .map { pin($0, store: store, pulses: true) }
        }
        if showsWorldPins(zoom), let box {
            out += worldPlaces(store: store, box: box, filter: filter).map { pin($0, store: store, pulses: false) }
        }
        if zoom >= 12 {
            out += store.starredPlaces.filter { box?.contains($0.coords) ?? true }.map { place in
                HomePin(id: "star-" + place.id, placeID: place.id, name: place.name, coord: place.coords,
                        kind: .star, glyph: "star-fill", pulses: false)
            }
        }
        return out
    }

    /// World places inside the box, closest to the middle first. Places that copy
    /// a curated spot are left out, since the curated pin is already there.
    @MainActor
    static func worldPlaces(store: AppStore, box: HomeMapBox, filter: String) -> [Place] {
        let middle = box.center
        let inside = store.osmPlaces.values.filter { place in
            place.curated == nil && box.contains(place.coords)
                && (filter == "all" || store.status(of: place).status.rawValue == filter)
        }
        return Array(inside.sorted { $0.coords.distance(to: middle) < $1.coords.distance(to: middle) }.prefix(maxPins))
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
