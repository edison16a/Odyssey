//
//  Footprints.swift
//  Odyssey
//
//  Wherever you walk counts as explored. Your real path is kept as points
//  about 15 m apart, and every hex of a fixed world grid it passes through
//  (plus the ones right beside it) turns blue on the map, the same idea as
//  a footprints map. Exploring is free; a place only becomes yours when you
//  check in there with a photo.
//
//  The grid is anchored to the globe, so the same street always lands in
//  the same hexes, wherever in the world you are.
//

import Foundation

/// One hex of the world grid.
nonisolated struct FootCell: Hashable, Sendable {
    /// One degree latitude band, so the east to west scale stays true.
    var band: Int
    var q: Int
    var r: Int
}

nonisolated enum FootGrid {
    /// Hex radius in metres.
    static let size = 22.0
    private static let metresPerDegree = 111_320.0
    private static let sqrt3 = 3.0.squareRoot()

    private static func scale(_ band: Int) -> Double { cos(Double(band) * .pi / 180) }

    static func cell(for c: Coord, size: Double = FootGrid.size) -> FootCell {
        let band = Int(c.lat.rounded())
        let x = c.lng * metresPerDegree * scale(band)
        let y = c.lat * metresPerDegree
        let fq = (sqrt3 / 3 * x - y / 3) / size
        let fr = (2.0 / 3 * y) / size
        // Cube rounding to the nearest hex.
        let fs = -fq - fr
        var q = fq.rounded(), r = fr.rounded()
        let s = fs.rounded()
        let dq = abs(q - fq), dr = abs(r - fr), ds = abs(s - fs)
        if dq > dr && dq > ds { q = -r - s } else if dr > ds { r = -q - s }
        return FootCell(band: band, q: Int(q), r: Int(r))
    }

    static func center(_ cell: FootCell, size: Double = FootGrid.size) -> Coord {
        let x = size * sqrt3 * (Double(cell.q) + Double(cell.r) / 2)
        let y = size * 1.5 * Double(cell.r)
        return Coord(y / metresPerDegree, x / (metresPerDegree * scale(cell.band)))
    }

    static func corners(_ cell: FootCell, size: Double = FootGrid.size) -> [Coord] {
        let c = center(cell, size: size)
        let k = scale(cell.band)
        return (0..<6).map { i in
            let a = Double.pi / 180 * (60 * Double(i) - 30)
            return Coord(c.lat + size * 0.96 * sin(a) / metresPerDegree,
                         c.lng + size * 0.96 * cos(a) / (metresPerDegree * k))
        }
    }

    private static let neighbours = [(1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)]

    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: (count: Int, last: Coord?, cells: Set<FootCell>)?

    /// The hexes for a path, worked out once per batch of new points. Safe from any thread,
    /// so the map can build its overlay in the background.
    static func cachedCells(_ points: [Coord]) -> Set<FootCell> {
        lock.lock()
        if let hit = cache, hit.count == points.count, hit.last == points.last {
            lock.unlock()
            return hit.cells
        }
        lock.unlock()
        let cells = cells(along: points)
        lock.lock()
        cache = (points.count, points.last, cells)
        lock.unlock()
        return cells
    }

    /// Every hex your path touches, with the ring around it so the trail reads as a band.
    static func cells(along points: [Coord]) -> Set<FootCell> {
        var out = Set<FootCell>()
        func mark(_ p: Coord) {
            let c = cell(for: p)
            out.insert(c)
            for (dq, dr) in neighbours { out.insert(FootCell(band: c.band, q: c.q + dq, r: c.r + dr)) }
        }
        for (i, p) in points.enumerated() {
            mark(p)
            guard i + 1 < points.count else { continue }
            let next = points[i + 1]
            let gap = p.distance(to: next)
            // Fill short gaps so a quick walk still draws a continuous trail; skip jumps.
            guard gap > size, gap < 400 else { continue }
            let steps = Int(gap / size)
            for k in 1..<max(2, steps) {
                let f = Double(k) / Double(steps)
                mark(Coord(p.lat + (next.lat - p.lat) * f, p.lng + (next.lng - p.lng) * f))
            }
        }
        return out
    }
}

extension AppStore {
    /// Add newly walked points. Points closer than 15 m to the last one are dropped,
    /// and walked distance (not drives or GPS jumps) is added to your kilometres.
    func recordFootprints(_ points: [Coord]) {
        guard !points.isEmpty else { return }
        var added: [Coord] = []
        var metres = 0.0
        var last = state.footprints.last
        for point in points {
            if let prev = last {
                let gap = prev.distance(to: point)
                if gap < 15 { continue }
                if gap < 400 { metres += gap }
            }
            added.append(point)
            last = point
        }
        guard !added.isEmpty else { return }
        update { s in
            s.footprints += added
            if s.footprints.count > 40_000 { s.footprints.removeFirst(s.footprints.count - 40_000) }
            s.stats.km += metres / 1000
        }
    }

    /// The explored hexes, worked out once per batch of new footprints.
    var footprintCells: Set<FootCell> { FootGrid.cachedCells(state.footprints) }

    /// Roughly how much ground you have walked, in square kilometres.
    var footprintArea: Double {
        Double(footprintCells.count) * 1.5 * 3.0.squareRoot() * FootGrid.size * FootGrid.size / 1_000_000
    }

    /// True when you have walked within a stone's throw of a place.
    func walkedPast(_ place: Place) -> Bool {
        footprintCells.contains(FootGrid.cell(for: place.coords))
    }

    /// Friends who explored a place before you, the most regular first.
    func friendsWhoVisited(_ place: Place) -> [Person] {
        var ids = topExplorers(place).map(\.id)
        if let first = firstExplorer(place)?.by, first != "me", !ids.contains(first) { ids.insert(first, at: 0) }
        return ids.filter { isFriend($0) }.compactMap { person($0) }
    }
}
