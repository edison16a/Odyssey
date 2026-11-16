//
//  SavedPlacesView.swift
//  Odyssey
//
//  Saved, opened from the bookmark at the top right of Explore: every place
//  you hearted, newest first, in the same grid as Explore. Tap one to open it,
//  tap the heart to take it off the list.
//

import Foundation
import SwiftUI

struct SavedPlacesView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let places = store.state.starred.values.sorted { $0.name < $1.name }
        VStack(spacing: 0) {
            NavHeader(title: "Saved", back: { router.pop() })
            if places.isEmpty {
                VStack(spacing: Space.s2) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Palette.faint)
                        .padding(.bottom, Space.s2)
                    Text("Nothing saved yet")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text("Tap the heart on a place in Explore and it lands here.")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Space.s6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(places.count == 1 ? "1 place" : "\(places.count) places")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Space.s4)
                        .padding(.top, Space.s2)
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(places, id: \.id) { place in
                            ExploreListCard(place: place, gem: false,
                                            onOpen: { router.push(.place(place.id)) },
                                            onLike: { unsave(place) })
                        }
                    }
                    .padding(.horizontal, Space.s4)
                    .padding(.top, Space.s3)
                    .padding(.bottom, Space.s8)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(Palette.surface)
    }

    private func unsave(_ place: Place) {
        Haptics.tap()
        if store.voteOf(place) == 1 { store.vote(place, 1) } // the same thumb again undoes it
        if store.isStarred(place) { store.toggleStar(place) }
    }
}
