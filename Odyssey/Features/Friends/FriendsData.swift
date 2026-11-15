//
//  FriendsData.swift
//  Odyssey
//
//  Where friends explored, as hexagons. A place a friend explored (one of
//  the places in their posts) fills the hex cell around it with that
//  friend's color. Colors are handed out by the order you added friends,
//  so a friend keeps the same color everywhere in the app.
//

import CoreLocation
import Foundation
import MapKit
import SwiftUI

enum FriendColors {
    /// Nine colors that stay apart from each other and read well on the muted map.
    static let all: [Color] = [
        "#e5484d", // red
        "#f76b15", // orange
        "#e8a800", // amber
        "#2fa84f", // green
        "#0e9f9a", // teal
        "#2f6feb", // blue
        "#7c5cfc", // violet
        "#e93d82", // pink
        "#a0653b", // brown
    ].map { Color(hex: $0) }
}

/// One filled hex on the friends map.
struct FriendHex: Identifiable {
    var id: String
    var corners: [CLLocationCoordinate2D]
    var personID: String
    var color: Color
}

extension AppStore {
    /// The places someone explored: the distinct places in their posts, oldest first.
    func exploredPlaces(of id: String) -> [Place] {
        var seen = Set<String>()
        var out: [Place] = []
        for post in posts(by: id).reversed() where seen.insert(post.placeId).inserted {
            if let place = place(post.placeId) { out.append(place) }
        }
        return out
    }

    /// A friend's color, picked by their place in your friends list. Anyone
    /// else gets a stable color from their id.
    func friendColor(_ id: String) -> Color {
        let colors = FriendColors.all
        if let i = state.friends.firstIndex(of: id) { return colors[i % colors.count] }
        let sum = id.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return colors[sum % colors.count]
    }

    /// Hexes for these people. When two people explored the same cell, the
    /// one with more places there owns it, then whoever comes first.
    func friendHexes(_ ids: [String], size: Double) -> [FriendHex] {
        var owner: [TravelHexGrid.Cell: (id: String, count: Int, order: Int)] = [:]
        for (order, id) in ids.enumerated() {
            var counts: [TravelHexGrid.Cell: Int] = [:]
            for place in exploredPlaces(of: id) {
                counts[TravelHexGrid.cell(of: place.coords, size: size), default: 0] += 1
            }
            for (cell, count) in counts {
                if let current = owner[cell], current.count >= count { continue }
                owner[cell] = (id, count, order)
            }
        }
        return owner
            .sorted { ($0.value.order, $0.key.q, $0.key.r) < ($1.value.order, $1.key.q, $1.key.r) }
            .map { cell, who in
                FriendHex(id: "\(who.id)-\(cell.q)-\(cell.r)", corners: TravelHexGrid.corners(cell, size: size),
                          personID: who.id, color: friendColor(who.id))
            }
    }

    /// A region that fits every place these people explored.
    func friendsRegion(_ ids: [String]) -> MKCoordinateRegion {
        let coords = ids.flatMap { exploredPlaces(of: $0).map(\.coords) }
        guard let first = coords.first else {
            return MKCoordinateRegion(center: here.location, span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03))
        }
        var minLat = first.lat, maxLat = first.lat, minLng = first.lng, maxLng = first.lng
        for c in coords {
            minLat = min(minLat, c.lat); maxLat = max(maxLat, c.lat)
            minLng = min(minLng, c.lng); maxLng = max(maxLng, c.lng)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max(0.012, (maxLat - minLat) * 1.5),
                                    longitudeDelta: max(0.012, (maxLng - minLng) * 1.5))
        return MKCoordinateRegion(center: center, span: span)
    }
}

/// Cell size for a map showing this span across this width, the same steps the explored map uses.
func friendsHexSize(longitudeDelta: Double, width: Double) -> Double {
    TravelHexGrid.cellSize(zoom: TravelHexGrid.zoom(longitudeDelta: longitudeDelta, width: width))
}
