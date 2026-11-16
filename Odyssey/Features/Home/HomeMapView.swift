//
//  HomeMapView.swift
//  Odyssey
//
//  The home map. The explored layer fills real buildings, streets, cities
//  and states blue where explorers have been and leaves the rest grey. On
//  top sits a pin per place, styled by whether you explored it, it is new
//  to Odyssey, or others have been, plus any business bounty areas. Tapping
//  a pin opens the place preview; tapping a bounty opens its sheet. Your
//  walked hexes and the world's places come from HomeMapWorld.swift, and
//  places you starred get a gold pin on top. The drawing itself lives in
//  HomeMapCanvas.swift and HomeMapEngine.swift, which only touch the map
//  when the scene changes.
//  Ported from features/home/home-map.js.
//

import Foundation
import MapKit
import SwiftUI

struct HomeMapView: View {
    @Environment(AppStore.self) private var store
    @Binding var position: MapCameraPosition
    @Binding var zoom: Int
    var filter: String
    var onPick: (Place) -> Void
    var onBounty: (Bounty) -> Void = { _ in }
    /// Amenity kinds switched on over the map ("bathroom", "elevator", "water", "wifi").
    var amenities: Set<String> = []
    var onAmenity: (AmenityPoint) -> Void = { _ in }

    var destinations: [Place] = []
    var selectedDestination: Place?
    /// Points below the top safe area for the compass, when controls cover the usual corner.
    var compassTop: CGFloat? = nil
    var onCamera: (MKCoordinateRegion) -> Void = { _ in }

    @State private var layer = HomeExploredLayer()
    /// What the map draws, rebuilt only when the zoom, region, layer or a pin changes.
    @State private var scene = HomeMapScene()
    @State private var revision = 0
    @State private var region: MKCoordinateRegion?
    /// The region and zoom the explored shapes were last cut to. They reach well past the
    /// screen, so a small pan keeps the same shapes and the map has nothing to redraw.
    @State private var layerRegion: MKCoordinateRegion?
    @State private var layerZoom: Int?
    @State private var width: CGFloat = 390

    /// Changes whenever something on the explored layer could look different.
    private var signature: String { HomeExploredLayer.signature(store) }

    /// Changes whenever a pin could look different or move.
    private var pinKey: String {
        let s = store.state
        let here = store.here
        return "\(s.visited.count)|\(s.checkins.count)|\(s.firsts.count)|\(s.starred.count)|\(store.osmPlaces.count)|"
            + "\(store.openBounties.count)|\(store.bountyRevision)|\(store.amenityPoints.count)|\(store.usingRealLocation)|\(Int(here.lat * 2000))|\(Int(here.lng * 2000))"
    }

    /// New footprints, a new zoom or a moved map rebuild the walked hexes.
    private var footKey: String {
        let walked = "\(store.footprintsRevision)-\(store.state.footprints.count)"
        guard let c = region?.center else { return walked }
        return "\(walked)-\(zoom)-\(Int(c.latitude * 2000))-\(Int(c.longitude * 2000))"
    }

    var body: some View {
        GeometryReader { geo in
            HomeMapCanvas(position: position, scene: scene, revision: revision, compassTop: compassTop,
                          onCamera: cameraMoved, onPin: pick, onBounty: onBounty, onAmenity: pickAmenity,
                          onMapItem: { onPick(LocationSearch.register($0, store: store)) },
                          onUserMove: { position = $0 })
                .equatable()
                .onAppear { width = geo.size.width }
                .onChange(of: geo.size.width) { _, value in width = value }
        }
        .task(id: signature) {
            layer = await HomeExploredLayer.load(store, key: signature)
            // Before the map reports where it is looking there is nothing to cut the shapes
            // to; the first camera report draws them instead of drawing every city at once.
            guard region != nil else { return }
            layerRegion = region
            layerZoom = zoom
            commit { refreshLayer(&$0); refreshPins(&$0) }
        }
        .task(id: footKey) {
            guard HomeMapWorld.showsFootprints(zoom), let region else {
                if !scene.footHexes.isEmpty { commit { $0.footHexes = [] } }
                return
            }
            let hexes = await HomeMapWorld.hexes(points: store.state.footprints, box: HomeMapBox(region), zoom: zoom)
            commit { $0.footHexes = hexes }
        }
        .task { await WorldPlaces.load(around: store.here, store: store) }
        .onChange(of: destinations) { commit(refreshPins) }
        .onChange(of: selectedDestination) { commit(refreshPins) }
        .onChange(of: pinKey) { commit(refreshPins) }
        .onChange(of: filter) { commit(refreshPins) }
        .onChange(of: amenities) { commit(refreshPins) }
    }

