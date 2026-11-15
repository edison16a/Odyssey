//
//  AdventureCompleteView.swift
//  Odyssey
//
//  Adventure Complete. Shown right after a check-in posts: the photo pair,
//  what you earned (coins, XP, the streak with Globie, the first explorer
//  bonus and your name on the place), any rank up, then the optional
//  walkthrough video that pays bonus XP.
//  Ported from features/celebrate/adventure.js.
//

import Foundation
import SwiftUI
import UIKit

struct AdventureCompleteView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var place: Place
    var result: CheckInResult
    var placeImage: UIImage?
    var selfieImage: UIImage?

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
                    if result.fresh { AdventureRewards(result: result, appeared: appeared).padding(.top, 16) }
                    tierUp
                    walkOffer
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
            AdventureShareSheet(place: place, first: result.first, placeImage: placeImage, selfieImage: selfieImage)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) { appeared = true }
            if result.fresh {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { confetti = true }
            }
        }
    }

    private var headline: (title: String, sub: String) {
        if !result.fresh { return ("Posted", "You already explored \(place.name) today, so rewards were counted earlier.") }
        if result.first { return ("Adventure Complete!", "You are the first explorer at \(place.name). Your name stays on it for good.") }
        return ("Adventure Complete!", "You've explored somewhere new.")
    }

    private var photoCard: some View {
        GeometryReader { geo in
            Group {
                if let placeImage { Image(uiImage: placeImage).resizable().scaledToFill() } else { PhotoView(path: place.photo) }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .overlay(alignment: .topLeading) {
                if let selfieImage {
                    Image(uiImage: selfieImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width * 0.34, height: geo.size.width * 0.34 * 4 / 3)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white, lineWidth: 2.5))
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 4)
                        .padding(10)
                }
            }
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

    /// The optional walkthrough offer, the bonus path.
    @ViewBuilder private var walkOffer: some View {
        let done = (store.state.videos[place.id] ?? []).contains { $0.date == Format.today() }
        if !done {
            let quest = store.questAt(place, kinds: ["walk"])
            let xp = Rewards.video.xp + (quest.map { $0.xp * $0.multiplier } ?? 0)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Palette.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Want bonus XP?").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                        Text("Record a short interior walkthrough to help improve place information.")
                            .font(.system(size: 13)).foregroundStyle(Palette.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Text("+\(xp) XP").font(.system(size: 15, weight: .heavy)).foregroundStyle(Palette.accent)
                }
                Button { router.present(.walkthrough(placeID: place.id)) } label: {
                    Label("Record walkthrough", systemImage: "video.fill")
                }
                .buttonStyle(.pill(.accent, fill: true))
            }
            .padding(14)
            .background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .padding(.top, 12)
            .adventureRise(appeared, delay: 1.0)
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
