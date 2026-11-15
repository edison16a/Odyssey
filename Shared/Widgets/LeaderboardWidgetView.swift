//
//  LeaderboardWidgetView.swift
//  Shared by the app and the widgets.
//
//  Leaderboard: where you stand this week. Small shows your city rank in
//  big type with a little podium, medium puts your friends' top three on
//  gold, silver and bronze steps next to your own place, and large lists
//  the top five with XP bars and your city standing underneath. The Color
//  style is deep indigo with gold.
//

import Foundation
import SwiftUI

struct LeaderboardWidgetView: View {
    var size: WidgetSize
    var snapshot: WidgetSnapshot
    var prefs: WidgetPrefs

    private var style: WidgetStyle { prefs.style(for: .leaderboard) }
    private var colors: WidgetColors { WidgetLook.colors(.leaderboard, style, snapshot) }
    private var rows: [BoardEntry] { snapshot.boardRows }
    private var me: BoardEntry? { snapshot.myBoardRow }
    private var headline: String {
        if let standing = snapshot.standing { return "#\(standing.position)" }
        return "#\(me?.rank ?? 1)"
    }
    private var whereLine: String {
        if let standing = snapshot.standing { return "in \(standing.scope)" }
        return "among friends"
    }

    var body: some View {
        switch size {
        case .rectangular, .inline, .circular: accessory
        case .medium: medium
        case .large: large
        case .small: small
        }
    }

    private var accessory: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: "trophy.fill").font(.system(size: 12, weight: .bold))
                Text("\(headline) \(whereLine)").font(.system(size: 15, weight: .heavy)).lineLimit(1)
            }
            if let standing = snapshot.standing {
                Text(standing.pctText.capitalizedFirst + " of explorers").font(.system(size: 12, weight: .medium)).opacity(0.8)
            }
            if let me {
                Text("#\(me.rank) among friends, \(me.xpText) XP").font(.system(size: 12, weight: .medium)).opacity(0.8).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                WidgetLabel(text: "This week", symbol: "trophy.fill", color: colors.secondary)
                Spacer(minLength: 4)
                PodiumGlyph(light: !colors.dark)
            }
            Spacer(minLength: 2)
            Text(headline)
                .font(.system(size: 46, weight: .black, design: .rounded)).monospacedDigit()
                .minimumScaleFactor(0.6).lineLimit(1)
                .foregroundStyle(colors.accent)
            Text(whereLine).font(.system(size: 14, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.8)
                .foregroundStyle(colors.text)
            pill(snapshot.standing.map { $0.pctText.capitalizedFirst } ?? "\(me?.xpText ?? "0") XP")
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                WidgetLabel(text: "Leaderboard", symbol: "trophy.fill", color: colors.secondary)
                Spacer(minLength: 2)
                Text("You").font(.system(size: 12, weight: .bold)).foregroundStyle(colors.secondary)
                Text("#\(me?.rank ?? 1)")
                    .font(.system(size: 36, weight: .black, design: .rounded)).monospacedDigit()
                    .foregroundStyle(colors.accent)
                Text("among friends").font(.system(size: 12, weight: .heavy)).foregroundStyle(colors.text)
                Spacer(minLength: 4)
                pill(snapshot.standing.map { "#\($0.position) in \($0.scope)" } ?? "\(me?.xpText ?? "0") XP")
            }
            .frame(width: 112, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .leading)
            LeaderPodium(rows: rows, colors: colors, face: 34, tall: 46)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private var large: some View {
        let top = rows.map(\.xp).max() ?? 1
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                WidgetLabel(text: "Leaderboard", symbol: "trophy.fill", color: colors.secondary)
                Spacer()
                pill("This week")
            }
            .padding(.bottom, 2)
            ForEach(rows.prefix(5)) { row in
                LeaderRow(row: row, top: top, colors: colors)
            }
            Spacer(minLength: 0)
            if let standing = snapshot.standing { standingCard(standing) }
        }
    }

    /// Your best area standing with a ring showing how many explorers you are ahead of.
    private func standingCard(_ standing: StandingSnapshot) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(colors.text.opacity(0.12), lineWidth: 5)
                Circle().trim(from: 0, to: max(0.04, min(1, 1 - standing.pct / 100)))
                    .stroke(colors.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "building.2.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(colors.accent)
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text("#\(standing.position) in \(standing.scope)").font(.system(size: 15, weight: .heavy)).lineLimit(1)
                    .foregroundStyle(colors.text)
                Text(standing.pctText.capitalizedFirst + " of explorers there").font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(colors.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(colors.chip, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.8)
            .foregroundStyle(colors.dark ? Palette.ink : .white)
            .padding(.horizontal, 8).frame(height: 20)
            .background(colors.accent, in: Capsule())
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
