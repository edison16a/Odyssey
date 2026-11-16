import MapKit
import Observation
import SwiftUI

/// Camera, phone position, selected destination and bounty target are deliberately independent.
@Observable
final class WorldMapState {
    var position: MapCameraPosition = .automatic
    var zoom = 14
    var region: MKCoordinateRegion?
    var selectedPlace: Place?
    var bountyTarget: Place?
    var results: [Place] = []
    var amenityKinds: Set<String> = []
    var nearbyTitle: String?
    var search = LocationSearch()
    private var initialized = false

    func initialize(store: AppStore) {
        guard !initialized else { return }
        initialized = true
        fly(to: store.demoFocus ?? store.deviceLocation ?? store.home.center)
    }

    func fly(to coord: Coord, distance: Double = 1500) {
        withAnimation(.easeInOut(duration: 0.7)) {
            position = .camera(MapCamera(centerCoordinate: coord.location, distance: distance, heading: 20, pitch: 55))
        }
    }

    func select(_ place: Place) {
        selectedPlace = place
        fly(to: place.coords)
    }

    /// Frame every coordinate. `bottomRoom` adds empty map below (as a share of the height)
    /// so a panel over the bottom of the map doesn't cover any of them.
    func fit(_ coords: [Coord], bottomRoom: Double = 0) {
        guard let first = coords.first else { return }
        var rect = MKMapRect(origin: MKMapPoint(first.location), size: MKMapSize(width: 1, height: 1))
        for coord in coords { rect = rect.union(MKMapRect(origin: MKMapPoint(coord.location), size: MKMapSize(width: 1, height: 1))) }
        let padding = max(800, max(rect.width, rect.height) * 0.25)
        rect.size.height += (rect.height + padding * 2) * bottomRoom
        withAnimation { position = .rect(rect.insetBy(dx: -padding, dy: -padding)) }
    }

    func clearNearby() {
        results = []
        amenityKinds = []
        nearbyTitle = nil
    }
}
