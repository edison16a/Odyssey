//
//  BountyParts.swift
//  Odyssey
//
//  Small pieces shared by every bounty surface: the sponsor badge, the
//  split explained in plain words, progress, the compact card and the
//  "Bounties near you" row on the home feed.
//  Ported from features/bounty/bounty-card.js and bounty.css.
//

import Foundation
import SwiftUI

enum BountyText {
    /// The place's name, or the area's.
    static func whereText(_ b: Bounty, store: AppStore) -> String {
        if b.target.kind == "place", let id = b.target.placeId { return store.place(id)?.name ?? b.target.name ?? id }
        return b.target.name ?? ""
    }

    /// One line on how the money is shared.
    static func splitLine(_ b: Bounty, store: AppStore) -> String {
        if b.isFunded {
            return "Up to \(b.maxExplorers ?? b.videos) explorers · estimated \(Format.money(store.bountySlice(b))) each. Payouts are not yet available."
        }
        if b.split == "even" {
            return "Demo allocation: split evenly, about \(Format.money(store.bountySlice(b))) each so far"
        }
        return "Demo reward: \(Format.money(store.bountySlice(b))) per walkthrough"
            + (b.firstBonus > 0 ? ", plus \(Format.money(b.firstBonus)) for the first one" : "")
    }
}

/// The sponsor's glyph on a tint of its color, in a rounded square.
struct BountySponsorBadge: View {
    var bounty: Bounty
    var size: CGFloat = 36

    var body: some View {
        let color = Color(hex: bounty.color)
        Image(systemName: Icon.symbol(bounty.logo.isEmpty ? "store" : bounty.logo))
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .background(Color.white, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

/// "11 of 30 walkthroughs" with money left (or the crew size) and a gold bar.
struct BountyProgressView: View {
    @Environment(AppStore.self) private var store
    var bounty: Bounty

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(bounty.isFunded ? "Up to \(bounty.maxExplorers ?? bounty.videos) eligible explorers" : "\(bounty.recorded) of \(bounty.videos) walkthroughs").font(.system(size: 13, weight: .bold))
                Spacer()
                Text(bounty.split == "even" ? "\(bounty.crew.count) explorers in" : "\(Format.money(store.bountyLeft(bounty))) left")
                    .font(.system(size: 13)).foregroundStyle(Palette.muted)
            }
            ProgressBar(value: Double(bounty.recorded) / Double(max(1, bounty.videos)), color: Palette.gold)
        }
        .padding(.top, 4)
    }
}

/// The card used in the home feed row and the business dashboard.
struct BountyCard: View {
    @Environment(AppStore.self) private var store
    var bounty: Bounty
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    BountySponsorBadge(bounty: bounty, size: 32)
                    Spacer()
                    Text(Format.money(bounty.pool))
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Color(hex: "#7a5200"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Palette.goldSoft, in: Capsule())
                }
                Text(bounty.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                Text((bounty.isFunded ? "" : "Demo · ") + bounty.sponsor + ", " + BountyText.whereText(bounty, store: store))
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
                BountyProgressView(bounty: bounty)
                HStack(spacing: 4) {
                    Image(systemName: "clock").font(.system(size: 10, weight: .semibold))
                    Text("\(bounty.daysRemaining) days left").font(.system(size: 11))
                }
                .foregroundStyle(Palette.muted)
            }
            .padding(14)
            .frame(width: 236, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
        }
        .buttonStyle(PressStyle())
    }
}

/// "Bounties near you": open bounties within 6 km, hidden when there are none.
struct BountyFeedSection: View {
    @Environment(AppStore.self) private var store
    var onOpen: (Bounty) -> Void

    var body: some View {
        let list = store.openBounties.filter { store.here.distance(to: $0.center) < 6000 }
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "Bounties near you", link: "Paid by businesses")
                    .padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(list) { bounty in
                            BountyCard(bounty: bounty) { onOpen(bounty) }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

/// The gold money tag at the center of a bounty on a map.
struct BountyMapTag: View {
    var bounty: Bounty

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "dollarsign").font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: "#b7791f"))
            Text(Format.money(bounty.pool)).font(.system(size: 13, weight: .bold)).foregroundStyle(Color(hex: "#3a2600"))
        }
        .padding(.leading, 6)
        .padding(.trailing, 9)
        .padding(.vertical, 5)
        .background(.white, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.gold, lineWidth: 2))
        .shadow(color: .black.opacity(0.18), radius: 7, y: 6)
    }
}
