//
//  WalkthroughScreens.swift
//  Odyssey
//
//  The last screen of a place video: what Odyssey learned and the
//  rewards it paid.
//

import Foundation
import SwiftUI

struct WalkthroughResultView: View {
    @Environment(AppStore.self) private var store
    var place: Place
    var analysis: WalkthroughAnalysis
    var result: VideoResult?
    var payout: BountyPayout? = nil
    var onDone: () -> Void
    @State private var confetti = false

    var body: some View {
        VStack(spacing: 8) {
            ScrollView {
                VStack(spacing: 8) {
                    GlobieView(mood: .ecstatic, form: store.streakTier.id, size: 96)
                    Text("Video saved!")
                        .font(.system(size: 22, weight: .bold)).tracking(-0.4).foregroundStyle(Palette.ink).padding(.top, 6)
                    Text("Thanks for showing explorers \(place.name).")
                        .mutedStyle(15).multilineTextAlignment(.center)
                    if let result, !result.already { rewards(result).padding(.top, 8) }
                    learned.padding(.top, 4)
                }
            }
            .scrollIndicators(.hidden)
            Button("Done", action: onDone).buttonStyle(.pill(.primary, fill: true))
        }
        .overlay { if confetti { ConfettiView(count: 60).ignoresSafeArea().allowsHitTesting(false) } }
        .onAppear { confetti = true }
    }

    private func rewards(_ result: VideoResult) -> some View {
        VStack(spacing: 0) {
            rewardRow("bolt.fill", Palette.accent, "Bonus XP", "+\(result.xp) XP")
            Divider().overlay(Palette.line)
            rewardRow("trophy.fill", Palette.ink, "Contribution points", "+\(result.points)")
            if result.coins > 0 {
                Divider().overlay(Palette.line)
                rewardRow("flag.fill", Palette.gold, "Quest complete", "+\(result.coins) coins")
            }
            if let payout, payout.amount > 0 {
                Divider().overlay(Palette.line)
                rewardRow("dollarsign", Palette.rare, "\(payout.bounty.sponsor) bounty", "+" + Format.money(payout.amount))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    private func rewardRow(_ icon: String, _ color: Color, _ label: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(label).font(.system(size: 15)).foregroundStyle(Palette.ink)
            Spacer()
            Text(value).font(.system(size: 15, weight: .heavy)).foregroundStyle(Palette.ink)
        }
        .padding(.vertical, 9)
    }

    private var learned: some View {
        let insights = analysis.insights
        let tags = Array(([insights.vibe].compactMap { $0 } + (insights.tags ?? [])).prefix(4))
        let likes = insights.vibe == "quiet" ? "quiet places" : insights.vibe == "lively" ? "lively places" : (insights.tags?.first ?? "places like this")
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("What Odyssey learned").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                Spacer()
                Tag(text: "On device", icon: "check")
            }
            Text(insights.summary ?? "").font(.system(size: 13)).foregroundStyle(Palette.ink)
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { Tag(text: $0.capitalized, tone: .accent) }
            }
            if !analysis.highlights.isEmpty {
                Text(analysis.highlights.prefix(3).joined(separator: ", ").capitalized).mutedStyle(13)
            }
            Label("Odyssey will suggest \(place.name) to explorers who like \(likes).", systemImage: "hand.thumbsup")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.accentInk)
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }
}