    /// Apply a change to the scene and let the map redraw once.
    private func commit(_ change: (inout HomeMapScene) -> Void) {
        change(&scene)
        revision += 1
    }

    private func cameraMoved(_ next: MKCoordinateRegion) {
        region = next
        onCamera(next)
        zoom = HomeMapZoom.level(for: next, width: width)
        let recut = layerZoom != zoom || !Self.covers(layerRegion, next)
        if recut {
            layerRegion = next
            layerZoom = zoom
        }
        commit {
            if recut { refreshLayer(&$0) }
            refreshPins(&$0)
        }
        if zoom >= 14 {
            let center = Coord(next.center)
            Task { await WorldPlaces.load(around: center, store: store) }
        }
    }

    private func pick(_ placeID: String) {
        if let place = store.place(placeID) { onPick(place) }
    }

    private func pickAmenity(_ id: String) {
        if let point = store.amenityPoints.first(where: { $0.id == id }) { onAmenity(point) }
    }

    /// True while the screen still sits inside the area the shapes were cut to (the old
    /// region grown by half on every side), leaving a margin so no edge shows.
    private static func covers(_ old: MKCoordinateRegion?, _ next: MKCoordinateRegion) -> Bool {
        guard let old else { return false }
        guard next.span.latitudeDelta <= old.span.latitudeDelta * 1.25,
              next.span.longitudeDelta <= old.span.longitudeDelta * 1.25 else { return false }
        let dLat = abs(next.center.latitude - old.center.latitude) + next.span.latitudeDelta / 2
        let dLng = abs(next.center.longitude - old.center.longitude) + next.span.longitudeDelta / 2
        return dLat <= old.span.latitudeDelta * 0.85 && dLng <= old.span.longitudeDelta * 0.85
    }

    private func refreshLayer(_ scene: inout HomeMapScene) {
        scene.polygons = layer.polygons(zoom: zoom, region: layerRegion)
        scene.circles = layer.circles(zoom: zoom, region: layerRegion)
        scene.lines = layer.mapLines(zoom: zoom, region: layerRegion)
        scene.labels = layer.labels(zoom: zoom)
    }

    private func refreshPins(_ scene: inout HomeMapScene) {
        let box = region.map(HomeMapBox.init)
        var pins = HomeMapWorld.pins(store: store, box: box, zoom: zoom, filter: filter)
        // With amenities on, place names step back so the amenity labels read clearly.
        if !amenities.isEmpty { for i in pins.indices { pins[i].label = false } }
        let highlighted = destinations + (selectedDestination.map { [$0] } ?? [])
        let ids = Set(highlighted.map(\.id))
        pins.removeAll { ids.contains($0.placeID) }
        var seen: Set<String> = []
        for place in highlighted where seen.insert(place.id).inserted {
            pins.append(HomePin(id: place.id, placeID: place.id, name: place.name, coord: place.coords,
                                kind: .destination, glyph: "mappin", pulses: false, label: true))
        }
        scene.pins = pins
        scene.amenities = HomeMapWorld.amenityPins(store: store, box: box, zoom: zoom, kinds: amenities)
        scene.dimsPins = !amenities.isEmpty && !scene.amenities.isEmpty
        scene.bounties = zoom >= 13 ? store.openBounties : []
        scene.showsUser = store.usingRealLocation
        scene.me = store.here
    }
}

/// Leaflet style zoom levels from a MapKit region, so the mockup's rules carry over.
enum HomeMapZoom {
    static func level(for region: MKCoordinateRegion, width: CGFloat) -> Int {
        let span = region.span.longitudeDelta
        let delta = span.isFinite ? max(span, 0.000_01) : 0.000_01
        // A zero width (mid layout) would make log2 return infinity, which Int() traps on.
        let level = log2(360 * Double(max(width, 1)) / (256 * delta)).rounded()
        return level.isFinite ? Int(level) : 15
    }

    static func region(center: Coord, zoom: Int, width: CGFloat = 390) -> MKCoordinateRegion {
        let lngDelta = 360 * Double(width) / (256 * pow(2, Double(zoom)))
        return MKCoordinateRegion(center: center.location,
                                  span: MKCoordinateSpan(latitudeDelta: lngDelta * 0.9, longitudeDelta: lngDelta))
    }
}
