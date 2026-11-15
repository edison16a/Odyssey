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
//  HomeMapCanvas.swift, which only redraws when the scene changes.
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

    @State private var layer = HomeExploredLayer()
    /// What the map draws, rebuilt only when the zoom, region, layer or a pin changes.
    @State private var scene = HomeMapScene()
    @State private var revision = 0
    @State private var region: MKCoordinateRegion?
    @State private var width: CGFloat = 390

    /// Changes whenever something on the explored layer could look different.
    private var signature: String { HomeExploredLayer.signature(store) }

    /// Changes whenever a pin could look different or move.
    private var pinKey: String {
        let s = store.state
        let here = store.here
        return "\(s.visited.count)|\(s.checkins.count)|\(s.firsts.count)|\(s.starred.count)|\(store.osmPlaces.count)|"
            + "\(store.openBounties.count)|\(store.amenityPoints.count)|\(store.usingRealLocation)|\(Int(here.lat * 2000))|\(Int(here.lng * 2000))"
    }

    /// New footprints, a new zoom or a moved map rebuild the walked hexes.
    private var footKey: String {
        guard let c = region?.center else { return "\(store.state.footprints.count)" }
        return "\(store.state.footprints.count)-\(zoom)-\(Int(c.latitude * 2000))-\(Int(c.longitude * 2000))"
    }

    var body: some View {
        GeometryReader { geo in
            HomeMapCanvas(position: $position, scene: scene, revision: revision,
                          onCamera: cameraMoved, onPin: pick, onBounty: onBounty, onAmenity: pickAmenity)
                .equatable()
                .onAppear { width = geo.size.width }
                .onChange(of: geo.size.width) { _, value in width = value }
        }
        .task(id: signature) {
            layer = await HomeExploredLayer.load(store, key: signature)
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
        zoom = HomeMapZoom.level(for: next, width: width)
        commit { refreshLayer(&$0); refreshPins(&$0) }
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

    private func refreshLayer(_ scene: inout HomeMapScene) {
        scene.polygons = layer.polygons(zoom: zoom, region: region)
        scene.circles = layer.circles(zoom: zoom, region: region)
        scene.lines = layer.mapLines(zoom: zoom, region: region)
        scene.labels = layer.labels(zoom: zoom)
    }

    private func refreshPins(_ scene: inout HomeMapScene) {
        let box = region.map(HomeMapBox.init)
        var pins = HomeMapWorld.pins(store: store, box: box, zoom: zoom, filter: filter)
        // With amenities on, place names step back so the amenity labels read clearly.
        if !amenities.isEmpty { for i in pins.indices { pins[i].label = false } }
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
