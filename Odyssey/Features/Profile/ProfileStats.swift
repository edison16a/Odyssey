//
//  ProfileStats.swift
//  Odyssey
//
//  Badges, standings and the wallet on your profile. Ported from
//  profile-view.js and profile-tab.js.
//

import Foundation
import SwiftUI

/// Earned badges in a row of tiles.
struct ProfileBadgesSection: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let badges = store.state.earnedBadges.compactMap { store.seed.badge($0) }
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Badges", link: "\(badges.count) earned").padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(badges) { badge in
                        VStack(alignment: .leading, spacing: 4) {
                            Image(systemName: Icon.symbol(badge.icon))
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Color(hex: badge.color), in: Circle())
                                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 3))
                                .padding(.bottom, 4)
                            Text(badge.name).font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.ink).lineLimit(1)
                            Text(badge.desc).font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(3)
                        }
                        .padding(12)
                        .frame(width: 118, alignment: .topLeading)
                        .frame(minHeight: 150, alignment: .topLeading)
                        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

/// Where you stand on every board.
struct ProfileStandingsSection: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Standings", link: "See boards") { router.push(.leaderboard) }
            HStack(spacing: 6) {
                ForEach(store.standings()) { standing in
                    Button { router.push(.leaderboard) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(standing.scope.label).font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1)
                            Text(standing.scope.id == "city" ? "#\(Format.number(standing.position))" : "Top \(ProfileTravel.pct(standing.pct))%")
                                .font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    }
                    .buttonStyle(PressStyle())
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

/// What you can spend: coins in the shop, bounty cash on gift cards.
struct ProfileWalletSection: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Wallet")
            HStack(spacing: Space.s3) {
                widget(label: "Coins", value: Format.number(store.state.wallet.coins), sub: "Open the shop", coin: true) { router.push(.shop(nil)) }
                widget(label: "Bounty cash", value: Format.money(store.state.wallet.cash), sub: "Turn into gift cards", coin: false) { router.push(.giftCards) }
            }
        }
        .padding(.horizontal, 20)
    }

    private func widget(label: String, value: String, sub: String, coin: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if coin { CoinIcon(size: 15) } else { Image(systemName: "gift").font(.system(size: 13, weight: .semibold)) }
                    Text(label)
                }
                .labelStyle()
                Text(value).font(.system(size: 26, weight: .bold)).tracking(-0.8).monospacedDigit().foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
                Text(sub).font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
        .buttonStyle(PressStyle())
    }
}
