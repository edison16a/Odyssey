//
//  QuestWidgetView.swift
//  Shared by the app and the widgets.
//
//  Quest: the rarest open quest near you, themed by its rarity. Mythical
//  is gold, epic purple, rare blue and common green, with a big flag and a
//  few sparkles behind the title, the reward and how long is left.
//

import Foundation
import SwiftUI

struct QuestWidgetView: View {
    var size: WidgetSize
    var snapshot: WidgetSnapshot
    var prefs: WidgetPrefs

    private var style: WidgetStyle { prefs.style(for: .quest) }
    private var colors: WidgetColors { WidgetLook.colors(.quest, style, snapshot) }
    private var vivid: Bool { style == .vivid }

    var body: some View {
        if let quest = snapshot.quest {
            switch size {
            case .rectangular, .circular, .inline:
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill").font(.system(size: 10, weight: .bold))
                        Text(quest.rarity + " quest").font(.system(size: 12, weight: .semibold))
                    }
                    .opacity(0.85)
                    Text(quest.title).font(.system(size: 14, weight: .bold)).lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            case .small:
                ZStack(alignment: .bottomTrailing) {
                    motif(quest, flag: 70)
                    VStack(alignment: .leading, spacing: 6) {
                        rarity(quest)
                        Text(quest.title).font(.system(size: 15, weight: .heavy)).tracking(-0.2).lineLimit(4).foregroundStyle(colors.text)
                        Spacer(minLength: 0)
                        WidgetCoins(amount: quest.coins, color: colors.text, background: colors.chip)
                        countdown(quest)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            default:
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        rarity(quest)
                        Text(quest.title).font(.system(size: 17, weight: .heavy)).tracking(-0.3).lineLimit(2).foregroundStyle(colors.text)
                        Text(quest.placeName).font(.system(size: 12, weight: .medium)).foregroundStyle(colors.secondary)
                        Spacer(minLength: 0)
                        HStack(spacing: 6) {
                            WidgetCoins(amount: quest.coins, color: colors.text, background: colors.chip)
                            Text("+\(quest.xp) XP").font(.system(size: 12, weight: .heavy)).foregroundStyle(colors.text)
                            countdown(quest)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    badge(quest)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                WidgetLabel(text: "Quests", symbol: "flag.fill", color: colors.secondary)
                Spacer()
                Text("Every quest nearby is done. New ones land tomorrow.")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(colors.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func tint(_ quest: QuestSnapshot) -> Color { Color(hex: quest.colorHex) }

    private func rarity(_ quest: QuestSnapshot) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "flag.fill").font(.system(size: 9, weight: .bold))
            Text(quest.rarity.uppercased()).font(.system(size: 10, weight: .heavy)).tracking(0.5)
        }
        .foregroundStyle(vivid ? tint(quest) : .white)
        .padding(.horizontal, 7)
        .frame(height: 20)
        .background(vivid ? Color.white : tint(quest), in: Capsule())
    }

    private func countdown(_ quest: QuestSnapshot) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill").font(.system(size: 9, weight: .bold))
            Text(quest.ends).font(.system(size: 10.5, weight: .bold)).lineLimit(1)
        }
        .foregroundStyle(colors.text)
        .padding(.horizontal, 7)
        .frame(height: 20)
        .background(vivid ? Color.black.opacity(0.18) : colors.chip, in: Capsule())
    }

    /// A big tilted flag and a few sparkles behind the words.
    private func motif(_ quest: QuestSnapshot, flag: CGFloat) -> some View {
        let ink = vivid ? Color.white : tint(quest)
        return ZStack(alignment: .bottomTrailing) {
            Image(systemName: "flag.fill")
                .font(.system(size: flag, weight: .black))
                .foregroundStyle(ink.opacity(vivid ? 0.16 : 0.12))
                .rotationEffect(.degrees(12))
                .offset(x: 14, y: 12)
            Image(systemName: "sparkle")
                .font(.system(size: flag * 0.24, weight: .bold))
                .foregroundStyle(ink.opacity(0.4))
                .offset(x: -flag * 0.9, y: -flag * 1.15)
            Image(systemName: "sparkle")
                .font(.system(size: flag * 0.16, weight: .bold))
                .foregroundStyle(ink.opacity(0.3))
                .offset(x: -flag * 0.15, y: -flag * 1.5)
        }
    }

    /// The round flag badge on the medium size.
    private func badge(_ quest: QuestSnapshot) -> some View {
        let ink = vivid ? Color.white : tint(quest)
        return ZStack {
            Circle().fill(ink.opacity(vivid ? 0.18 : 0.12))
            Circle().strokeBorder(ink.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
            Image(systemName: "flag.fill").font(.system(size: 34, weight: .black)).foregroundStyle(ink)
            Image(systemName: "sparkle").font(.system(size: 14, weight: .bold)).foregroundStyle(ink.opacity(0.7))
                .offset(x: 30, y: -30)
        }
        .frame(width: 92, height: 92)
    }
}
