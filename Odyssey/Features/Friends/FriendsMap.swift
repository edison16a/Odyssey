//
//  FriendsMap.swift
//  Odyssey
//
//  Where your friends explored, drawn as hexagons. Every friend has their
//  own color and each place they explored fills the hex around it. A row
//  of faces under the map doubles as the legend: tap one to show just that
//  friend. Only places friends explored, never anyone's live location.
//

import CoreLocation
import Foundation
import MapKit
import SwiftUI

/// The hex map itself, used on the Friends tab, full screen and on a profile.
struct FriendsHexMap: View {
    @Environment(AppStore.self) private var store
    /// Whose places to draw.
    var ids: [String]
    /// Show only this person, or everyone when nil.
    var focus: String? = nil
    var interactive = false

    @State private var position: MapCameraPosition = .automatic
    @State private var size: Double = TravelHexGrid.base * 2

    var body: some View {
        let shown = focus.map { [$0] } ?? ids
        GeometryReader { geo in
            Map(position: $position, interactionModes: interactive ? .all : []) {
                ForEach(store.friendHexes(shown, size: size)) { hex in
                    MapPolygon(coordinates: hex.corners)
                        .foregroundStyle(hex.color.opacity(0.55))
                        .stroke(hex.color, lineWidth: 1.5)
                }
                Annotation("You", coordinate: store.here.location) { FriendsUserDot() }
                    .annotationTitles(.hidden)
            }
            .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
            .onMapCameraChange(frequency: .onEnd) { context in
                size = friendsHexSize(longitudeDelta: context.region.span.longitudeDelta, width: geo.size.width)
            }
            .onAppear { fit(shown, width: geo.size.width) }
            .onChange(of: focus) { _, _ in
                withAnimation(.easeInOut(duration: 0.4)) { fit(focus.map { [$0] } ?? ids, width: geo.size.width) }
            }
        }
    }

    private func fit(_ shown: [String], width: Double) {
        let region = store.friendsRegion(shown)
        size = friendsHexSize(longitudeDelta: region.span.longitudeDelta, width: max(width, 1))
        position = .region(region)
    }
}

/// Faces with their color, for picking whose places the map shows.
struct FriendsLegend: View {
    @Environment(AppStore.self) private var store
    var people: [Person]
    @Binding var focus: String?
    var padding: CGFloat = Space.s5

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s2) {
                chip(nil)
                ForEach(people) { chip($0) }
            }
            .padding(.horizontal, padding)
            .padding(.vertical, 2)
        }
    }

    private func chip(_ person: Person?) -> some View {
        let on = focus == person?.id
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { focus = on ? nil : person?.id }
        } label: {
            HStack(spacing: 6) {
                if let person {
                    AvatarView(person: person, size: 24, frame: "none")
                    Circle().fill(store.friendColor(person.id)).frame(width: 10, height: 10)
                    Text(person.firstName)
                } else {
                    Text("Everyone")
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(on ? .white : Palette.ink)
            .padding(.leading, person == nil ? 14 : 4)
            .padding(.trailing, 12)
            .frame(height: 34)
            .background(on ? Palette.ink : Palette.surface2, in: Capsule())
        }
        .buttonStyle(PressStyle(scale: 0.95))
    }
}

/// The full screen map, pushed from the Friends tab.
struct FriendsMapView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var focus: String?

    var body: some View {
        let friends = store.friends
        VStack(spacing: 0) {
            NavHeader(title: "Where friends explored", back: { router.pop() })
            FriendsHexMap(ids: friends.map(\.id), focus: focus, interactive: true)
                .overlay(alignment: .bottom) {
                    VStack(spacing: Space.s2) {
                        if let id = focus, let person = store.person(id) {
                            Button { router.push(.person(id)) } label: {
                                Text("\(store.exploredPlaces(of: id).count) places by \(person.firstName)  ·  View profile")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(.white.opacity(0.95), in: Capsule())
                            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                        }
                        FriendsLegend(people: friends, focus: $focus)
                            .padding(.vertical, Space.s2)
                            .background(.white.opacity(0.95))
                    }
                }
        }
        .background(Palette.surface)
    }
}

/// Your own position: a blue dot with a white edge.
private struct FriendsUserDot: View {
    var body: some View {
        Circle()
            .fill(Palette.accent)
            .frame(width: 14, height: 14)
            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
            .shadow(color: Palette.accent.opacity(0.4), radius: 6)
    }
}
