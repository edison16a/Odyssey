//
//  SearchView.swift
//  Odyssey
//
//  Search for places. Curated Odyssey places and the real OpenStreetMap
//  places around your Explore location are searched together, by name,
//  category or cuisine, and results update on every keystroke.
//  Ported from features/search/search.js.
//

import Foundation
import SwiftUI

struct SearchView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var query = ""
    @State private var pool: [Place] = []
    @FocusState private var focused: Bool

    private let recent = ["quiet cafe", "tacos", "Cheese Board"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                FieldBox(icon: "search") {
                    TextField("Search places near you", text: $query)
                        .font(.system(size: 15))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .focused($focused)
                }
                Button("Cancel") { router.pop() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
            ScrollView(showsIndicators: false) {
                content
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Palette.surface)
        .onAppear {
            pool = searchPool()
            focused = true
        }
    }

    /// Everything searchable right now: curated places plus the real ones around you.
    private func searchPool() -> [Place] {
        let loc = store.exploreLocation
        let real: [Place]
        if let area = store.seed.discoverPlaces[loc.id] {
            real = area.places.map { store.osmPlaces["osm-" + $0.id] ?? NearbyService.normalize($0, store: store, register: false) }
            // Register them in one go so the app redraws once.
            var all = store.osmPlaces
            for place in real where all[place.id] == nil { all[place.id] = place }
            if all.count != store.osmPlaces.count { store.osmPlaces = all }
        } else {
            real = Array(store.osmPlaces.values)
        }
        return store.seed.places.filter { $0.category != "transit" } + real
    }

    private func results(_ text: String) -> [Place]? {
        let q = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return nil }
        let words = q.split(separator: " ").map(String.init)
        return Array(pool.filter { place in
            let hay = [place.name, store.placeKind(place).label, place.blurb ?? "", place.tags?["cuisine"] ?? ""]
                .joined(separator: " ").lowercased()
            return words.allSatisfy { hay.contains($0) }
        }.prefix(30))
    }

    @ViewBuilder private var content: some View {
        if let found = results(query) {
            if found.isEmpty {
                Text("Nothing matches \"\(query)\" yet. Try a name, a food or a kind of place.")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader(title: "Places", link: "\(found.count)").padding(.top, 16)
                    rows(found)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "Recent").padding(.top, 16)
                HStack(spacing: 8) {
                    ForEach(recent, id: \.self) { term in
                        Chip(label: term, icon: "clock") { query = term }
                    }
                }
                SectionHeader(title: "Nearby").padding(.top, 28)
                rows(Array(store.nearbyPlaces.filter { $0.category != "transit" }.prefix(6)))
            }
        }
    }

    private func rows(_ places: [Place]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                if index > 0 { Divider().overlay(Palette.line) }
                SearchPlaceRow(place: place) { router.push(.place(place.id)) }
            }
        }
    }
}

struct SearchPlaceRow: View {
    @Environment(AppStore.self) private var store
    var place: Place
    var onTap: () -> Void

    var body: some View {
        let status = store.status(of: place).status
        Button(action: onTap) {
            HStack(spacing: 12) {
                PlacePhoto(place: place)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                    Text([store.placeKind(place).label, Format.distance(store.metres(to: place))].joined(separator: ", "))
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
                if status == .new {
                    Tag(text: "Be first", icon: "star-fill", tone: .rare)
                } else if status == .mine {
                    Tag(text: "", icon: "check", tone: .success)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}
