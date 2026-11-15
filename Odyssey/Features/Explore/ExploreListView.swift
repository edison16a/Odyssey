//
//  ExploreListView.swift
//  Odyssey
//
//  Explore's list mode: every place at once in a two column grid you can keep
//  scrolling, with a heart on each card. Two tabs: Places you'll love (the
//  same Supermemory-backed ranking the feed uses) and Hidden gems (places
//  nobody on Odyssey has explored yet). The grid keeps loading further out
//  as you near the bottom.
//

import Foundation
import SwiftUI

enum ExploreListTab: String, CaseIterable, Identifiable {
    case loved, gems
    var id: String { rawValue }
    var label: String { self == .loved ? "Places you'll love" : "Hidden gems" }
}

struct ExploreListView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var places: [Place]
    @Binding var tab: ExploreListTab
    var loading: Bool
    var topInset: CGFloat
    var onToggleLike: (Place) -> Void
    var onNeedMore: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let shown = tab == .gems ? places.filter { store.status(of: $0).status == .new } : places
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                picker
                header
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { i, place in
                        ExploreListCard(place: place, gem: tab == .gems,
                                        onOpen: { router.push(.place(place.id)) },
                                        onLike: { onToggleLike(place) })
                            .onAppear { if i >= shown.count - 6 { onNeedMore() } }
                    }
                }
                .padding(.horizontal, Space.s4)
                .padding(.top, Space.s3)
                if loading || shown.count < 6 {
                    HStack(spacing: Space.s2) {
                        ProgressView().tint(.white).controlSize(.small)
                        Text(tab == .gems ? "Looking for more hidden gems" : "Finding more places")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.s6)
                    .onAppear(perform: onNeedMore)
                }
            }
            .padding(.top, topInset + Space.s3)
            .padding(.bottom, Space.s8)
        }
        .scrollIndicators(.hidden)
        .background(Palette.ink)
        // Ask Supermemory to rank what's on the grid each time it grows, so the
        // reasons under each card come from your memories, not just the phone.
        .task(id: places.count / 12) { await Cloud.shared.rank(places, timeout: 12) }
    }

    private var picker: some View {
        HStack(spacing: 4) {
            ForEach(ExploreListTab.allCases) { t in
                Button {
                    Haptics.tap()
                    withAnimation(.snappy(duration: 0.25)) { tab = t }
                } label: {
                    HStack(spacing: 5) {
                        if t == .gems { Image(systemName: "star.fill").font(.system(size: 11, weight: .bold)) }
                        Text(t.label).font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(tab == t ? Palette.ink : .white.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(tab == t ? Color.white : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.white.opacity(0.1), in: Capsule())
        .padding(.horizontal, Space.s4)
    }

    private var header: some View {
        let gem = TasteGem.of(store)
        return VStack(alignment: .leading, spacing: 6) {
            Text(tab == .gems
                 ? "Nobody on Odyssey has been yet. Be first for +\(Rewards.first.coins) coins."
                 : "Picked for your explorer type: \(gem.persona)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            if Cloud.shared.usedSupermemory {
                HStack(spacing: 5) {
                    Image(systemName: "brain.head.profile").font(.system(size: 11, weight: .bold))
                    Text(Cloud.shared.memoriesUsed > 0
                         ? "Ranked with Supermemory from \(Cloud.shared.memoriesUsed) things you've done"
                         : "Ranked with Supermemory")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color(hex: "#c9b6ff"))
            }
        }
        .padding(.horizontal, Space.s4)
        .padding(.top, Space.s3)
    }
}

/// One place in the grid: photo, why it was picked, and a heart.
struct ExploreListCard: View {
    @Environment(AppStore.self) private var store
    var place: Place
    var gem: Bool
    var onOpen: () -> Void
    var onLike: () -> Void

    var body: some View {
        let liked = store.voteOf(place) == 1
        VStack(alignment: .leading, spacing: 4) {
            Button(action: onOpen) {
                PlacePhoto(place: place)
                    .frame(maxWidth: .infinity)
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if gem || store.status(of: place).status == .new {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Palette.rare, in: Circle())
                                .padding(8)
                        }
                    }
            }
            .buttonStyle(PressStyle(scale: 0.97))
            .overlay(alignment: .bottomTrailing) {
                Button {
                    onLike()
                } label: {
                    Image(systemName: liked ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(liked ? Color(hex: "#ff4d6d") : .white)
                        .frame(width: 38, height: 38)
                        .background(.black.opacity(0.45), in: Circle())
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(PressStyle(scale: 0.85))
                .padding(8)
                .accessibilityLabel(liked ? "Unlike \(place.name)" : "Like \(place.name)")
            }
            Text(place.name)
                .font(.system(size: 15, weight: .bold))
                .lineLimit(1)
                .padding(.top, 4)
            Text(store.why(place))
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(2)
            Text(Format.distance(store.metres(to: place)))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
        }
        .foregroundStyle(.white)
    }
}
