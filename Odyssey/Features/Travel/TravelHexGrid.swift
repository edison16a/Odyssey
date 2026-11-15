//
//  TravelHexGrid.swift
//  Odyssey
//
//  The hex grid behind the explored map. Every place you have been snaps
//  to a cell and only those cells are painted, so the basemap keeps its
//  normal colors everywhere else. The grid lives in Web Mercator metres,
//  which keeps cells regular at any latitude, and cells grow in powers of
//  two as you zoom out so a trip to Tokyo still shows on the world view.
//  Ported from ui/hex-layer.js with the same numbers.
//

import CoreLocation
import Foundation

enum TravelHexGrid {
    private static let radius = 6_378_137.0
    private static let root3 = 3.0.squareRoot()
    /// Street level cell radius in projected metres, about 90 m on the ground in Berkeley.
    static let base = 110.0
    /// Cells never get smaller than this many points on screen.
    static let minPoints = 9.0

    nonisolated struct Cell: Hashable, Sendable {
        var q: Int
        var r: Int
    }

    /// Cell radius for a zoom level, a power of two steps above the street size.
    static func cellSize(zoom: Double) -> Double {
        let perPixel = 40_075_016.686 / pow(2, zoom + 8)
        let k = max(0, (log2(perPixel * minPoints / base)).rounded(.up))
        return base * pow(2, k)
    }

    static func project(_ c: Coord) -> (x: Double, y: Double) {
        let lat: Double = max(-85.0511, min(85.0511, c.lat)) * Double.pi / 180
        let x: Double = radius * c.lng * Double.pi / 180
        let y: Double = radius * log(tan(Double.pi / 4 + lat / 2))
        return (x, y)
    }

    static func unproject(_ x: Double, _ y: Double) -> CLLocationCoordinate2D {
        let angle: Double = 2 * atan(exp(y / radius)) - Double.pi / 2
        let latitude: Double = angle * 180 / Double.pi
        let longitude: Double = x / radius * 180 / Double.pi
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Axial coordinates of the pointy top hex containing a point.
    static func cell(of c: Coord, size: Double) -> Cell {
        let p = project(c)
        let q = (root3 / 3 * p.x - p.y / 3) / size
        let r = (2.0 / 3 * p.y) / size
        var rx = q.rounded()
        var rz = r.rounded()
        let ry = (-q - r).rounded()
        let dx = abs(rx - q)
        let dy = abs(ry + q + r)
        let dz = abs(rz - r)
        if dx > dy && dx > dz { rx = -ry - rz } else if dz >= dy { rz = -rx - ry }
        return Cell(q: Int(rx), r: Int(rz))
    }

    static func corners(_ cell: Cell, size: Double) -> [CLLocationCoordinate2D] {
        let cx = size * root3 * (Double(cell.q) + Double(cell.r) / 2)
        let cy = size * 1.5 * Double(cell.r)
        return (0..<6).map { i in
            let a = Double.pi / 180 * (60 * Double(i) - 30)
            return unproject(cx + size * cos(a), cy + size * sin(a))
        }
    }

    /// The distinct cells under a list of points.
    static func cells(_ points: [Coord], size: Double) -> [Cell] {
        var seen = Set<Cell>()
        var out: [Cell] = []
        for point in points {
            let c = cell(of: point, size: size)
            if seen.insert(c).inserted { out.append(c) }
        }
        return out
    }

    /// A Leaflet style zoom level for a span of longitude across a width in points.
    static func zoom(longitudeDelta: Double, width: Double) -> Double {
        guard longitudeDelta > 0, width > 0 else { return 14 }
        return log2(360 * width / (256 * longitudeDelta))
    }

    /// The coordinate box a zoom level shows around a center, for a view of this size.
    static func box(center: Coord, zoom: Double, width: Double, height: Double) -> (center: CLLocationCoordinate2D, lat: Double, lng: Double) {
        let perPoint = 40_075_016.686 / pow(2, zoom + 8)
        let p = project(center)
        let halfW = perPoint * width / 2
        let halfH = perPoint * height / 2
        let north = unproject(p.x, p.y + halfH)
        let south = unproject(p.x, p.y - halfH)
        let lng = min(359, halfW * 2 / radius * 180 / .pi)
        return (center.location, min(170, north.latitude - south.latitude), lng)
    }
}
