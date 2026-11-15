//
//  HomeCards.swift
//  Odyssey
//
//  The cards at the top of the home panel: the streak with Globie and the
//  last seven days, then the stat tiles for coins, first finds, today's
//  recap and your rank.
//

import Foundation
import SwiftUI

struct HomeStreakCard: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let done = store.streakClaimedToday
        Button { router.push(.streak) } label: {
            HStack(spacing: 14) {
                GlobieView(mood: store.globieMood, form: store.streakTier.id, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    (Text("\(store.state.streak.days)").font(.system(size: 22, weight: .heavy)).monospacedDigit()
                        + Text(" day streak").font(.system(size: 17, weight: .bold)))
                        .foregroundStyle(Palette.ink)
                    Text(done ? "Today counted. Globie is happy." : "Check in anywhere today to keep it going")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 4) {
                        ForEach(Array(store.streakWeek.enumerated()), id: \.offset) { _, day in
                            Text(day.letter)
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(day.done ? .white : Palette.faint)
                                .frame(width: 19, height: 19)
                                .background(day.done ? Palette.flame : Palette.surface3, in: Circle())
                                .overlay {
                                    if day.today && !day.done { Circle().strokeBorder(Palette.flame, lineWidth: 1.5) }
                                }
                        }
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.faint)
            }
            .padding(16)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
        .buttonStyle(PressStyle())
    }
}

struct HomeTiles: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let rank = store.rank()
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                tile(action: { router.push(.shop(nil)) }) {
                    label("Coins") { CoinIcon(size: 15) }
                    value(Format.number(store.state.wallet.coins))
                    sub("Spend in the shop")
                }
                tile(action: { router.select(.profile) }) {
                    label("First finds") { Image(systemName: "star.fill").font(.system(size: 12)).foregroundStyle(Palette.rare) }
                    value("\(store.state.firsts.count)")
                    sub("Places with your name")
                }
            }
            HomeRecapTile()
            tile(action: { router.push(.ranks) }) {
                HStack {
                    label(rank.current.name) { RankEmblem(tier: rank.tier, size: 18, color: Color(hex: rank.current.color)) }
                    Spacer()
                    Text("\(Format.number(rank.xp)) XP").font(.system(size: 11)).foregroundStyle(Palette.muted).monospacedDigit()
                }
                ProgressBar(value: rank.progress)
                sub(rank.next.map { "\(Format.number(rank.toNext)) XP to \($0.name)" } ?? "Top tier reached")
            }
        }
    }

    private func tile<Content: View>(action: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) { content() }
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
                .padding(14)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
        .buttonStyle(PressStyle())
    }

    private func label<Glyph: View>(_ text: String, @ViewBuilder icon: () -> Glyph) -> some View {
        HStack(spacing: 6) {
            icon()
            Text(text).labelStyle()
        }
    }

    private func value(_ text: String) -> some View {
        Text(text).font(.system(size: 26, weight: .bold)).tracking(-0.8).monospacedDigit().foregroundStyle(Palette.ink)
    }

    private func sub(_ text: String) -> some View {
        Text(text).font(.system(size: 11)).foregroundStyle(Palette.muted)
    }
}

/// Today's recap tile: numbered stops and totals, opens the Strava style recap.
struct HomeRecapTile: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let recap = RecapBuilder.today(store)
        Button { router.push(.recap) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.muted)
                        Text("Today").labelStyle()
                    }
                    Spacer()
                    Text(recap.date).font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
                HStack(spacing: 0) {
                    ForEach(Array(recap.stops.enumerated()), id: \.offset) { index, stop in
                        if index > 0 { Rectangle().fill(Palette.lineStrong).frame(height: 2) }
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(stop.first ? Palette.accent : Palette.ink, in: Circle())
                    }
                }
                Text("\(recap.stops.count) places, \(String(format: "%.1f", recap.km)) km, +\(Format.number(recap.coins)) coins")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
        .buttonStyle(PressStyle())
    }
}
