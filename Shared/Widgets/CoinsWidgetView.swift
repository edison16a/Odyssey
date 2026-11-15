//
//  CoinsWidgetView.swift
//  Shared by the app and the widgets.
//
//  Coins and Rank: your balance in big type with a little stack of coins,
//  what the next check-in pays and a ring toward your next rank. The Color
//  style sits on warm gold.
//

import Foundation
import SwiftUI

struct CoinsWidgetView: View {
    var size: WidgetSize
    var snapshot: WidgetSnapshot
    var prefs: WidgetPrefs

    private var style: WidgetStyle { prefs.style(for: .coins) }
    private var colors: WidgetColors { WidgetLook.colors(.coins, style, snapshot) }
    private var balance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: snapshot.coins)) ?? "\(snapshot.coins)"
    }
    private var ringColor: Color { style == .vivid ? Palette.ink : Color(hex: snapshot.rankColorHex) }
    private var rankLine: String {
        snapshot.nextRankName.map { "Next, \($0)" } ?? "Top rank"
    }

    var body: some View {
        switch size {
        case .circular:
            Gauge(value: min(1, max(0, snapshot.rankProgress))) {
                Image(systemName: "circle.hexagongrid.fill")
            } currentValueLabel: {
                Text(snapshot.coins >= 10000 ? "\(snapshot.coins / 1000)k" : String(format: "%.1fk", Double(snapshot.coins) / 1000))
                    .font(.system(size: 14, weight: .heavy))
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .rectangular, .inline:
            VStack(alignment: .leading, spacing: 2) {
                Text("\(balance) coins").font(.system(size: 15, weight: .bold))
                Text(snapshot.nextRankName.map { "\(snapshot.rankName), next \($0)" } ?? snapshot.rankName)
                    .font(.system(size: 12, weight: .medium)).opacity(0.8).lineLimit(1)
                WidgetBar(value: snapshot.rankProgress, color: .primary, track: .primary.opacity(0.25), height: 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            card
        }
    }

    private var card: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                WidgetLabel(text: "Coins", symbol: "circle.hexagongrid.fill", color: colors.secondary)
                Spacer(minLength: 0)
                Text(balance)
                    .font(.system(size: 32, weight: .heavy)).tracking(-1).monospacedDigit()
                    .minimumScaleFactor(0.7).lineLimit(1).foregroundStyle(colors.text)
                Text("+100 next check-in")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(style == .vivid ? Palette.ink.opacity(0.7) : Palette.success)
                if prefs.showNextRank {
                    HStack(spacing: 7) {
                        ring
                        VStack(alignment: .leading, spacing: 0) {
                            Text(snapshot.rankName).font(.system(size: 11, weight: .heavy)).foregroundStyle(colors.text)
                            Text(rankLine).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(colors.secondary)
                        }
                        .lineLimit(1)
                    }
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            WidgetCoinStack(width: 40)
                .rotationEffect(.degrees(-8))
                .shadow(color: .black.opacity(style == .vivid ? 0.12 : 0.08), radius: 3, y: 2)
        }
    }

    /// Progress toward the next rank, in the rank's color.
    private var ring: some View {
        ZStack {
            Circle().stroke(colors.chip, lineWidth: 4)
            Circle()
                .trim(from: 0, to: CGFloat(min(1, max(0.02, snapshot.rankProgress))))
                .stroke(ringColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "diamond.fill").font(.system(size: 7, weight: .bold)).foregroundStyle(ringColor)
        }
        .frame(width: 24, height: 24)
    }
}
