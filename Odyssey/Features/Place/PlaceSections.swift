//
//  PlaceSections.swift
//  Odyssey
//
//  The recognition blocks of a place page: an open quest here, who
//  explored it first, the walkthroughs explorers shared and what Odyssey
//  learned from them, the regulars, the visit activity grid, explorer
//  photos and the address. Ported from features/place/place-sections.js.
//

import Foundation
import SwiftUI

struct PlaceSectionsStack: View {
    @Environment(AppStore.self) private var store
    var place: Place

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let quest = store.seed.quests.first(where: { $0.placeId == place.id && store.state.questsDone[$0.id] == nil }) {
                section { PlaceQuestBanner(quest: quest) }
            }
            section { PlaceFirstExplorerCard(place: place) }
            section { PlaceFriendsCard(place: place) }
            section { PlaceWalkthroughCard(place: place) }
            if !store.topExplorers(place).isEmpty {
                section { PlaceRegulars(place: place) }
            }
            section { PlaceActivityGrid(place: place) }
            if !explorerPosts.isEmpty {
                section { PlaceExplorerPhotos(place: place, posts: explorerPosts) }
            }
            if !address.isEmpty {
                section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Address").font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.ink)
                        Text(address).font(.system(size: 13)).foregroundStyle(Palette.ink2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .softCard()
                }
            }
            if place.isOSM {
                section {
                    Text(place.fromAppleMaps ? "Place data from Apple Maps" : "Place data from OpenStreetMap contributors")
                        .font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
            }
        }
    }

    private func section<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content().padding(.horizontal, 20).padding(.top, 20)
    }

    private var explorerPosts: [Post] {
        store.seed.posts.filter { $0.placeId == place.id && $0.selfie != nil }
    }

    private var address: String {
        let raw = place.address ?? ""
        if raw.isEmpty { return "" }
        if place.isOSM { return raw }
        let city = store.seed.areas[place.areaID]?.city ?? ""
        return raw + ", " + city + ", CA"
    }
}

/// The quest waiting at this place.
private struct PlaceQuestBanner: View {
    @Environment(AppStore.self) private var store
    var quest: Quest

    var body: some View {
        HStack(spacing: 12) {
            PlaceStarBadge(icon: "flag", size: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(quest.title).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                Text("\(quest.ends), \(quest.coins) coins and \(quest.xp) XP").mutedStyle(13)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Palette.rareSoft, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }
}

/// The purple rounded star tile used on first explorer cards.
struct PlaceStarBadge: View {
    var icon = "star-fill"
    var size: CGFloat = 18

    var body: some View {
        Image(systemName: Icon.symbol(icon))
            .font(.system(size: size * 0.8, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(Palette.rare, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// The first explorer keeps their name on the place for good.
private struct PlaceFirstExplorerCard: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var place: Place

    var body: some View {
        if let first = firstInfo, let who = store.person(first.by) {
            Button { open(who.id) } label: {
                HStack(spacing: 12) {
                    AvatarView(person: who, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("First explorer").labelStyle()
                        Text(who.id == "me" ? "You" : who.name).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                        Text(first.date.isEmpty ? "Discovered on Odyssey" : "Discovered " + Format.longDate(first.date)).mutedStyle(13)
                    }
                    Spacer(minLength: 0)
                    PlaceStarBadge()
                }
                .padding(14)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            }
            .buttonStyle(PressStyle())
        } else {
            HStack(spacing: 12) {
                PlaceStarBadge(size: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nobody has explored this yet").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                    Text("Check in first and your name stays on this place.").mutedStyle(13)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(Palette.rareSoft, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
    }

    private var firstInfo: (by: String, date: String)? {
        if store.state.firsts.contains(place.id) {
            return ("me", store.state.checkins[place.id] ?? store.firstExplorer(place)?.date ?? "")
        }
        return store.firstExplorer(place)
    }

    private func open(_ id: String) {
        if id == "me" { router.select(.profile) } else { router.push(.person(id)) }
    }
}

/// Walkthroughs shared here, and what Odyssey learned from them.
private struct PlaceWalkthroughCard: View {
    @Environment(AppStore.self) private var store
    var place: Place

    var body: some View {
        let count = store.videoCount(place)
        let insight = store.state.placeInsights[place.id]
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "video.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Palette.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(count > 0 ? "\(count) \(count == 1 ? "walkthrough" : "walkthroughs") shared" : "No walkthroughs yet")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                Text(count > 0 ? "Explorers recorded the inside so others know what to expect." : "Record a short walkthrough after you check in for +50 XP.")
                    .mutedStyle(13)
                    .fixedSize(horizontal: false, vertical: true)
                if let insight { learned(insight) }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    private func learned(_ insight: AppState.Insights) -> some View {
        let tags = Array(([insight.vibe].compactMap { $0 } + (insight.tags ?? [])).prefix(4))
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { Tag(text: $0.capitalized) }
            }
            if let summary = insight.summary {
                Text(summary).mutedStyle(13).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 8)
    }
}
