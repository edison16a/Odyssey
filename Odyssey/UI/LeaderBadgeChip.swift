//
//  LeaderBadgeChip.swift
//  Odyssey
//
//  The small crown or trophy pill that marks a top 10 or top 100 explorer,
//  on their leaderboard row and next to their rank on the profile.
//

import Foundation
import SwiftUI

struct LeaderBadgeChip: View {
    var badge: Badge
    var compact = false

    private var gold: Bool { badge.id == "top-10" }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: gold ? "crown.fill" : "trophy.fill").font(.system(size: compact ? 9 : 10, weight: .bold))
            Text(badge.name).font(.system(size: compact ? 10 : 11, weight: .heavy))
        }
        .foregroundStyle(gold ? Color(hex: "#5a3d00") : .white)
        .padding(.horizontal, 8)
        .frame(height: compact ? 20 : 24)
        .background(gold ? Color(hex: "#f2b21b") : Color(hex: "#2b59ff"), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.5), lineWidth: 1))
    }
}
