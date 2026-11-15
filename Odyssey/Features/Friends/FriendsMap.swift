//
//  FriendsMap.swift
//  Odyssey
//
//  Map of places friends explored. Each pin is the place photo with the
//  friend's face on it; tapping opens that friend's post. Only published
//  posts appear, never anyone's live location. The Friends tab shows a
//  still preview; the full screen version can be moved around.
//  Ported from friends-map.js.
//

import CoreLocation
import Foundation
import MapKit
import SwiftUI

/// The latest post at each place, with who posted it.
struct FriendsMapPin: Identifiable {
    var post: Post
    var place: Place
    var person: Person
    var id: String { place.id }

    static func all(_ store: AppStore) -> [FriendsMapPin] {
        var seen = Set<String>()
        var pins: [FriendsMapPin] = []
        for post in store.feed where !seen.contains(post.placeId) {
            guard let place = store.place(post.placeId), let person = store.person(post.by) else { continue }
            seen.insert(post.placeId)
            pins.append(FriendsMapPin(post: post, place: place, person: person))
        }
        return pins
    }

    /// A region that fits every pin with some room around it.
    static func region(_ pins: [FriendsMapPin], fallback: Coord) -> MKCoordinateRegion {
        guard !pins.isEmpty else {
            return MKCoordinateRegion(center: fallback.location, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
        }
        let lats = pins.map(\.place.coords.lat)
        let lngs = pins.map(\.place.coords.lng)
        let minLat = lats.min()!, maxLat = lats.max()!, minLng = lngs.min()!, maxLng = lngs.max()!
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max(0.008, (maxLat - minLat) * 1.5),
                                    longitudeDelta: max(0.008, (maxLng - minLng) * 1.5))
        return MKCoordinateRegion(center: center, span: span)
    }
}

/// The photo pin with the friend's face in the corner.
struct FriendsMapFace: View {
    var pin: FriendsMapPin
    var size: CGFloat = 44

    var body: some View {
        Group {
            if pin.post.by == "me" {
                UserPhotoView(file: pin.post.photoFile, fallback: pin.place.photo)
            } else {
                PlacePhoto(place: pin.place)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white, lineWidth: 2.5))
        .overlay(alignment: .bottomTrailing) {
            AvatarView(person: pin.person, size: 24, frame: "none")
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .offset(x: 7, y: 7)
        }
        .shadow(color: .black.opacity(0.22), radius: 6, y: 3)
        .padding(.trailing, 7)
        .padding(.bottom, 7)
    }
}

/// The still map on the Friends tab.
struct FriendsMapPreview: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let pins = FriendsMapPin.all(store)
        Map(initialPosition: .region(FriendsMapPin.region(pins, fallback: store.here)), interactionModes: []) {
            ForEach(pins) { pin in
                Annotation(pin.person.firstName, coordinate: pin.place.coords.location, anchor: .bottom) {
                    FriendsMapFace(pin: pin, size: 40)
                }
                .annotationTitles(.hidden)
            }
            Annotation("You", coordinate: store.here.location) { FriendsUserDot() }
                .annotationTitles(.hidden)
        }
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
        .allowsHitTesting(false)
    }
}

/// The full screen map, pushed from the Friends tab.
struct FriendsMapView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let pins = FriendsMapPin.all(store)
        VStack(spacing: 0) {
            NavHeader(title: "Where friends explored", back: { router.pop() })
            Map(initialPosition: .region(FriendsMapPin.region(pins, fallback: store.here))) {
                ForEach(pins) { pin in
                    Annotation(pin.person.firstName, coordinate: pin.place.coords.location, anchor: .bottom) {
                        Button {
                            router.present(.story(personID: pin.post.by, postID: pin.post.id))
                        } label: {
                            FriendsMapFace(pin: pin)
                        }
                        .buttonStyle(PressStyle(scale: 0.9))
                    }
                    .annotationTitles(.hidden)
                }
                Annotation("You", coordinate: store.here.location) { FriendsUserDot() }
                    .annotationTitles(.hidden)
            }
            .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
            .overlay(alignment: .bottom) {
                Text("Only places friends chose to share. Never anyone's live location.")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.white.opacity(0.95), in: Capsule())
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                    .padding(.bottom, 24)
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
