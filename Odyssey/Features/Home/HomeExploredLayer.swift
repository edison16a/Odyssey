//
//  HomeExploredLayer.swift
//  Odyssey
//
//  The explored layer on the home map, worked out from the real shapes in
//  seed.exploredShapes (OpenStreetMap). Close in, the building or park of
//  every explored place fills blue, the streets around it light up and
//  small hexes fill the open ground between the roads; places nobody has
//  explored stay grey. Zoom out and the hexes grow, then whole cities fill
//  in, then states. Ported from the mockup's ui/explored-layer.js.
//

import Foundation

nonisolated struct HomeExploredLayer: Sendable {
    nonisolated enum Look: Sendable { case mine, explored, fog }

    nonisolated struct Fill: Identifiable, Sendable {
        var id: String
        var rings: [[Coord]]
        /// Places without an outline get a soft circle instead.
        var circle: (center: Coord, radius: Double)?
        var look: Look
    }

    nonisolated struct Line: Identifiable, Sendable {
        var id: String
        var coords: [Coord]
        var lit: Bool
    }

    nonisolated struct Region: Identifiable, Sendable {
        var id: String
        var name: String
        var rings: [[Coord]]
        var explored: Bool
        var labelAt: Coord
    }

    var fills: [Fill] = []
    var lines: [Line] = []
    var small: [HomeHexCell] = []
    var mid: [HomeHexCell] = []
    var large: [HomeHexCell] = []
    var cities: [Region] = []
    var states: [Region] = []

    // Which groups show at which zoom: the closer you are, the smaller the hexes.
    static func showStreet(_ z: Int) -> Bool { z >= 14 }
    static func showSmall(_ z: Int) -> Bool { z >= 15 }
    static func showMid(_ z: Int) -> Bool { z == 13 || z == 14 }
    static func showLarge(_ z: Int) -> Bool { z == 11 || z == 12 }
    static func showCity(_ z: Int) -> Bool { z >= 9 && z <= 12 }
    static func showState(_ z: Int) -> Bool { z <= 8 }

    /// The level the Street, City and State switch shows as active.
    static func level(_ z: Int) -> String {
        if z >= 13 { return "street" }
        if z >= 9 { return "city" }
        return "state"
    }

    /// What the layer needs from the store, copied so the heavy work can run off the main thread.
    nonisolated struct Inputs: Sendable {
        var data: ExploredShapes
        var rows: [(place: Place, status: PlaceStatus)]
        var saved: [Place]
        var trailCities: Set<String>
    }

    @MainActor private static var cache: (key: String, layer: HomeExploredLayer)?
    /// A build already under way, shared so the splash screen and the map never build twice.
    @MainActor private static var building: (key: String, task: Task<HomeExploredLayer, Never>)?

    /// Changes whenever something on the layer could look different.
    @MainActor
    static func signature(_ store: AppStore) -> String {
        "\(store.home.id)-\(store.state.visited.count)-\(store.state.savedPlaces.count)-\(store.state.firsts.count)"
    }

    /// Start building the layer early (during onboarding or at launch) so the map is ready when it appears.
    @MainActor
    static func prewarm(_ store: AppStore) {
        Task { _ = await load(store, key: signature(store)) }
    }

    /// True once the layer for this key is built and waiting.
    @MainActor
    static func isReady(_ key: String) -> Bool { cache?.key == key }

    /// The layer for the current state: from the cache when nothing changed, otherwise
    /// built on a background thread so the map and the rest of the app never freeze.
    @MainActor
    static func load(_ store: AppStore, key: String) async -> HomeExploredLayer {
        if let hit = cache, hit.key == key { return hit.layer }
        if let running = building, running.key == key { return await running.task.value }
        let data = store.seed.exploredShapes
        let rows: [(place: Place, status: PlaceStatus)] = store.seed.places
            .filter { data.shapes[$0.id] != nil }
            .map { (place: $0, status: store.status(of: $0).status) }
        let inputs = Inputs(data: data, rows: rows, saved: Array(store.state.savedPlaces.values),
                            trailCities: Set(store.seed.travel.trails.keys))
        let task = Task.detached(priority: .userInitiated) { compute(inputs) }
        building = (key, task)
        let layer = await task.value
        cache = (key, layer)
        if building?.key == key { building = nil }
        return layer
    }

    static func compute(_ inputs: Inputs) -> HomeExploredLayer {
        let data = inputs.data
        var layer = HomeExploredLayer()
        let rows = inputs.rows
        let known = rows.filter { $0.status != .new }.map { $0.place.coords }
        let rank: [PlaceStatus: Int] = [.mine: 3, .explored: 2, .new: 1]

        // Hexes, one source per place plus places checked in from Explore.
        var sources: [HomeHexSource] = rows.map { row in
            let shape = data.shapes[row.place.id]
            let roads = (shape?.streets ?? [:]).keys.compactMap { data.streets[$0]?.line }
            return HomeHexSource(coords: row.place.coords, rank: rank[row.status] ?? 1, roads: roads, skip: shape?.rings?.first)
        }
        sources += inputs.saved.map { HomeHexSource(coords: $0.coords, rank: 3) }
        layer.small = HomeHexGrid.cells(sources, size: 14, reach: 110, roads: 9)
        layer.mid = HomeHexGrid.cells(sources, size: 55, reach: 280, roads: 0)
        layer.large = HomeHexGrid.cells(sources, size: 220, reach: 800, roads: 0)

        // Streets: explored stretches blue, the rest of a new place's streets grey.
        var onRanges: [String: [[Double]]] = [:]
        var fogRanges: [String: [[Double]]] = [:]
        for row in rows {
            for (id, range) in data.shapes[row.place.id]?.streets ?? [:] {
                if row.status == .new { fogRanges[id, default: []].append(range) } else { onRanges[id, default: []].append(range) }
            }
        }
        for (id, street) in data.streets {
            let on = HomeGeo.merge(onRanges[id] ?? [])
            let fog = HomeGeo.subtract(HomeGeo.merge(fogRanges[id] ?? []), on)
            for (i, r) in fog.enumerated() {
                layer.lines.append(Line(id: "\(id)-f\(i)", coords: HomeGeo.slice(street.line, from: r[0], to: r[1]), lit: false))
            }
            for (i, r) in on.enumerated() {
                layer.lines.append(Line(id: "\(id)-o\(i)", coords: HomeGeo.slice(street.line, from: r[0], to: r[1]), lit: true))
            }
        }

        // Buildings and parks.
        for row in rows {
            guard let shape = data.shapes[row.place.id] else { continue }
            let look: Look = row.status == .new ? .fog : (row.status == .mine ? .mine : .explored)
            if shape.kind == "circle" || (shape.rings ?? []).isEmpty {
                layer.fills.append(Fill(id: row.place.id, rings: [], circle: (row.place.coords, 45), look: look))
            } else {
                layer.fills.append(Fill(id: row.place.id, rings: shape.rings ?? [], circle: nil, look: look))
            }
        }
        for place in inputs.saved {
            layer.fills.append(Fill(id: "saved-" + place.id, rings: [], circle: (place.coords, 30), look: .mine))
        }

        // Cities fill in when you explored something inside or walked a trail there; states follow their cities.
        func inside(_ rings: [[Coord]]) -> Bool {
            rings.contains { ring in known.contains { HomeGeo.contains(ring, $0) } }
        }
        func labelPoint(_ rings: [[Coord]]) -> Coord {
            let within = known.filter { pt in rings.contains { HomeGeo.contains($0, pt) } }
            return within.isEmpty ? HomeGeo.centroid(rings.first ?? []) : HomeGeo.centroid(within)
        }
        layer.cities = data.cities.map { city in
            let explored = inside(city.rings) || inputs.trailCities.contains(city.name)
            return Region(id: city.id, name: city.name, rings: city.rings, explored: explored, labelAt: labelPoint(city.rings))
        }
        let litCities = layer.cities.filter(\.explored)
        layer.states = data.states.map { state in
            let viaCity = litCities.contains { city in
                let middle = HomeGeo.centroid(city.rings.first ?? [])
                return state.rings.contains { HomeGeo.contains($0, middle) }
            }
            let explored = inside(state.rings) || viaCity
            return Region(id: state.id, name: state.name, rings: state.rings, explored: explored, labelAt: labelPoint(state.rings))
        }
        return layer
    }
}
