//
//  CheckInSteps.swift
//  Odyssey
//
//  "Where are you?" with the places closest to you, asked after recording
//  when the check-in did not start from a place.
//

import Foundation
import SwiftUI

/// Places to check in at, closest first.
struct CheckInPickStep: View {
    @Environment(AppStore.self) private var store
    var onPick: (Place) -> Void

    private var places: [Place] {
        let curated = store.nearbyPlaces.filter { $0.category != "transit" }
        let seen = Set(curated.map(\.id))
        let osm = store.osmPlaces.values.filter { !seen.contains($0.id) }
        // Each distance is worked out once, not twice per comparison of the sort.
        return (curated + osm).map { ($0, store.metres(to: $0)) }.sorted { $0.1 < $1.1 }.prefix(12).map { $0.0 }
    }

    var body: some View {
        let list = places
        return VStack(alignment: .leading, spacing: 4) {
            Text("Where are you?").font(.system(size: 28, weight: .bold)).tracking(-0.6).foregroundStyle(Palette.ink)
            Text("Pick the place to earn coins and keep your streak.").mutedStyle(13)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(list) { place in
                        if place.id != list.first?.id { Divider().overlay(Palette.line) }
                        row(place, closest: place.id == list.first?.id)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .padding(.top, 12)
        }
    }

    private func row(_ place: Place, closest: Bool) -> some View {
        let isNew = store.status(of: place).status == .new
        return Button { onPick(place) } label: {
            HStack(spacing: 12) {
                PhotoView(path: place.photo)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                    HStack(spacing: 0) {
                        Text(Format.distance(store.metres(to: place)) + " away").foregroundStyle(Palette.muted)
                        if isNew {
                            Text(", ").foregroundStyle(Palette.muted)
                            Text("be the first").fontWeight(.bold).foregroundStyle(Palette.rare)
                        }
                    }
                    .font(.system(size: 13))
                }
                Spacer(minLength: 0)
                if closest {
                    Text("Closest")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.accentInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Palette.accentSoft, in: Capsule())
                }
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.faint)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}
