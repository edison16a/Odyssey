//
//  CheckInFlow.swift
//  Odyssey
//
//  The core of Odyssey. The + button opens straight onto the video camera:
//  one record button. Then say where you are (unless you came from a
//  place), and the video checks you in and adds to the place. The first
//  check-in of the day powers up the streak, then Adventure Complete shows
//  the rewards.
//  Ported from features/checkin/checkin.js.
//

import Foundation
import SwiftUI

struct CheckInFlow: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var placeID: String?

    private enum Stage { case record, pick, saving, power, adventure }

    @State private var stage: Stage = .record
    @State private var place: Place?
    @State private var clip: Clip?
    @State private var result: CheckInResult?
    @State private var saved: WalkthroughSaved?
    @State private var started = false
    /// True when this flow started the Live Activity or moved it on, so closing early ends it.
    @State private var ownsActivity = false

    /// The recorded video, kept until we know where it was taken.
    private struct Clip {
        var seconds: Int
        var video: URL?
        var simulated: Bool
    }

    var body: some View {
        ZStack {
            Palette.surface.ignoresSafeArea()
            switch stage {
            case .power:
                StreakPowerUpView(days: store.state.streak.days, milestone: result?.milestone) {
                    withAnimation(.easeInOut(duration: 0.3)) { stage = .adventure }
                }
                .transition(.opacity)
            case .adventure:
                if let place, let result {
                    AdventureCompleteView(place: place, result: result, video: saved?.result, payout: saved?.payout)
                        .transition(.opacity)
                }
            default:
                capture
            }
        }
        .onAppear(perform: begin)
        .onDisappear {
            // Closed before saving: do not leave the activity on the Lock Screen.
            if result == nil && ownsActivity { LiveActivityService.shared.end(immediately: true) }
            if result == nil, let video = clip?.video { try? FileManager.default.removeItem(at: video) }
        }
    }

    private var capture: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconButton(icon: "close", label: "Close") { router.dismissCover() }
                    .disabled(stage == .saving)
                Text(place?.name ?? "")
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 12)
            Group {
                switch stage {
                case .record:
                    WalkthroughRecorder(place: place) { seconds, video, simulated in
                        recorded(Clip(seconds: seconds, video: video, simulated: simulated))
                    }
                    // Coming from a place, the adventure page already laid out the rewards.
                    .overlay(alignment: .top) { if placeID == nil { CheckInRewardOverlay(place: place).padding(.top, 50) } }
                case .pick:
                    CheckInPickStep { chosen in choose(chosen) }
                default:
                    WalkthroughAnalyzing(seconds: clip?.seconds ?? 0, simulated: clip?.simulated ?? false)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .frame(maxHeight: .infinity)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        }
    }

    private func begin() {
        guard !started else { return }
        started = true
        if let placeID, let found = store.place(placeID) { attach(found) }
    }

    /// The place this check-in is for, with its Live Activity.
    private func attach(_ chosen: Place) {
        place = chosen
        if !LiveActivityService.shared.isRunning || LiveActivityService.shared.placeID != chosen.id {
            LiveActivityService.shared.start(place: chosen, store: store)
            ownsActivity = true
        }
    }

    /// The video is in: say where you are next, or save straight away.
    private func recorded(_ recording: Clip) {
        clip = recording
        if place != nil {
            save()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) { stage = .pick }
        }
    }

    /// Picked after recording.
    private func choose(_ chosen: Place) {
        attach(chosen)
        save()
    }

    /// Check in, add the video to the place, then show the power up or the rewards.
    private func save() {
        // A second tap during the transition would check in twice.
        guard let place, let clip, result == nil, stage != .saving else { return }
        LiveActivityService.shared.captured()
        ownsActivity = true
        withAnimation(.easeInOut(duration: 0.3)) { stage = .saving }
        let outcome = store.checkIn(place, caption: "Exploring \(place.name).", photoFile: nil, selfieFile: nil)
        result = outcome
        Task {
            // Too far from the place: the video is still kept, but it pays nothing either.
            saved = await WalkthroughSaved.save(place, seconds: clip.seconds, video: clip.video, simulated: clip.simulated,
                                                store: store, rewarded: !outcome.tooFar)
            LiveActivityService.shared.complete(coins: outcome.coins + (saved?.result.coins ?? 0), streak: store.state.streak.days)
            Haptics.success()
            withAnimation(.easeInOut(duration: 0.35)) { stage = outcome.streak ? .power : .adventure }
        }
    }
}

/// What this check-in will pay, over the top of the camera: the place, the coins and XP
/// from the same breakdown the wallet is credited from, and how long to film. Says so
/// plainly when you are too far for the check-in to pay.
struct CheckInRewardOverlay: View {
    @Environment(AppStore.self) private var store
    /// The place this check-in is for, or nil when it is picked after recording.
    var place: Place?

    var body: some View {
        let target = place ?? store.nearestPlace
        VStack(spacing: 3) {
            if let target {
                let rewards = store.checkInRewards(for: target)
                Text(place == nil ? "Nearest: \(target.name)" : target.name)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    if !rewards.fresh {
                        Text("Already explored today, no coins this time")
                    } else if !rewards.inReach {
                        Image(systemName: "location.fill").font(.system(size: 10, weight: .bold))
                        Text("Get within \(radius) m to earn coins")
                    } else {
                        CoinIcon(size: 13)
                        Text("+\(rewards.coins) coins").fontWeight(.heavy).monospacedDigit()
                        if rewards.totalXp > 0 {
                            Text("+\(rewards.totalXp) XP").fontWeight(.heavy).foregroundStyle(Color(hex: "#c9b6ff"))
                        }
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(rewards.earnable || !rewards.fresh ? .white : Palette.gold)
                if rewards.earnable { breakdown(rewards, demoJump: store.state.demoMode && target.id == "yc") }
            } else {
                HStack(spacing: 5) {
                    CoinIcon(size: 13)
                    Text("Earn up to \(upTo) coins").fontWeight(.heavy).monospacedDigit()
                }
                .font(.system(size: 12, weight: .semibold))
            }
            Text("Film up to \(Rewards.maxClipSeconds) seconds")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .padding(.horizontal, 24)
        .allowsHitTesting(false)
    }

    private var radius: Int { Int(Rewards.checkInRadius) }

    /// Each coin line and the XP, so you know exactly what this adventure pays.
    private func breakdown(_ rewards: CheckInRewards, demoJump: Bool) -> some View {
        VStack(spacing: 2) {
            ForEach(rewards.lines) { line in
                row(line.label, "+\(line.coins)", color: Palette.gold)
            }
            if rewards.xp > 0 { row("Check-in XP", "+\(rewards.xp) XP", color: Color(hex: "#c9b6ff")) }
            if rewards.videoXp > 0 { row("Video XP", "+\(rewards.videoXp) XP", color: Color(hex: "#c9b6ff")) }
            let rank = store.rank()
            if let next = rank.next, rank.toNext > 0 {
                Text(rewards.totalXp >= rank.toNext || demoJump ? "This ranks you up to \(next.name)"
                                                    : "\(rank.toNext - rewards.totalXp) XP after this to \(next.name)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 2)
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: 240)
    }

    private func row(_ label: String, _ value: String, color: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
            Spacer(minLength: 8)
            Text(value).fontWeight(.heavy).foregroundStyle(color).monospacedDigit()
        }
        .font(.system(size: 11, weight: .medium))
    }

    /// Best case with no place yet: a first explorer, recommended check-in on its own.
    private var upTo: Int { Rewards.checkIn.coins + Rewards.first.coins + Rewards.recommended.coins }
}
