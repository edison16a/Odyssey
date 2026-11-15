//
//  WalkthroughScreens.swift
//  Odyssey
//
//  The first and last screens of a walkthrough: the simple rules and
//  sharing choices before recording, and what Odyssey learned afterwards
//  with the rewards it paid.
//

import Foundation
import SwiftUI

struct WalkthroughConsent: View {
    var place: Place
    @Binding var choice: WalkthroughChoice
    var onRecord: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "video.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Palette.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text("Record a walkthrough of \(place.name)")
                    .font(.system(size: 22, weight: .bold)).tracking(-0.4).foregroundStyle(Palette.ink)
                Text("Walk slowly from the entrance through the main space. 20 to 60 seconds is perfect.").mutedStyle(15)
                VStack(spacing: 8) {
                    check(on: $choice.publicOnly, title: "Only spaces open to the public", sub: "No back rooms, staff areas or private homes")
                    check(on: $choice.noCloseUps, title: "No close ups of people", sub: "Faces are blurred before anything is shared")
                }
                .padding(.top, 4)
                Text("What to share").labelStyle().padding(.top, 16).padding(.bottom, 2)
                toggle(on: $choice.share, title: "Share with Odyssey", sub: "Improves this place for everyone and earns +\(Rewards.video.xp) XP")
                toggle(on: $choice.guides, title: "Help build indoor guides",
                       sub: "With your permission, walkthroughs may one day power interactive guides for schools, businesses and venues")
                Button(action: onRecord) {
                    Label("Start recording", systemImage: "video.fill")
                }
                .buttonStyle(.pill(.accent, fill: true))
                .disabled(!choice.ready)
                .padding(.top, 8)
                Text(choice.ready ? "You can stop any time. The video stays on your phone unless you share it." : "Agree to both to start recording.")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func check(on: Binding<Bool>, title: String, sub: String) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) { on.wrappedValue.toggle() }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(on.wrappedValue ? Palette.accent : .white)
                    if !on.wrappedValue {
                        RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Palette.lineStrong, lineWidth: 2)
                    }
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(on.wrappedValue ? .white : .clear)
                }
                .frame(width: 24, height: 24)
                rowText(title, sub)
            }
            .padding(12)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(PressStyle())
    }

    private func toggle(on: Binding<Bool>, title: String, sub: String) -> some View {
        HStack(spacing: 12) {
            rowText(title, sub)
            Toggle("", isOn: on).labelsHidden().tint(Palette.accent)
        }
        .padding(12)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    private func rowText(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
            Text(sub).font(.system(size: 11)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
    }
}

struct WalkthroughResultView: View {
    @Environment(AppStore.self) private var store
    var place: Place
    var analysis: WalkthroughAnalysis
    var result: VideoResult?
    var payout: BountyPayout? = nil
    var shared: Bool
    var onDone: () -> Void
    @State private var confetti = false

    var body: some View {
        VStack(spacing: 8) {
            ScrollView {
                VStack(spacing: 8) {
                    GlobieView(mood: shared ? .ecstatic : .happy, form: store.streakTier.id, size: 96)
                    Text(shared ? "Walkthrough shared!" : "Saved on your phone")
                        .font(.system(size: 22, weight: .bold)).tracking(-0.4).foregroundStyle(Palette.ink).padding(.top, 6)
                    Text(shared ? "Thanks for showing explorers the inside of \(place.name)." : "Only you can see it. Share it any time from the place page.")
                        .mutedStyle(15).multilineTextAlignment(.center)
                    if let result, !result.already { rewards(result).padding(.top, 8) }
                    learned.padding(.top, 4)
                }
            }
            .scrollIndicators(.hidden)
            Button("Done", action: onDone).buttonStyle(.pill(.primary, fill: true))
        }
        .overlay { if confetti { ConfettiView(count: 60).ignoresSafeArea().allowsHitTesting(false) } }
        .onAppear { if shared { confetti = true } }
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
            if shared {
                Label("Odyssey will suggest \(place.name) to explorers who like \(likes).", systemImage: "hand.thumbsup")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.accentInk)
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }
}
