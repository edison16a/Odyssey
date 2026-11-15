//
//  HomeAmenities.swift
//  Odyssey
//
//  The amenity layer of the home map: public bathrooms, elevators, water
//  fountains and free wifi. A row of chips over the map turns each kind
//  on, and the nearest few dozen in view become small coloured pins.
//  Tapping one opens a short sheet with how far it is, who can use it and
//  a Directions button. Pins are worked out ahead into the map scene, so
//  they follow the same one-redraw-per-change rule as the place pins.
//

import CoreLocation
import Foundation
import MapKit
import SwiftUI

/// A ready to draw amenity pin, so drawing it never touches the store.
nonisolated struct HomeAmenityPin: Identifiable, Equatable, Sendable {
    var id: String
    var kind: String
    var name: String
    var coord: Coord
    var icon: String
    var label: Bool
}

/// Names, colours and order of the amenity kinds.
enum AmenityStyle {
    static let kinds = ["bathroom", "elevator", "water", "wifi"]

    static func title(_ kind: String) -> String {
        switch kind {
        case "bathroom": return "Bathrooms"
        case "elevator": return "Elevators"
        case "water": return "Water"
        default: return "Wifi"
        }
    }

    static func single(_ kind: String) -> String {
        switch kind {
        case "bathroom": return "Public bathroom"
        case "elevator": return "Elevator"
        case "water": return "Water fountain"
        default: return "Free wifi"
        }
    }

    static func icon(_ kind: String) -> String {
        switch kind {
        case "bathroom": return "toilet.fill"
        case "elevator": return "arrow.up.arrow.down.square.fill"
        case "water": return "drop.fill"
        default: return "wifi"
        }
    }

    static func color(_ kind: String) -> Color {
        switch kind {
        case "bathroom": return Color(hex: "#0e9f9a")
        case "elevator": return Color(hex: "#7c4dff")
        case "water": return Color(hex: "#1e88e5")
        default: return Color(hex: "#ef7d00")
        }
    }

    static func soft(_ kind: String) -> Color { color(kind).opacity(0.12) }
}

extension HomeMapWorld {
    /// The nearest amenities of the chosen kinds in view, capped so MapKit stays smooth.
    @MainActor
    static func amenityPins(store: AppStore, box: HomeMapBox?, zoom: Int, kinds: Set<String>) -> [HomeAmenityPin] {
        guard !kinds.isEmpty, zoom >= 11 else { return [] }
        let center = box?.center ?? store.here
        let inView = store.amenityPoints.filter { kinds.contains($0.kind) && (box?.contains($0.coord) ?? true) }
        let nearest = inView
            .map { ($0, $0.coord.distance(to: center)) }
            .sorted { $0.1 < $1.1 }
            .prefix(40)
        return nearest.enumerated().map { index, item in
            let point = item.0
            // Names at street level, or for the closest few a little further out.
            let label = zoom >= 17 || (zoom >= 15 && index < 6)
            return HomeAmenityPin(id: point.id, kind: point.kind, name: point.name, coord: point.coord,
                                  icon: point.icon, label: label)
        }
    }

    /// The closest amenity of a kind to where you are.
    @MainActor
    static func nearest(_ kind: String, store: AppStore) -> AmenityPoint? {
        let here = store.here
        return store.amenityPoints.filter { $0.kind == kind }.min { $0.coord.distance(to: here) < $1.coord.distance(to: here) }
    }
}

/// A small round amenity pin with an optional name beside it.
struct HomeAmenityPinView: View {
    var pin: HomeAmenityPin

    var body: some View {
        let color = AmenityStyle.color(pin.kind)
        Image(systemName: pin.icon)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(color, in: Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            .shadow(color: color.opacity(0.45), radius: 3, y: 1)
            .frame(width: 30, height: 30)
            .contentShape(Circle())
            .overlay(alignment: .leading) {
                if pin.label {
                    Text(pin.name)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .frame(width: 120, alignment: .leading)
                        .shadow(color: .white, radius: 0, x: 1, y: 1)
                        .shadow(color: .white, radius: 0, x: -1, y: -1)
                        .shadow(color: .white, radius: 1.5)
                        .offset(x: 30)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityLabel(pin.name)
    }
}

/// The toggle chips over the map: one per amenity kind.
struct HomeAmenityChips: View {
    @Binding var kinds: Set<String>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(AmenityStyle.kinds, id: \.self) { kind in
                    chip(kind)
                }
            }
            .padding(.horizontal, 10)
        }
    }

    private func chip(_ kind: String) -> some View {
        let on = kinds.contains(kind)
        let color = AmenityStyle.color(kind)
        return Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                if on { kinds.remove(kind) } else { kinds.insert(kind) }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: AmenityStyle.icon(kind)).font(.system(size: 11, weight: .bold))
                Text(AmenityStyle.title(kind)).font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(on ? .white : Palette.ink)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(on ? color : .white.opacity(0.94), in: Capsule())
            .overlay(Capsule().strokeBorder(on ? .clear : Palette.line))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
        .buttonStyle(PressStyle(scale: 0.94))
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// The sheet for a tapped amenity: what it is, who can use it, how far, and directions.
struct AmenitySheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var point: AmenityPoint

    var body: some View {
        let meters = store.here.distance(to: point.coord)
        let color = AmenityStyle.color(point.kind)
        let isPublic = point.access != "customers"
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: point.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(AmenityStyle.single(point.kind).uppercased())
                        .font(.system(size: 11, weight: .heavy)).tracking(0.6).foregroundStyle(color)
                    Text(point.name).font(.system(size: 20, weight: .bold)).tracking(-0.3)
                        .foregroundStyle(Palette.ink).lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 6) {
                accessTag(isPublic)
                Tag(text: Format.distance(meters), icon: "mappin.and.ellipse")
                Tag(text: Format.walkTime(meters), icon: "figure.walk")
            }
            if !point.note.isEmpty {
                Text(point.note)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .softCard(padding: 12, radius: Radius.md)
            }
            if let id = point.placeID, let place = store.place(id) {
                HStack(spacing: 6) {
                    Image(systemName: "building.2").font(.system(size: 12, weight: .semibold))
                    Text("Inside \(place.name)").font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
            Button {
                Haptics.tap()
                let item = MKMapItem(placemark: MKPlacemark(coordinate: point.coord.location))
                item.name = point.name
                item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
            } label: {
                Label("Directions", systemImage: "location.north.fill")
            }
            .buttonStyle(.pill(.primary, fill: true))
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    private func accessTag(_ isPublic: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: isPublic ? "checkmark.seal.fill" : "cup.and.saucer.fill").font(.system(size: 10, weight: .bold))
            Text(isPublic ? "Public" : "Customers only").font(.system(size: 11, weight: .bold))
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .foregroundStyle(isPublic ? Color(hex: "#0f7a42") : Color(hex: "#9a6a00"))
        .background(isPublic ? Palette.successSoft : Palette.goldSoft, in: Capsule())
    }
}
