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
            saved = await WalkthroughSaved.save(place, seconds: clip.seconds, video: clip.video, simulated: clip.simulated, store: store)
            LiveActivityService.shared.complete(coins: outcome.coins + (saved?.result.coins ?? 0), streak: store.state.streak.days)
            Haptics.success()
            withAnimation(.easeInOut(duration: 0.35)) { stage = outcome.streak ? .power : .adventure }
        }
    }
}
