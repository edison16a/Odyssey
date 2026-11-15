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
    enum Kind: Sendable { case mine, new, explored, star }
    var id: String
    var placeID: String
    var name: String
    var coord: Coord
    var kind: Kind
    var glyph: String
    var pulses: Bool
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

    nonisolated static func == (a: HomeMapCanvas, b: HomeMapCanvas) -> Bool {
        MainActor.assumeIsolated { a.revision == b.revision && a.position == b.position }
    }

    var body: some View {
        Map(position: $position) {
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
                Annotation(pin.name, coordinate: pin.coord.location, anchor: pin.kind == .star ? .bottom : .center) {
                    HomePinView(pin: pin)
                        .onTapGesture { onPin(pin.placeID) }
                }
                .annotationTitles(.hidden)
            }
            if scene.showsUser {
                UserAnnotation()
                    .annotationTitles(.hidden)
            } else {
                Annotation("You", coordinate: scene.me.location, anchor: .center) { HomeMeDot() }
                    .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .onMapCameraChange(frequency: .onEnd) { context in onCamera(context.region) }
    }
}
