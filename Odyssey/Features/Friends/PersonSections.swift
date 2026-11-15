//
//  PersonSections.swift
//  Odyssey
//
//  The places someone explored, under their header: a small hex map in
//  their color and the list of places. The explorer card and rank roadmap
//  above it are the same ones your own profile uses.
//

import Foundation
import SwiftUI

struct FriendsPersonPlaces: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var person: Person

    var body: some View {
        let places = store.exploredPlaces(of: person.id)
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Places explored", link: places.isEmpty ? nil : "\(places.count)")
            if places.isEmpty {
                Text("No places yet.").font(.system(size: 13)).foregroundStyle(Palette.muted).padding(.vertical, Space.s6)
            } else {
                FriendsHexMap(ids: [person.id])
                    .frame(height: 200)
                    .allowsHitTesting(false)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
                    .padding(.bottom, Space.s2)
                ForEach(places) { place in row(place) }
            }
        }
        .padding(.horizontal, Space.s5)
    }

    private func row(_ place: Place) -> some View {
        Button { router.push(.place(place.id)) } label: {
            HStack(spacing: Space.s3) {
                PlacePhoto(place: place)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                    Text(store.placeKind(place).label).font(.system(size: 13)).foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if store.firstExplorer(place)?.by == person.id { Tag(text: "First", icon: "star-fill", tone: .rare) }
            }
            .padding(.vertical, Space.s3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
