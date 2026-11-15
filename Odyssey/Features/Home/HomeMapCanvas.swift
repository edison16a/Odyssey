//
//  HomeMapCanvas.swift
//  Odyssey
//
//  The map itself, kept apart from the app state on purpose. Everything it
//  draws arrives as one plain scene with a revision number, and the view
//  only redraws when that number or the camera changes. Earning coins or
//  voting on a place used to make MapKit compare every shape and pin on the
//  map; now those changes never reach it.
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

struct HomeMapCanvas: View, Equatable {
    @Binding var position: MapCameraPosition
    var scene: HomeMapScene
    var revision: Int
    var onCamera: (MKCoordinateRegion) -> Void
    var onPin: (String) -> Void
    var onBounty: (Bounty) -> Void
    var onAmenity: (String) -> Void = { _ in }
    var onMapItem: (MKMapItem) -> Void = { _ in }
    @State private var selectedFeature: MapFeature?

    nonisolated static func == (a: HomeMapCanvas, b: HomeMapCanvas) -> Bool {
        MainActor.assumeIsolated { a.revision == b.revision && a.position == b.position }
    }

    var body: some View {
        Map(position: $position, selection: $selectedFeature) {
            ForEach(scene.polygons) { p in
                MapPolygon(coordinates: p.coords)
                    .foregroundStyle(p.fill)
                    .stroke(p.stroke, style: StrokeStyle(lineWidth: p.width, dash: p.dash))
            }
            ForEach(scene.footHexes) { hex in
                MapPolygon(coordinates: hex.coords)
                    .foregroundStyle(HomeMapStyle.blue.opacity(0.4))
                    .stroke(HomeMapStyle.blue.opacity(0.75), lineWidth: 0.6)
            }
            ForEach(scene.circles) { c in
                MapCircle(center: c.center, radius: c.radius)
                    .foregroundStyle(c.fill)
                    .stroke(c.stroke, style: StrokeStyle(lineWidth: c.width, dash: c.dash))
            }
            ForEach(scene.lines) { line in
                MapPolyline(coordinates: line.coords)
                    .stroke(line.color, style: StrokeStyle(lineWidth: line.width, lineCap: .round, lineJoin: .round, dash: line.dash))
            }
            ForEach(scene.labels) { label in
                Annotation(label.name, coordinate: label.labelAt.location, anchor: .center) {
                    HomeRegionPill(name: label.name, explored: label.explored)
                }
                .annotationTitles(.hidden)
            }
            BountyMapContent(bounties: scene.bounties, onPick: onBounty)
            ForEach(scene.pins) { pin in
                Annotation(pin.name, coordinate: pin.coord.location, anchor: .center) {
                    Button { onPin(pin.placeID) } label: {
                        HomePinView(pin: pin).frame(minWidth: 44, minHeight: 44)
                            .opacity(scene.dimsPins ? 0.4 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(pin.name)
                }
                .annotationTitles(.hidden)
            }
            ForEach(scene.amenities) { pin in
                Annotation(pin.name, coordinate: pin.coord.location, anchor: .center) {
                    Button { onAmenity(pin.id) } label: {
                        HomeAmenityPinView(pin: pin).frame(minWidth: 44, minHeight: 44)
                    }.buttonStyle(.plain).accessibilityLabel(pin.name)
                }
                .annotationTitles(.hidden)
            }
            if scene.showsUser {
                UserAnnotation()
                    .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .all))
        .task(id: selectedFeature) {
            guard let feature = selectedFeature else { return }
            let item: MKMapItem
            if let resolved = try? await MKMapItemRequest(feature: feature).mapItem {
                item = resolved
            } else {
                item = MKMapItem(placemark: MKPlacemark(coordinate: feature.coordinate))
                item.name = feature.title ?? "Selected location"
            }
            guard !Task.isCancelled else { return }
            selectedFeature = nil
            onMapItem(item)
        }
        .onMapCameraChange(frequency: .onEnd) { context in onCamera(context.region) }
    }
}
