//
//  HomeFeed.swift
//  Odyssey
//
//  Everything under the home map: search, the streak with Globie, the stat
//  tiles, Today's Adventure, picks for you, the winter season, bounties
//  near you, quests and the places nobody on Odyssey has explored yet. Ported from features/home/home-feed.js.
//

import Foundation
import SwiftUI

struct HomeFeed: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var onPick: (Place) -> Void
    var onReveal: () -> Void
    var onBounty: (Bounty) -> Void = { _ in }
    @State private var season: SeasonQuest?
    @State private var unbox: ShopItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchButton
            VStack(spacing: 12) {
                HomeStreakCard()
                HomeTiles()
            }
            .padding(.horizontal, 20)
            HomeDailySection(onReveal: onReveal)
                .padding(.horizontal, 20)
                .padding(.top, 28)
            HomeDailyMapCard()
                .padding(.horizontal, 20)
                .padding(.top, 12)
            picks
            SeasonBanner { season = $0 }
                .padding(.horizontal, 20)
                .padding(.top, 28)
            BountyFeedSection(onOpen: onBounty)
                .padding(.top, 28)
            QuestListSection()
                .padding(.horizontal, 20)
                .padding(.top, 28)
            firsts
            TabBarSpacer()
        }
        .sheet(item: $season) { quest in
            SeasonSheet(questID: quest.id) { item in unbox = item }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .fullScreenCover(item: $unbox) { item in ShopUnboxView(item: item) }
    }

    private var searchButton: some View {
        Button { router.push(.search) } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.system(size: 18))
                Text("Search places near you").font(.system(size: 15))
                Spacer()
            }
            .foregroundStyle(Palette.muted)
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(PressStyle())
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    /// Nearby places you have not explored yet, best for you first.
    @ViewBuilder private var picks: some View {
        let spots = Array(store.forYou().filter { store.status(of: $0).status != .mine }.prefix(8))
        if !spots.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "Picked for you", link: "See all") { router.select(.explore) }
                    .padding(.horizontal, 20)
                carousel(spots, star: false)
            }
            .padding(.top, 28)
        }
    }

    @ViewBuilder private var firsts: some View {
        let spots = store.nearbyPlaces.filter { store.status(of: $0).status == .new }
        if !spots.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "Be the first explorer", link: "+\(Rewards.checkIn.coins + Rewards.first.coins) coins")
                    .padding(.horizontal, 20)
                carousel(spots, star: true)
            }
            .padding(.top, 28)
        }
    }

    private func carousel(_ places: [Place], star: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(places) { place in
                    HomeRecCard(place: place, star: star) { onPick(place) }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

/// A photo card with the reason Odyssey picked it and a thumbs pair.
struct HomeRecCard: View {
    @Environment(AppStore.self) private var store
    var place: Place
    var star = false
    var onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: onTap) {
                PlacePhoto(place: place)
                    .frame(width: 168, height: 126)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if star {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(Palette.rare, in: Circle())
                                .padding(8)
                        }
                    }
            }
            .buttonStyle(PressStyle())
            Button(action: onTap) {
                Text(place.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            Text(store.why(place))
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted)
                .lineLimit(2, reservesSpace: true)
            HStack {
                Text(Format.distance(store.metres(to: place))).font(.system(size: 11)).foregroundStyle(Palette.muted)
                Spacer()
                ThumbsView(place: place, size: 15)
            }
            .padding(.top, 2)
        }
        .frame(width: 168)
    }
}
