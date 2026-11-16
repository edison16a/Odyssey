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
    enum Kind: Sendable { case mine, new, explored, star, destination }
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
    /// Move the compass this far below the top safe area (nil keeps MapKit's spot).
    var compassTop: CGFloat? = nil
    var onCamera: (MKCoordinateRegion) -> Void
    var onPin: (String) -> Void
    var onBounty: (Bounty) -> Void
    var onAmenity: (String) -> Void = { _ in }
    /// A shop, park or landmark of Apple's own map was tapped.
    var onMapItem: (MKMapItem) -> Void = { _ in }
    /// You moved the map by hand; the new camera goes back to whoever owns the position.
    var onUserMove: (MapCameraPosition) -> Void = { _ in }

    nonisolated static func == (a: HomeMapCanvas, b: HomeMapCanvas) -> Bool {
        MainActor.assumeIsolated { a.revision == b.revision && a.position == b.position }
    }

    func makeCoordinator() -> HomeMapEngine { HomeMapEngine() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        let configuration = MKStandardMapConfiguration(elevationStyle: .realistic)
        configuration.pointOfInterestFilter = .includingAll
        map.preferredConfiguration = configuration
        map.selectableMapFeatures = [.pointsOfInterest, .physicalFeatures, .territories]
        map.delegate = context.coordinator
        // The location dot takes the map's tint; keep it Odyssey blue, not the app's ink.
        map.tintColor = UIColor(Palette.accent)
        map.register(HomeMapMarkerView.self, forAnnotationViewWithReuseIdentifier: HomeMapMarkerView.reuseID)
        if let compassTop {
            // The search bar covers MapKit's compass corner, so show our own one lower down.
            map.showsCompass = false
            let compass = MKCompassButton(mapView: map)
            compass.compassVisibility = .adaptive
            compass.translatesAutoresizingMaskIntoConstraints = false
            map.addSubview(compass)
            NSLayoutConstraint.activate([
                compass.topAnchor.constraint(equalTo: map.safeAreaLayoutGuide.topAnchor, constant: compassTop),
                compass.trailingAnchor.constraint(equalTo: map.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            ])
        }
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let engine = context.coordinator
        engine.onCamera = onCamera
        engine.onPin = onPin
        engine.onBounty = onBounty
        engine.onAmenity = onAmenity
        engine.onMapItem = onMapItem
        engine.onUserMove = onUserMove
        if engine.position != position {
            engine.position = position
            // A position another map reported from a hand move is not an order to follow it.
            if position != HomeMapEngine.movedByHand {
                engine.move(map, to: position, animated: context.transaction.animation != nil)
            }
        }
        if engine.revision != revision {
            engine.revision = revision
            engine.apply(scene, to: map)
        }
    }
}
