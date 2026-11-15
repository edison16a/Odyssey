//
//  AdventureRewards.swift
//  Odyssey
//
//  The list of what a check-in paid: coins, the first explorer bonus, any
//  quest, the bonus for a place Explore recommended, experience, what the
//  video added and the streak with Globie. Each row rises in after the one before, and the
//  numbers count up.
//

import Foundation
import SwiftUI

struct AdventureRewards: View {
    @Environment(AppStore.self) private var store
    var result: CheckInResult
    var video: VideoResult? = nil
    var payout: BountyPayout? = nil
    var appeared: Bool

    private struct Row: Identifiable {
        enum Glyph { case coin, icon(String, Color), globie(GlobieMood) }
        var id: String
        var glyph: Glyph
        var label: String
        var value: Int
        var prefix: String
        var suffix: String
        var valueColor: Color = Palette.ink
        /// Shown as is instead of counting up, for cash.
        var text: String? = nil
    }

    var body: some View {
        let rows = makeRows()
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 { Divider().overlay(Palette.line) }
                HStack(spacing: 12) {
                    glyph(row.glyph)
                        .frame(width: 32, height: 32)
                        .background(isStreak(row) ? Color(hex: "#eef3ff") : .white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Text(row.label).font(.system(size: 15)).foregroundStyle(Palette.ink)
                    Spacer(minLength: 8)
                    Group {
                        if let text = row.text {
                            Text(text)
                        } else {
                            CountUpText(value: row.value, from: row.id == "streak" ? max(0, row.value - 1) : 0, prefix: row.prefix, suffix: row.suffix)
                        }
                    }
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(row.valueColor)
                }
                .padding(.vertical, 9)
                .adventureRise(appeared, delay: 0.42 + Double(index) * 0.1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    private func isStreak(_ row: Row) -> Bool { row.id == "streak" }

    private func makeRows() -> [Row] {
        var rows: [Row] = [Row(id: "checkin", glyph: .coin, label: "Check-in reward", value: Rewards.checkIn.coins, prefix: "+", suffix: " coins")]
        if result.first {
            rows.append(Row(id: "first", glyph: .icon("star.fill", Palette.rare), label: "First explorer bonus",
                            value: Rewards.first.coins, prefix: "+", suffix: " coins", valueColor: Palette.rare))
        }
        if let quest = result.quest {
            let label = "\(store.questRarity(quest).label) quest, \(quest.multiplier)x"
            rows.append(Row(id: "quest", glyph: .icon("flag.fill", Palette.gold), label: label,
                            value: quest.coins * quest.multiplier, prefix: "+", suffix: " coins"))
        }
        if result.recommended {
            rows.append(Row(id: "picked", glyph: .icon("sparkles", Palette.gold), label: "Recommended pick bonus",
                            value: Rewards.recommended.coins, prefix: "+", suffix: " coins"))
        }
        rows.append(Row(id: "xp", glyph: .icon("bolt.fill", Palette.accent), label: "Experience", value: result.xp, prefix: "+", suffix: " XP"))
        if let video, !video.already {
            rows.append(Row(id: "video", glyph: .icon("video.fill", Palette.accent), label: "Video bonus", value: video.xp, prefix: "+", suffix: " XP"))
            if video.coins > 0 {
                rows.append(Row(id: "video-quest", glyph: .icon("flag.fill", Palette.gold), label: "Video quest", value: video.coins, prefix: "+", suffix: " coins"))
            }
        }
        if let payout, payout.amount > 0 {
            rows.append(Row(id: "bounty", glyph: .icon("dollarsign", Palette.rare), label: "\(payout.bounty.sponsor) bounty",
                            value: 0, prefix: "", suffix: "", text: "+" + Format.money(payout.amount)))
        }
        let days = store.state.streak.days
        let mood: GlobieMood = result.streak && StreakTiers.milestones.contains(days) ? .ecstatic : .happy
        rows.append(Row(id: "streak", glyph: .globie(mood), label: result.streak ? "Streak extended" : "Streak kept",
                        value: days, prefix: "", suffix: " days"))
        return rows
    }

    @ViewBuilder private func glyph(_ glyph: Row.Glyph) -> some View {
        switch glyph {
        case .coin:
            CoinIcon(size: 20)
        case .icon(let name, let color):
            Image(systemName: name).font(.system(size: 15, weight: .semibold)).foregroundStyle(color)
        case .globie(let mood):
            GlobieView(mood: mood, form: store.streakTier.id, size: 28, animated: false)
        }
    }
}
