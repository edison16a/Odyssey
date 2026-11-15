//
//  HomePlacePreview.swift
//  Odyssey
//
//  The sheet shown when a map pin or a card is tapped. It says why Odyssey
//  thinks you will like the place, whether anyone has been, any bounty a
//  business put up there, and offers the two moves: check in, or directions in Apple Maps.
//  Ported from features/home/place-preview.js.
//

import Foundation
import SwiftUI

struct HomePlacePreview: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    var place: Place
    var onBounty: (Bounty) -> Void = { _ in }

    @State private var contributors: PlaceContributors?
    @State private var loaded = false
    @State private var history: PlaceHistory?

    var body: some View {
        let meters = store.here.distance(to: place.coords)
        let kind = store.placeKind(place)
        let info = store.status(of: place)
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // A compact header: the contributors are the point of this sheet.
                HStack(spacing: 12) {
                    PlacePhoto(place: place)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name).font(.system(size: 20, weight: .bold)).tracking(-0.3).foregroundStyle(Palette.ink).lineLimit(2)
                        Text(store.usingRealLocation ? [kind.label, Format.distance(meters), Format.walkTime(meters)].joined(separator: ", ") : kind.label)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.muted)
                    }
                    Spacer(minLength: 0)
                    ThumbsView(place: place)
                }
                if let address = place.address, !address.isEmpty {
                    Text(address).font(.subheadline).foregroundStyle(Palette.muted)
                }
                PlaceAmenityDetails(place: place)
                if place.fromAppleMaps {
                    Text("Place data from Apple Maps").font(.caption2).foregroundStyle(Palette.muted)
                }
                PlaceDealsSection(place: place)
                contributorList
                // "Nobody has been here" would contradict a list of contributors.
                if !(info.status == .new && (contributors?.total ?? 0) > 0) { status(info) }
                bountyCallout
                ScanPlaceRow(place: place, before: { dismiss() })
                HStack(spacing: 8) {
                    Button {
                        dismiss()
                        // Let the sheet finish closing, or the cover can fail to present.
                        let id = place.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.present(.checkIn(placeID: id)) }
                    } label: {
                        Label("Check in", systemImage: "camera")
                    }
                    .buttonStyle(.pill(.accent, fill: true))
                    Button {
                        LiveActivityService.shared.start(place: place, store: store)
                        NearbyService.directions(to: place)
                    } label: {
                        Label("Directions", systemImage: "location.north.fill")
                    }
                    .buttonStyle(.pill(.primary))
                }
                Button {
                    dismiss()
                    let id = place.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.present(.setBounty(placeID: id)) }
                } label: {
                    Label("Set Bounty for This Location", systemImage: "dollarsign.circle.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.pill(.primary))
                Button("See place details") {
                    dismiss()
                    let id = place.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.push(.place(id)) }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)
        }
        .task(id: place.id) {
            async let people = Cloud.shared.placeContributors(place.id)
            async let graph = Cloud.shared.placeHistory(place.id)
            let (next, days) = await (people, graph)
            withAnimation(.easeOut(duration: 0.2)) { contributors = next; history = days; loaded = true }
        }
    }

    /// The first explorer, the top three as a podium, and the daily contribution graph.
    @ViewBuilder private var contributorList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Contributors").font(.system(size: 17, weight: .bold)).foregroundStyle(Palette.ink)
                Spacer()
                if let contributors, contributors.total > 0 {
                    Text("\(contributors.people.count) people · \(contributors.total) walkthroughs")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.muted)
                }
            }
            if let people = contributors?.people, !people.isEmpty {
                if let first = contributors?.first { firstContributor(first) }
                podium(Array(people.prefix(3)))
            } else if loaded {
                Text("No one has recorded this place yet. Be the first contributor.")
                    .font(.system(size: 13)).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .softCard()
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 18)
            }
            if loaded, (contributors?.total ?? 0) > 0 {
                PlaceActivityGrid(place: place, history: history).padding(.top, 6)
            }
        }
    }

    private func lookup(_ personID: String?, name: String) -> Person? {
        personID.flatMap { store.person($0) } ?? (name == store.me.name ? store.me : nil)
    }

    private func open(_ person: Person?) {
        guard let person else { return }
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.push(.person(person.id)) }
    }

    /// Who explored the place before anyone else.
    private func firstContributor(_ first: PlaceContributors.First) -> some View {
        let person = lookup(first.personID, name: first.name)
        return Button { open(person) } label: {
            HStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    if let person {
                        AvatarView(person: person, size: 42, frame: "none")
                    } else {
                        Circle().fill(Palette.surface3).frame(width: 42, height: 42)
                    }
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .padding(4)
                        .background(Palette.gold, in: Circle())
                        .offset(x: 6, y: -6)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("First contributor").font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: "#5c3d00")).textCase(.uppercase)
                    Text(first.name).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                    Text("Explored it first on \(first.at.formatted(.dateTime.month(.abbreviated).day().year()))")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.goldSoft, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(PressStyle())
    }

    /// Second on the left, first in the middle, third on the right.
    private func podium(_ top: [PlaceContributors.Person]) -> some View {
        let slots: [(rank: Int, height: CGFloat, color: Color)] = [
            (2, 54, Color(hex: "#c7ccd6")), (1, 78, Palette.gold), (3, 40, Color(hex: "#d9a273")),
        ]
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(slots, id: \.rank) { slot in
                if slot.rank <= top.count {
                    podiumColumn(top[slot.rank - 1], rank: slot.rank, height: slot.height, color: slot.color)
                } else {
                    Color.clear.frame(maxWidth: .infinity, minHeight: slot.height)
                }
            }
        }
        .padding(.top, 4)
    }

    private func podiumColumn(_ item: PlaceContributors.Person, rank: Int, height: CGFloat, color: Color) -> some View {
        let person = lookup(item.personID, name: item.name)
        let size: CGFloat = rank == 1 ? 56 : 46
        return Button { open(person) } label: {
            VStack(spacing: 6) {
                if let person {
                    AvatarView(person: person, size: size, frame: "none")
                } else {
                    Circle().fill(Palette.surface3).frame(width: size, height: size)
                }
                VStack(spacing: 1) {
                    Text(item.name.components(separatedBy: " ").first ?? item.name)
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.ink).lineLimit(1)
                    Text("\(item.count) \(item.count == 1 ? "video" : "videos")")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.muted)
                }
                Text("\(rank)")
                    .font(.system(size: rank == 1 ? 26 : 20, weight: .heavy))
                    .foregroundStyle(rank == 1 ? Palette.ink : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .background(color, in: UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12, style: .continuous))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    /// You claimed it before anyone else, and that stays on the place for good.
    private var firstClaim: some View {
        HStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Palette.ink)
                .frame(width: 42, height: 42)
                .background(Palette.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("You were the first explorer here").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                Text("Your name stays on it for everyone who comes after.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.goldSoft, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    /// A walkthrough bounty covering this place, if a business put one up.
    @ViewBuilder private var bountyCallout: some View {
        if let b = store.bounty(for: place) {
            Button { onBounty(b) } label: {
                HStack(spacing: 12) {
                    BountySponsorBadge(bounty: b, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Format.money(b.pool)) walkthrough bounty from \(b.sponsor)").font(.system(size: 15, weight: .bold))
                        Text(BountyText.splitLine(b, store: store)).font(.system(size: 13))
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color(hex: "#5c3d00"))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.goldSoft, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            }
            .buttonStyle(PressStyle())
        }
    }

    @ViewBuilder private func status(_ info: (status: PlaceStatus, explorers: Int)) -> some View {
        switch info.status {
        case .new:
            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Palette.rare, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nobody on Odyssey has been here").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                    Text("Check in first and your name stays on it, plus \(Rewards.checkIn.coins + Rewards.first.coins) coins.")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.muted)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.rareSoft, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        case .mine:
            if store.state.firsts.contains(place.id) {
                firstClaim
            } else {
                Tag(text: "You explored this", icon: "check", tone: .success)
            }
        case .explored:
            Tag(text: "\(info.explorers) explorers have been", icon: "users")
        }
    }
}
