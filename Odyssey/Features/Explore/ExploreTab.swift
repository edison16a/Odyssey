//
//  ExploreTab.swift
//  Odyssey
//
//  Explore: an endless deck of real places around you, ranked by what you
//  love. Where you are sits on top, then the filter chips and a search bar
//  that knows about a thousand things to look for, the deck in the middle,
//  and one quiet line at the bottom that says what Odyssey has learned,
//  with a way into the full picture. Every swipe teaches the same taste
//  model the rest of the app uses. Ported from discover-tab.js.
//

import Foundation
import SwiftUI

struct ExploreTab: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    @State private var feed = ExploreFeed()
    @State private var liked: [Place] = []
    @State private var showLocation = false
    @State private var showLiked = false
    @State private var typed = ""
    @FocusState private var searching: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            ExploreFilterBar(filter: feed.filter) { pick($0) }
                .padding(.top, 12)
            ExploreSearchBar(text: $typed, active: activeQuery, focused: $searching,
                             onPick: { pick(.search($0)) }, onClear: { pick(.all) })
                .padding(.horizontal, Space.s4)
                .padding(.top, 10)
            ZStack(alignment: .top) {
                deck
                    .padding(.horizontal, Space.s4)
                    .padding(.top, 12)
                if searching && !typed.isEmpty {
                    ExploreSuggestions(typed: typed) { pick(.search($0)) }
                        .padding(.horizontal, Space.s4)
                        .padding(.top, 6)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxHeight: .infinity)
            .animation(.easeOut(duration: 0.18), value: searching && !typed.isEmpty)
            ExploreLearnedLine { router.push(.tasteProfile) }
            TabBarSpacer()
        }
        .background(Palette.surface)
        .task(id: locationKey) {
            await feed.start(store: store, key: locationKey)
            syncCategory()
        }
        .onChange(of: store.state.discoverCategory) { syncCategory() }
        .sheet(isPresented: $showLocation) {
            ExploreLocationSheet()
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showLiked) {
            ExploreLikedSheet(liked: liked)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
        }
    }

    /// Changes whenever the Explore location does, so the deck reloads.
    private var locationKey: String {
        let loc = store.exploreLocation
        return "\(loc.id)\(loc.center.lat),\(loc.center.lng)"
    }

    private var activeQuery: ExploreQuery? {
        if case .search(let q) = feed.filter { return q }
        return nil
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button { showLocation = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                    Text(store.exploreLocation.label)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(Palette.ink)
                .padding(.leading, 10)
                .padding(.trailing, 12)
                .padding(.vertical, 7)
                .background(Palette.surface2, in: Capsule())
            }
            .buttonStyle(PressStyle())
            .frame(maxWidth: 240, alignment: .leading)
            Spacer()
            Button { showLiked = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: "hand.thumbsup.fill").font(.system(size: 12, weight: .bold))
                    Text("\(liked.count)").font(.system(size: 13, weight: .bold)).monospacedDigit()
                }
                .foregroundStyle(liked.isEmpty ? Palette.muted : .white)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(liked.isEmpty ? Palette.surface2 : Palette.accent, in: Capsule())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Places you liked")
        }
        .padding(.horizontal, Space.s4)
        .padding(.top, 8)
    }

    @ViewBuilder private var deck: some View {
        if feed.loading {
            ExploreLoadingCard()
        } else if feed.exhausted {
            VStack(spacing: 8) {
                Text("That is everything around here").font(.system(size: 22, weight: .bold)).tracking(-0.4)
                Text("Try another filter, or pick another place to explore.").mutedStyle(15)
                Button("Show all") { pick(.all) }.buttonStyle(.pill(.soft)).padding(.top, 6)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 8) {
                if let line = noteLine {
                    Text(line).font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.muted).lineLimit(1)
                }
                ExploreDeckView(feed: feed, liked: $liked)
            }
        }
    }

    private var noteLine: String? {
        if feed.broadened, let q = activeQuery {
            let cat = q.cats.first.flatMap { store.seed.discoverCategory($0)?.label.lowercased() } ?? "places"
            return "Nothing called \(q.text) nearby, so here are \(cat)"
        }
        return feed.note.isEmpty ? nil : feed.note
    }

    private func pick(_ next: ExploreFilter) {
        Haptics.tap()
        searching = false
        switch next {
        case .search(let q): typed = q.text
        default: typed = ""
        }
        var saved = "all"
        if case .category(let id) = next { saved = id }
        if store.state.discoverCategory != saved { store.update { s in s.discoverCategory = saved } }
        guard next != feed.filter else { return }
        feed.apply(next, store: store)
    }

    /// A category chosen elsewhere (the demo guide) carries over to the deck.
    private func syncCategory() {
        let id = store.state.discoverCategory
        let wanted: ExploreFilter = store.seed.discoverCategory(id) == nil ? .all : .category(id)
        if case .search = feed.filter, wanted == .all { return }
        if wanted != feed.filter && (wanted != .all || feed.filter.isCategory) { feed.apply(wanted, store: store) }
    }
}

extension ExploreFilter {
    var isCategory: Bool {
        if case .category = self { return true }
        return false
    }
}
