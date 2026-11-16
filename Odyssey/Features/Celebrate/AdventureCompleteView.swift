//
//  AdventureCompleteView.swift
//  Odyssey
//
//  Adventure Complete. Shown right after a check-in video saves: the place,
//  what you earned (coins, XP, the video bonus, the streak with Globie, the
//  first explorer bonus and your name on the place) and any rank up.
//  Ported from features/celebrate/adventure.js.
//

import Foundation
import SwiftUI

struct AdventureCompleteView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var place: Place
    var result: CheckInResult
    /// What the check-in video paid on top, when it saved.
    var video: VideoResult? = nil
    var payout: BountyPayout? = nil

    @State private var appeared = false
    @State private var confetti = false
    @State private var sharing = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    photoCard
                    Text(headline.title)
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.8)
                        .foregroundStyle(Palette.ink)
                        .padding(.top, 18)
                        .adventureRise(appeared, delay: 0.25)
                    Text(headline.sub)
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                        .adventureRise(appeared, delay: 0.33)
                    if result.fresh { AdventureRewards(result: result, video: video, payout: payout, appeared: appeared).padding(.top, 16) }
                    tierUp
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 16)
            }
            HStack(spacing: 8) {
                Button { sharing = true } label: { Label("Share", systemImage: "square.and.arrow.up") }
                    .buttonStyle(.pill(.soft))
                Button("Done") { router.dismissCover() }
                    .buttonStyle(.pill(.primary, fill: true))
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(Palette.surface)
        .overlay { if confetti { ConfettiView(count: result.first ? 110 : 70).ignoresSafeArea() } }
        .adventureMoments(result)
        .sheet(isPresented: $sharing) {
            AdventureShareSheet(place: place, first: result.first)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) { appeared = true }
            if result.fresh {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { confetti = true }
            }
        }
    }

    private var headline: (title: String, sub: String) {
        if result.tooFar {
            return ("Video saved", "You were \(Format.distance(result.rewards.metres)) from \(place.name). Check in within \(Int(Rewards.checkInRadius)) m to earn coins.")
        }
        if !result.fresh { return ("Saved", "You already explored \(place.name) today, so rewards were counted earlier.") }
        if result.first { return ("Adventure Complete!", "You are the first explorer at \(place.name). Your name stays on it for good.") }
        return ("Adventure Complete!", "You've explored somewhere new.")
    }

    private var photoCard: some View {
        GeometryReader { geo in
            PhotoView(path: place.photo)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                if result.first {
                    Label("First explorer", systemImage: "star.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Palette.rare, in: Capsule())
                        .padding(10)
                }
            }
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .containerRelativeFrame(.horizontal) { width, _ in width * 0.46 }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Palette.ink.opacity(0.18), radius: 20, y: 18)
        .rotationEffect(.degrees(appeared ? -3 : -9))
        .offset(y: appeared ? 0 : -24)
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
    }

    @ViewBuilder private var tierUp: some View {
        if result.fresh && result.rankAfter.tier > result.rankBefore.tier {
            let rank = result.rankAfter.current
            let article = ["A", "E", "I", "O", "U"].contains(String(rank.name.prefix(1))) ? "an" : "a"
            HStack(spacing: 12) {
                RankEmblem(tier: result.rankAfter.tier, size: 38, color: .white.opacity(0.25))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Rank up").font(.system(size: 11)).opacity(0.8)
                    Text("You are now \(article) \(rank.name)").font(.system(size: 15, weight: .bold))
                    Text(rank.perk).font(.system(size: 11)).opacity(0.8)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(14)
            .background(Color(hex: rank.color), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .padding(.top, 10)
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.9), value: appeared)
        }
    }
}

extension View {
    /// Fade and rise into place after a delay, like the mockup's rise-in.
    func adventureRise(_ shown: Bool, delay: Double) -> some View {
        opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.46).delay(delay), value: shown)
    }
}
