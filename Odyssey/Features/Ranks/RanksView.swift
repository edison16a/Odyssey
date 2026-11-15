//
//  RanksView.swift
//  Odyssey
//
//  The rank ladder. All six tiers top to bottom with their badge color, XP
//  threshold, what each unlocks and how rare it is, so the whole climb from
//  Explorer to Atlas reads at a glance. Each tier has its own emblem, and
//  the current one sits on a white disc so it reads on its own color.
//  Ported from ranks.js.
//

import Foundation
import SwiftUI

struct RanksView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var appeared = false

    var body: some View {
        let rank = store.rank()
        let share = store.seed.rankShare
        VStack(spacing: 0) {
            NavHeader(title: "Ranks", back: { router.pop() }) {
                IconButton(icon: "trophy", label: "Leaderboards") { router.push(.leaderboard) }
            }
            ScrollView {
                VStack(spacing: 0) {
                    hero(rank, share: share)
                    VStack(spacing: 10) {
                        ForEach(Array(store.seed.ranks.enumerated()).reversed(), id: \.offset) { index, tier in
                            rung(index: index, tier: tier, current: rank.tier, share: share)
                        }
                    }
                    .padding(.horizontal, 20)
                    Text("XP comes from check-ins, quests and walkthroughs. Ranks are yours for life, and leaderboards reset each season.")
                        .font(.system(size: 11)).foregroundStyle(Palette.faint)
                        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 30)
                }
            }
        }
        .background(Palette.surface)
        .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { appeared = true } }
    }

    private func pct(_ share: [Double], _ tier: Int) -> String {
        ProfileTravel.pct(share.indices.contains(tier) ? share[tier] : 100)
    }

    private func hero(_ rank: RankInfo, share: [Double]) -> some View {
        VStack(spacing: 2) {
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .strokeBorder(.white.opacity(0.16 - Double(i) * 0.045), lineWidth: 1)
                        .frame(width: 146 + CGFloat(i) * 40, height: 146 + CGFloat(i) * 40)
                        .scaleEffect(appeared ? 1 : 0.7)
                }
                Circle()
                    .fill(.white)
                    .frame(width: 136, height: 136)
                    .shadow(color: .black.opacity(0.22), radius: 18, y: 12)
                RankEmblem(tier: rank.tier, size: 104)
            }
            .frame(height: 200)
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)
            .padding(.bottom, 4)
            Text("Your rank").font(.system(size: 11, weight: .bold)).tracking(0.9).textCase(.uppercase).opacity(0.75)
            Text(rank.current.name).font(.system(size: 30, weight: .heavy)).tracking(-0.9)
            Text("\(rank.xp) XP, top \(pct(share, rank.tier))% of Explorers").font(.system(size: 13)).opacity(0.85)
            if let next = rank.next {
                VStack(spacing: 8) {
                    ProgressBar(value: rank.progress, color: Color(hex: next.color), track: .white.opacity(0.25))
                    HStack(spacing: 4) {
                        Text("\(rank.toNext) XP to")
                        RankEmblem(tier: rank.tier + 1, size: 16, inverse: true)
                        Text(next.name)
                    }
                    .font(.system(size: 11, weight: .semibold))
                }
                .padding(.top, 14)
            }
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .background {
            ZStack {
                Color(hex: rank.current.color)
                RankRays(color: .white, count: 12).opacity(0.07)
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func rung(index: Int, tier: Rank, current: Int, share: [Double]) -> some View {
        let color = Color(hex: tier.color)
        let isCurrent = index == current
        return HStack(spacing: 14) {
            RankEmblem(tier: index, size: 52).opacity(index > current ? 0.55 : 1)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(tier.name).font(.system(size: 17, weight: .heavy)).foregroundStyle(color)
                    if isCurrent {
                        Text("You").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 8).frame(height: 22).background(color, in: Capsule())
                    }
                    if index < current {
                        Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 18, height: 18).background(color, in: Circle())
                    }
                }
                Text(tier.perk).font(.system(size: 13)).foregroundStyle(Palette.muted)
                Text("\(tier.xp) XP, top \(pct(share, index))%").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.faint)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isCurrent ? Palette.surface : Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(isCurrent ? color : .clear, lineWidth: 2))
        .shadow(color: .black.opacity(isCurrent ? 0.08 : 0), radius: 10, y: 6)
    }
}
