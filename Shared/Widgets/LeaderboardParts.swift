//
//  LeaderboardParts.swift
//  Shared by the app and the widgets.
//
//  Pieces of the Leaderboard widget: medal colors, the stepped podium with
//  faces on gold, silver and bronze blocks, a ranked row and a little
//  podium glyph for the small size.
//

import Foundation
import SwiftUI

nonisolated enum Medal {
    static func color(_ rank: Int, light: Bool) -> Color {
        switch rank {
        case 1: return Palette.gold
        case 2: return Color(hex: light ? "#c3c9d4" : "#d3d8e2")
        case 3: return Color(hex: "#d4874e")
        default: return light ? Palette.surface3 : .white.opacity(0.14)
        }
    }

    /// Deep indigo for the Color style, with gold doing the shouting.
    static let indigo = Color(hex: "#17134a")
    static let indigoChip = Color(hex: "#2a2470")
}

/// Top three on stepped blocks, first in the middle with a crown.
struct LeaderPodium: View {
    var rows: [BoardEntry]
    var colors: WidgetColors
    var face: CGFloat = 36
    var tall: CGFloat = 48

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach([2, 1, 3], id: \.self) { rank in
                if let row = rows.first(where: { $0.rank == rank }) {
                    step(row, height: rank == 1 ? tall : rank == 2 ? tall * 0.7 : tall * 0.5)
                } else {
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func step(_ row: BoardEntry, height: CGFloat) -> some View {
        let medal = Medal.color(row.rank, light: !colors.dark)
        let size = row.rank == 1 ? face * 1.16 : face
        return VStack(spacing: 3) {
            if row.rank == 1 {
                Image(systemName: "crown.fill").font(.system(size: size * 0.3, weight: .bold)).foregroundStyle(Palette.gold)
            }
            WidgetFace(name: row.name, file: row.imageFile, size: size)
                .overlay(Circle().strokeBorder(medal, lineWidth: 2.5))
                .overlay {
                    if row.isMe { Circle().strokeBorder(.white, lineWidth: 1).padding(2.5) }
                }
            Text(row.firstName)
                .font(.system(size: 10.5, weight: .bold)).lineLimit(1).minimumScaleFactor(0.8)
                .foregroundStyle(row.isMe ? colors.accent : colors.text)
            Text("\(row.rank)")
                .font(.system(size: height * 0.46, weight: .black, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.78))
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(medal, in: UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }
}

/// One ranked line: place, face, name with a bar against the leader, and XP.
struct LeaderRow: View {
    var row: BoardEntry
    var top: Int
    var colors: WidgetColors

    var body: some View {
        let medal = Medal.color(row.rank, light: !colors.dark)
        HStack(spacing: 9) {
            Text("\(row.rank)")
                .font(.system(size: 13, weight: .black, design: .rounded)).monospacedDigit()
                .foregroundStyle(row.rank <= 3 ? Palette.ink.opacity(0.8) : colors.secondary)
                .frame(width: 22, height: 22)
                .background(row.rank <= 3 ? medal : .clear, in: Circle())
            WidgetFace(name: row.name, file: row.imageFile, size: 30)
                .overlay(Circle().strokeBorder(row.rank <= 3 ? medal : .clear, lineWidth: 2))
            VStack(alignment: .leading, spacing: 4) {
                Text(row.isMe ? "You" : row.name)
                    .font(.system(size: 13, weight: row.isMe ? .heavy : .bold)).lineLimit(1)
                    .foregroundStyle(colors.text)
                WidgetBar(value: Double(row.xp) / Double(max(1, top)), color: row.isMe ? colors.accent : medalBar,
                          track: colors.text.opacity(0.1), height: 4)
            }
            Text("\(row.xpText) XP")
                .font(.system(size: 12, weight: .heavy, design: .rounded)).monospacedDigit()
                .foregroundStyle(row.isMe ? colors.accent : colors.secondary)
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
        .background {
            if row.isMe {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.accent.opacity(colors.dark ? 0.16 : 0.12))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(colors.accent.opacity(0.55), lineWidth: 1))
            }
        }
    }

    private var medalBar: Color { colors.text.opacity(0.35) }
}

/// Three tiny steps, the middle one gold, for the small size's corner.
struct PodiumGlyph: View {
    var light: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            RoundedRectangle(cornerRadius: 2).fill(Medal.color(2, light: light)).frame(width: 7, height: 12)
            RoundedRectangle(cornerRadius: 2).fill(Medal.color(1, light: light)).frame(width: 7, height: 18)
            RoundedRectangle(cornerRadius: 2).fill(Medal.color(3, light: light)).frame(width: 7, height: 8)
        }
    }
}
