//
//  HomeMapContent.swift
//  Odyssey
//
//  Turns the explored layer into plain drawable shapes for the current
//  zoom and viewport, styled like the mockup: yours solid blue, explored
//  by others lighter blue, nobody yet dashed grey. Only what is on screen
//  is handed to MapKit, so close in maps stay smooth.
//

import CoreLocation
import Foundation
import MapKit
import SwiftUI

struct HomeMapPolygon: Identifiable {
    var id: String
    var coords: [CLLocationCoordinate2D]
    var fill: Color
    var stroke: Color
    var width: CGFloat
    var dash: [CGFloat] = []
}

struct HomeMapLine: Identifiable {
    var id: String
    var coords: [CLLocationCoordinate2D]
    var color: Color
    var width: CGFloat
    var dash: [CGFloat] = []
}

struct HomeMapCircle: Identifiable {
    var id: String
    var center: CLLocationCoordinate2D
    var radius: Double
    var fill: Color
    var stroke: Color
    var width: CGFloat
    var dash: [CGFloat] = []
}

enum HomeMapStyle {
    static let blue = Palette.accent
    static let grey = Color(hex: "#8d8d96")

    static func fill(_ look: HomeExploredLayer.Look) -> (fill: Color, stroke: Color, width: CGFloat, dash: [CGFloat]) {
        switch look {
        case .mine: return (blue.opacity(0.42), blue.opacity(0.95), 2, [])
        case .explored: return (blue.opacity(0.24), blue.opacity(0.8), 1.5, [])
        case .fog: return (Palette.ink.opacity(0.08), grey.opacity(0.75), 1.2, [3, 4])
        }
    }

    static func hex(_ rank: Int) -> (fill: Color, stroke: Color, width: CGFloat) {
        switch rank {
        case 3: return (blue.opacity(0.26), blue.opacity(0.55), 0.8)
        case 2: return (blue.opacity(0.15), blue.opacity(0.35), 0.7)
        default: return (Palette.ink.opacity(0.06), grey.opacity(0.35), 0.6)
        }
    }
}

extension HomeExploredLayer {
    /// True when a point sits inside the region, grown by half on every side.
    private static func onScreen(_ c: Coord, _ region: MKCoordinateRegion?) -> Bool {
        guard let region else { return true }
        let dLat = region.span.latitudeDelta, dLng = region.span.longitudeDelta
        return abs(c.lat - region.center.latitude) < dLat && abs(c.lng - region.center.longitude) < dLng
    }

    /// True when any of the first, middle or last point of a shape is near the screen.
    private static func near(_ points: [Coord], _ region: MKCoordinateRegion?) -> Bool {
        guard let first = points.first, let last = points.last else { return false }
        return onScreen(first, region) || onScreen(last, region) || onScreen(points[points.count / 2], region)
    }

    private static func coords(_ ring: [Coord]) -> [CLLocationCoordinate2D] { ring.map(\.location) }

    func polygons(zoom z: Int, region: MKCoordinateRegion?) -> [HomeMapPolygon] {
        var out: [HomeMapPolygon] = []
        var hexes: [HomeHexCell] = []
        if Self.showSmall(z) { hexes += small }
        if Self.showMid(z) { hexes += mid }
        if Self.showLarge(z) { hexes += large }
        for cell in hexes where Self.onScreen(cell.center, region) {
            let style = HomeMapStyle.hex(cell.rank)
            out.append(HomeMapPolygon(id: "h\(cell.corners.count)-\(Int(cell.center.lat * 1e6))-\(Int(cell.center.lng * 1e6))", coords: Self.coords(cell.corners),
                                      fill: style.fill, stroke: style.stroke, width: style.width))
        }
        if Self.showStreet(z) {
            for fill in fills where fill.circle == nil && Self.near(fill.rings.first ?? [], region) {
                let style = HomeMapStyle.fill(fill.look)
                for (i, ring) in fill.rings.enumerated() {
                    out.append(HomeMapPolygon(id: "f-\(fill.id)-\(i)", coords: Self.coords(ring), fill: style.fill,
                                              stroke: style.stroke, width: style.width, dash: style.dash))
                }
            }
        }
        let regions: [Region] = Self.showCity(z) ? cities : (Self.showState(z) ? states : [])
        for region in regions {
            for (i, ring) in region.rings.enumerated() {
                out.append(HomeMapPolygon(
                    id: "r-\(region.id)-\(i)", coords: Self.coords(ring),
                    fill: region.explored ? HomeMapStyle.blue.opacity(0.2) : Palette.ink.opacity(0.05),
                    stroke: region.explored ? HomeMapStyle.blue.opacity(0.9) : HomeMapStyle.grey.opacity(0.6),
                    width: region.explored ? 2.5 : 1.2, dash: region.explored ? [] : [5, 6]))
            }
        }
        return out
    }

    func mapLines(zoom z: Int, region: MKCoordinateRegion?) -> [HomeMapLine] {
        guard Self.showStreet(z) else { return [] }
        return lines.filter { $0.coords.count > 1 && Self.near($0.coords, region) }.map { line in
            line.lit
                ? HomeMapLine(id: line.id, coords: Self.coords(line.coords), color: HomeMapStyle.blue.opacity(0.34), width: 6)
                : HomeMapLine(id: line.id, coords: Self.coords(line.coords), color: HomeMapStyle.grey.opacity(0.55), width: 4, dash: [1, 9])
        }
    }

    func circles(zoom z: Int, region: MKCoordinateRegion?) -> [HomeMapCircle] {
        guard Self.showStreet(z) else { return [] }
        return fills.compactMap { fill in
            guard let circle = fill.circle, Self.onScreen(circle.center, region) else { return nil }
            let style = HomeMapStyle.fill(fill.look)
            return HomeMapCircle(id: "c-\(fill.id)", center: circle.center.location, radius: circle.radius,
                                 fill: style.fill, stroke: style.stroke, width: style.width, dash: style.dash)
        }
    }

    /// City or state name pills for the current zoom.
    func labels(zoom z: Int) -> [Region] {
        if Self.showCity(z) { return cities }
        if Self.showState(z) { return states }
        return []
    }
}
