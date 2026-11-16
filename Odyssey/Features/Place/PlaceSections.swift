//
//  PlaceSections.swift
//  Odyssey
//
//  The three tabs of a place page. Overview: the blurb, the 3D spaces,
//  what Odyssey learned from walkthroughs and the practical details.
//  Deals: Whop deals, a walkthrough bounty covering the place and any
//  quest waiting here. Activity: who explored it first, friends, the
//  regulars, the visit grid, recent contributions and explorer photos.
//  Ported from features/place/place-sections.js.
//

import Foundation
import SwiftUI

// MARK: - Overview

struct PlaceOverviewTab: View {
    var place: Place
    var history: PlaceHistory?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let blurb = place.blurb, !blurb.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader(title: "About")
                    Text(blurb)
                        .font(.system(size: 15))
                        .lineSpacing(3)
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            ScanPlaceRow(place: place)
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "From walkthroughs")
                PlaceWalkthroughCard(place: place, total: history?.total)
            }
            PlaceAmenityDetails(place: place)
            PlaceDetailsCard(place: place)
            if place.isOSM || place.fromAppleMaps {
                Text(place.fromAppleMaps ? "Place data from Apple Maps" : "Place data from OpenStreetMap contributors")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
        }
    }
}

/// Hours, distance and address as tidy icon rows.
private struct PlaceDetailsCard: View {
    @Environment(AppStore.self) private var store
    var place: Place

    private struct Row {
        var icon: String
        var label: String
        var value: String
    }

    var body: some View {
        let list = rows
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "Details")
                VStack(spacing: 0) {
                    ForEach(Array(list.enumerated()), id: \.offset) { index, row in
                        if index > 0 { Divider().overlay(Palette.line).padding(.leading, 48) }
                        HStack(spacing: 12) {
                            Image(systemName: row.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                                .frame(width: 36, height: 36)
                                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(row.label).font(.system(size: 12)).foregroundStyle(Palette.muted)
                                Text(row.value)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 10)
                    }
                }
                .padding(.vertical, -4)
                .card(padding: 14)
            }
        }
    }

    private var rows: [Row] {
        let metres = store.metres(to: place)
        let distance = [Format.distance(metres), Format.walkTime(metres)].filter { !$0.isEmpty }.joined(separator: ", ")
        return [
            Row(icon: "clock", label: "Hours", value: place.hours ?? ""),
            Row(icon: "figure.walk", label: "Distance", value: distance),
            Row(icon: "mappin.and.ellipse", label: "Address", value: address),
        ].filter { !$0.value.isEmpty }
    }

    private var address: String {
        let raw = place.address ?? ""
        if raw.isEmpty { return "" }
        if place.isOSM { return raw }
        let city = store.seed.areas[place.areaID]?.city ?? ""
        return city.isEmpty ? raw : raw + ", " + city + ", CA"
    }
}

// MARK: - Deals

struct PlaceDealsTab: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var place: Place
    @State private var openBounty: Bounty?

    /// How many things the Deals tab holds, for the badge on the tab bar.
    static func count(_ place: Place, store: AppStore) -> Int {
        (store.deals[place.id] ?? []).count
            + (store.bounty(for: place) == nil ? 0 : 1)
            + (quest(place, store: store) == nil ? 0 : 1)
    }

    static func quest(_ place: Place, store: AppStore) -> Quest? {
        store.seed.quests.first { $0.placeId == place.id && store.state.questsDone[$0.id] == nil }
    }

    var body: some View {
        let deals = store.deals[place.id] ?? []
        let bounty = store.bounty(for: place)
        let quest = Self.quest(place, store: store)
        VStack(alignment: .leading, spacing: 24) {
            if !deals.isEmpty {
                PlaceDealsSection(place: place)
            }
            if let bounty {
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader(title: "Walkthrough bounty", link: "Paid by \(bounty.sponsor)")
                    PlaceBountyCard(bounty: bounty) { openBounty = bounty }
                }
            }
            if let quest {
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader(title: "Quest here", link: quest.ends)
                    PlaceQuestBanner(quest: quest)
                }
            }
            if deals.isEmpty && bounty == nil && quest == nil {
                empty
            }
            ownerRow
        }
        .sheet(item: $openBounty) { bounty in
            BountySheet(bountyID: bounty.id) { target in
                let id = target.id
                let here = place.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    if id == here { router.present(.walkthrough(placeID: id)) } else { router.push(.place(id)) }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "tag")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.muted)
                .frame(width: 52, height: 52)
                .background(Palette.surface, in: Circle())
                .overlay(Circle().strokeBorder(Palette.line, lineWidth: 1))
            Text("No deals here yet").font(.system(size: 16, weight: .bold)).foregroundStyle(Palette.ink)
            Text("When a business posts a Whop deal or a walkthrough bounty for \(place.name), it shows up here.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    /// Businesses can put up their own bounty for this place.
    private var ownerRow: some View {
        Button {
            Haptics.tap()
            router.present(.setBounty(placeID: place.id))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "dollarsign")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Palette.ink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Set a bounty here").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                    Text("Pay explorers for walkthroughs of \(place.name)")
                        .font(.system(size: 13)).foregroundStyle(Palette.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.faint)
            }
            .card(padding: 14)
        }
        .buttonStyle(PressStyle())
    }
}

/// The open bounty covering this place: sponsor, pool, the split and progress.
private struct PlaceBountyCard: View {
    @Environment(AppStore.self) private var store
    var bounty: Bounty
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    BountySponsorBadge(bounty: bounty, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bounty.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(bounty.sponsor).font(.system(size: 13)).foregroundStyle(Palette.muted)
                    }
                    Spacer(minLength: 0)
                    Text(Format.money(bounty.pool))
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Color(hex: "#7a5200"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Palette.surface, in: Capsule())
                }
                Text(BountyText.splitLine(bounty, store: store))
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#5c3d00"))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                BountyProgressView(bounty: bounty)
                HStack(spacing: 4) {
                    Image(systemName: "clock").font(.system(size: 10, weight: .semibold))
                    Text("\(bounty.days) days left").font(.system(size: 11))
                    Spacer()
                    Text("See bounty").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.ink)
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(Palette.ink)
                }
                .foregroundStyle(Palette.muted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.goldSoft, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: - Activity

struct PlaceActivityTab: View {
    @Environment(AppStore.self) private var store
    var place: Place
    var history: PlaceHistory?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PlaceFirstExplorerCard(place: place)
            PlaceFriendsCard(place: place)
            if !store.topExplorers(place).isEmpty {
                PlaceRegulars(place: place)
            }
            PlaceActivityGrid(place: place, history: history)
            if let history, !history.recent.isEmpty {
                PlaceContributions(items: history.recent)
            }
        }
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
    var total: Int?

    var body: some View {
        let count = total.map { $0 + (store.state.videos[place.id]?.count ?? 0) } ?? store.videoCount(place)
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
