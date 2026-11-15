//
//  HomeGeo.swift
//  Odyssey
//
//  Geometry for the explored layer on the home map, ported from the
//  mockup's ui/geo.js and ui/hex-grid.js: point in polygon, ring centroids,
//  cutting a street into the stretches someone explored, and hex cells
//  around places on one shared grid per size so neighbours never overlap.
//

import CoreLocation
import Foundation

nonisolated enum HomeGeo {
    /// Ray casting point in polygon.
    static func contains(_ ring: [Coord], _ pt: Coord) -> Bool {
        guard ring.count > 2 else { return false }
        var inside = false
        var j = ring.count - 1
        for i in 0..<ring.count {
            let yi = ring[i].lat, xi = ring[i].lng
            let yj = ring[j].lat, xj = ring[j].lng
            if (yi > pt.lat) != (yj > pt.lat) && pt.lng < (xj - xi) * (pt.lat - yi) / (yj - yi) + xi {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    /// Average of a ring's points, good enough for placing a label.
    static func centroid(_ points: [Coord]) -> Coord {
        guard !points.isEmpty else { return Coord(0, 0) }
        let lat = points.reduce(0) { $0 + $1.lat } / Double(points.count)
        let lng = points.reduce(0) { $0 + $1.lng } / Double(points.count)
        return Coord(lat, lng)
    }

    /// Sort and join overlapping [from, to] ranges in metres.
    static func merge(_ ranges: [[Double]]) -> [[Double]] {
        var out: [[Double]] = []
        for range in ranges.filter({ $0.count == 2 }).sorted(by: { $0[0] < $1[0] }) {
            if let last = out.last, range[0] <= last[1] + 4 {
                out[out.count - 1][1] = max(last[1], range[1])
            } else {
                out.append(range)
            }
        }
        return out
    }

    /// Ranges in a that no range in b covers. Both should be merged.
    static func subtract(_ a: [[Double]], _ b: [[Double]]) -> [[Double]] {
        var out: [[Double]] = []
        for range in a {
            var start = range[0]
            let to = range[1]
            for cut in b where !(cut[1] <= start || cut[0] >= to) {
                if cut[0] > start { out.append([start, cut[0]]) }
                start = max(start, cut[1])
            }
            if start < to { out.append([start, to]) }
        }
        return out.filter { $0[1] - $0[0] > 6 }
    }

    /// The part of a polyline between two distances along it, in metres.
    static func slice(_ line: [Coord], from: Double, to: Double) -> [Coord] {
        var out: [Coord] = []
        var along = 0.0
        guard line.count > 1 else { return out }
        for i in 1..<line.count {
            let a = line[i - 1], b = line[i]
            let seg = a.distance(to: b)
            func at(_ s: Double) -> Coord {
                let t = seg > 0 ? min(1, max(0, (s - along) / seg)) : 0
                return Coord(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t)
            }
            if along + seg >= from && along <= to {
                if out.isEmpty { out.append(at(from)) }
                out.append(along + seg <= to ? b : at(to))
            }
            along += seg
            if along > to { break }
        }
        return out
    }
}

/// One hex on the explored layer. Rank 3 is yours, 2 explored by others, 1 nobody yet.
nonisolated struct HomeHexCell: Hashable, Sendable {
    var key: String
    var center: Coord
    var corners: [Coord]
    var rank: Int
}

/// Where hexes come from: a place, how explored it is, roads to keep clear and its own outline to skip.
nonisolated struct HomeHexSource: Sendable {
    var coords: Coord
    var rank: Int
    var roads: [[Coord]] = []
    var skip: [Coord]? = nil
}

nonisolated enum HomeHexGrid {
    private static let metresPerDegree = 111_320.0

    /// Distance in metres from a point to a segment, on a local flat projection.
    private static func toSegment(_ p: Coord, _ a: Coord, _ b: Coord, _ k: Double) -> Double {
        let ax = (a.lng - p.lng) * k, ay = a.lat - p.lat
        let bx = (b.lng - p.lng) * k, by = b.lat - p.lat
        let dx = bx - ax, dy = by - ay
        let len = dx * dx + dy * dy
        let t = len > 0 ? max(0, min(1, -(ax * dx + ay * dy) / len)) : 0
        return hypot(ax + t * dx, ay + t * dy) * metresPerDegree
    }

    private static func nearRoad(_ pt: Coord, _ lines: [[Coord]], _ clear: Double, _ k: Double) -> Bool {
        for line in lines where line.count > 1 {
            for i in 1..<line.count where toSegment(pt, line[i - 1], line[i], k) < clear { return true }
        }
        return false
    }

    /// Hex cells of radius size metres reaching reach metres around each source.
    static func cells(_ sources: [HomeHexSource], size: Double, reach: Double, roads: Double) -> [HomeHexCell] {
        guard let origin = sources.first?.coords else { return [] }
        let lat0 = origin.lat, lng0 = origin.lng
        let k = cos(lat0 * .pi / 180)
        let s = size / metresPerDegree
        let sq3 = 3.0.squareRoot()
        var grid: [String: (center: Coord, rank: Int)] = [:]
        func centerOf(_ q: Int, _ r: Int) -> Coord {
            Coord(lat0 + Double(r) * 1.5 * s, lng0 + sq3 * s * (Double(q) + Double(r) / 2) / k)
        }
        let span = Int((reach / size).rounded(.up)) + 1
        for src in sources {
            let r0 = Int(((src.coords.lat - lat0) / (1.5 * s)).rounded())
            let q0 = Int(((src.coords.lng * k - lng0 * k) / (sq3 * s) - Double(r0) / 2).rounded())
            for dr in -span...span {
                for dq in -span...span {
                    let q = q0 + dq, r = r0 + dr
                    let c = centerOf(q, r)
                    let dist = hypot(c.lat - src.coords.lat, (c.lng - src.coords.lng) * k) * metresPerDegree
                    if dist > reach { continue }
                    let key = "\(q),\(r)"
                    if let prev = grid[key], prev.rank >= src.rank { continue }
                    if roads > 0 && nearRoad(c, src.roads, roads, k) { continue }
                    if let skip = src.skip, HomeGeo.contains(skip, c) { continue }
                    grid[key] = (c, src.rank)
                }
            }
        }
        return grid.map { key, cell in
            let corners = (0..<6).map { i -> Coord in
                let a = Double.pi / 180 * (60 * Double(i) - 30)
                return Coord(cell.center.lat + s * 0.94 * sin(a), cell.center.lng + s * 0.94 * cos(a) / k)
            }
            return HomeHexCell(key: key, center: cell.center, corners: corners, rank: cell.rank)
        }
    }
}
