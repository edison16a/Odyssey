//
//  ProfileRoadmap.swift
//  Odyssey
//
//  The six tier rank roadmap and the Explorer Icon card. The roadmap shows
//  every tier's XP threshold, the share of explorers at or above it, and
//  where you sit. The icon card is the historical explorer your profile
//  wears, with how much of their journey you have walked.
//  Ported from rank-roadmap.js and explorer-icon.js.
//

import Foundation
import SwiftUI

struct ProfileRoadmap: View {
    @Environment(AppStore.self) private var store
    var xp: Int
    var action: () -> Void

    var body: some View {
        let rank = store.rank(xp: xp)
        let share = store.seed.rankShare
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    RankEmblem(tier: rank.tier, size: 44)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Rank").labelStyle()
                        Text(rank.current.name).font(.system(size: 20, weight: .bold)).foregroundStyle(Color(hex: rank.current.color))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(xp) XP").font(.system(size: 15, weight: .bold)).monospacedDigit().foregroundStyle(Palette.ink)
                        Text("Top \(ProfileTravel.pct(share.indices.contains(rank.tier) ? share[rank.tier] : 100))% of Explorers")
                            .font(.system(size: 11)).foregroundStyle(Palette.muted)
                    }
                }
                .padding(.bottom, 12)
                ProgressBar(value: rank.progress, color: Color(hex: rank.current.color))
                Text(rank.next.map { "\($0.xp - xp) XP to \($0.name). \($0.perk)." } ?? "You reached the top tier.")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
                    .padding(.top, 6).padding(.bottom, 14)
                HStack(spacing: 4) {
                    ForEach(Array(store.seed.ranks.enumerated()), id: \.offset) { index, tier in
                        tierCell(index: index, tier: tier, current: rank.tier)
                    }
                }
            }
            .multilineTextAlignment(.leading)
            .card()
        }
        .buttonStyle(PressStyle(scale: 0.98))
    }

    private func tierCell(index: Int, tier: Rank, current: Int) -> some View {
        VStack(spacing: 3) {
            RankEmblem(tier: index, size: 30).opacity(index > current ? 0.45 : 1)
            Text(tier.name).font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(index > current ? Palette.faint : Palette.ink).lineLimit(1).minimumScaleFactor(0.7)
            Text("\(tier.xp)").font(.system(size: 9.5)).foregroundStyle(Palette.muted).monospacedDigit()
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(index == current ? Palette.accentSoft : .clear, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if index > current {
                Image(systemName: "lock.fill").font(.system(size: 8)).foregroundStyle(Palette.faint).padding(.top, 4).padding(.trailing, 6)
            }
        }
    }
}

/// The Explorer Icon card on a parchment plate.
struct ProfileExplorerCard: View {
    var explorer: Explorer
    var km: Double? = nil
    var eyebrow = "Explorer Icon"
    var full = false
    var onPick: (() -> Void)? = nil

    static let parchment = Color(hex: "#f4ecd6")
    static let ink = Color(hex: "#22291f")

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ProfileExplorerPortrait(explorer: explorer, size: 86)
            VStack(alignment: .leading, spacing: 2) {
                Text(eyebrow).font(.system(size: 11, weight: .bold)).tracking(0.9).textCase(.uppercase).opacity(0.6)
                Text(explorer.name).font(.system(size: 21, weight: .bold, design: .serif))
                Text(explorer.years).font(.system(size: 11)).opacity(0.7)
                if full {
                    Text(explorer.known).font(.system(size: 13)).padding(.vertical, 4)
                }
                HStack(spacing: 4) {
                    Image(systemName: Icon.symbol(explorer.glyph)).font(.system(size: 10, weight: .bold))
                    Text(explorer.region).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: explorer.color), in: Capsule())
                .padding(.top, 4)
                if let km {
                    let share = max(0.1, (km / explorer.benchmarkKm * 1000).rounded() / 10)
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressBar(value: min(1, share / 100), color: ProfileExplorerCard.ink, track: ProfileExplorerCard.ink.opacity(0.15), height: 4)
                        Text("You have walked \(ProfileTravel.pct(share))% of their journey").font(.system(size: 11))
                    }
                    .padding(.top, 8)
                }
            }
            Spacer(minLength: 0)
            if let onPick {
                Button("Change", action: onPick)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ProfileExplorerCard.parchment)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(ProfileExplorerCard.ink, in: Capsule())
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .foregroundStyle(ProfileExplorerCard.ink)
        .padding(.vertical, 12)
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ProfileExplorerCard.parchment, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(ProfileExplorerCard.ink.opacity(0.18), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg - 5, style: .continuous).strokeBorder(ProfileExplorerCard.ink.opacity(0.14), lineWidth: 1).padding(5))
    }
}

/// The engraved bank note portrait from the mockup, on its rounded plate.
struct ProfileExplorerPortrait: View {
    var explorer: Explorer
    var size: CGFloat

    var body: some View {
        ExplorerPortrait(explorerID: explorer.id, width: size)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color(hex: "#3c2e14").opacity(0.22), radius: 6, y: 4)
    }
}
