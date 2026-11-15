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

    var body: some View {
        let meters = store.metres(to: place)
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
                        Text([kind.label, Format.distance(meters), Format.walkTime(meters)].joined(separator: ", "))
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.muted)
                    }
                    Spacer(minLength: 0)
                    ThumbsView(place: place)
                }
                contributorList
                status(info)
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
            let next = await Cloud.shared.placeContributors(place.id)
            withAnimation(.easeOut(duration: 0.2)) { contributors = next; loaded = true }
        }
    }

    /// Everyone who recorded a walkthrough here, most walkthroughs first.
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
                VStack(spacing: 0) {
                    ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
                        contributorRow(person, rank: index + 1)
                        if index < people.count - 1 { Divider().padding(.leading, 64) }
                    }
                }
                .card(padding: 12)
            } else if loaded {
                Text("No one has recorded this place yet. Be the first contributor.")
                    .font(.system(size: 13)).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .softCard()
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 18)
            }
        }
    }

    private func contributorRow(_ item: PlaceContributors.Person, rank: Int) -> some View {
        let person = item.personID.flatMap { store.person($0) } ?? (item.name == store.me.name ? store.me : nil)
        return Button {
            guard let person else { return }
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.push(.person(person.id)) }
        } label: {
            HStack(spacing: 10) {
                Text("\(rank)").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.muted).frame(width: 14)
                if let person {
                    AvatarView(person: person, size: 38, frame: "none")
                } else {
                    Circle().fill(Palette.surface3).frame(width: 38, height: 38)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.ink)
                    Text(item.summary ?? "Recorded a walkthrough")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(item.count)").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.accentInk)
                    Text(item.count == 1 ? "video" : "videos").font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
            }
            .padding(.vertical, 8)
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
