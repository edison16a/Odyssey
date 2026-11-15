//
//  HomeMapCanvas.swift
//  Odyssey
//
//  The map itself, kept apart from the app state on purpose. Everything it
//  draws arrives as one plain scene with a revision number, and the map is
//  only touched when that number or the camera changes.
//
//  It sits on MKMapView directly rather than SwiftUI's Map. A close in view
//  holds a couple of thousand hexes, and SwiftUI's Map turns every one into
//  its own overlay with its own renderer, which is what made the map (and
//  everything scrolling past it) stutter. Here every shape that shares a
//  look is drawn together: a handful of overlays, however many hexes there
//  are. Pins are small cached pictures instead of live views.
//  The drawing and diffing lives in HomeMapEngine.swift.
//

import CoreLocation
import Foundation
import MapKit
import SwiftUI

/// A pin with everything worked out ahead, so drawing it never touches the store.
nonisolated struct HomePin: Identifiable, Equatable, Sendable {
    enum Kind: Sendable { case mine, new, explored, star }
    var id: String
    var placeID: String
    var name: String
    var coord: Coord
    var kind: Kind
    var glyph: String
    var pulses: Bool
    /// Show the place name next to the pin.
    var label = false
}

/// Everything on the map at one moment.
struct HomeMapScene {
    var polygons: [HomeMapPolygon] = []
    var footHexes: [HomeFootHex] = []
    var circles: [HomeMapCircle] = []
    var lines: [HomeMapLine] = []
    var labels: [HomeExploredLayer.Region] = []
    var bounties: [Bounty] = []
    var pins: [HomePin] = []
    /// Bathrooms, elevators, water and wifi, when their chips are on.
    var amenities: [HomeAmenityPin] = []
    /// Fade the place pins while amenities are showing, so those stand out.
    var dimsPins = false
    var showsUser = false
    var me = Coord(0, 0)
}

struct HomeMapCanvas: UIViewRepresentable, Equatable {
    var position: MapCameraPosition
    var scene: HomeMapScene
    var revision: Int
    var onCamera: (MKCoordinateRegion) -> Void
    var onPin: (String) -> Void
    var onBounty: (Bounty) -> Void
    var onAmenity: (String) -> Void = { _ in }

    nonisolated static func == (a: HomeMapCanvas, b: HomeMapCanvas) -> Bool {
        MainActor.assumeIsolated { a.revision == b.revision && a.position == b.position }
    }

    func makeCoordinator() -> HomeMapEngine { HomeMapEngine() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        let configuration = MKStandardMapConfiguration(elevationStyle: .realistic)
        configuration.pointOfInterestFilter = .excludingAll
        map.preferredConfiguration = configuration
        map.delegate = context.coordinator
        map.register(HomeMapMarkerView.self, forAnnotationViewWithReuseIdentifier: HomeMapMarkerView.reuseID)
        map.register(HomeMapMeView.self, forAnnotationViewWithReuseIdentifier: HomeMapMeView.reuseID)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let engine = context.coordinator
        engine.onCamera = onCamera
        engine.onPin = onPin
        engine.onBounty = onBounty
        engine.onAmenity = onAmenity
        if engine.position != position {
            engine.position = position
            engine.move(map, to: position)
        }
        if engine.revision != revision {
            engine.revision = revision
            engine.apply(scene, to: map)
        }
    }
}
