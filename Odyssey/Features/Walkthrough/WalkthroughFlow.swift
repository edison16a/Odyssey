//
//  WalkthroughFlow.swift
//  Odyssey
//
//  The optional walkthrough, offered after a check-in. First the explorer
//  agrees to a couple of simple rules and chooses what to share, then
//  records 5 to 60 seconds inside, then the phone reads a few frames and
//  the place's details improve. Sharing pays +50 XP and contribution
//  points; nothing is shared without the explorer saying so.
//  Ported from features/walkthrough/walkthrough.js.
//

import Foundation
import SwiftUI

struct WalkthroughFlow: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var placeID: String

    private enum Stage { case consent, record, analyzing, done }

    @State private var stage: Stage = .consent
    @State private var choice = WalkthroughChoice()
    @State private var seconds = 0
    @State private var simulated = false
    @State private var analysis: WalkthroughAnalysis?
    @State private var result: VideoResult?
    @State private var payout: BountyPayout?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconButton(icon: "close", label: "Close") { router.dismissCover() }
                Text("Walkthrough").font(.system(size: 17, weight: .bold)).frame(maxWidth: .infinity)
                Text("+\(Rewards.video.xp) XP")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 40, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 12)
            if let place = store.place(placeID) {
                content(place)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .frame(maxHeight: .infinity)
            } else {
                Spacer()
            }
        }
        .background(Palette.surface)
    }

    @ViewBuilder private func content(_ place: Place) -> some View {
        switch stage {
        case .consent:
            WalkthroughConsent(place: place, choice: $choice) {
                withAnimation(.easeInOut(duration: 0.3)) { stage = .record }
            }
        case .record:
            WalkthroughRecorder(place: place) { length, video, isSimulated in
                seconds = length
                simulated = isSimulated
                withAnimation(.easeInOut(duration: 0.3)) { stage = .analyzing }
                Task { await analyze(place, video: video) }
            }
        case .analyzing:
            VStack(spacing: 8) {
                Spacer()
                GlobieView(mood: .happy, form: store.streakTier.id, size: 96)
                Text("Watching your walkthrough").font(.system(size: 22, weight: .bold)).tracking(-0.4).padding(.top, 6)
                Text("\(seconds) seconds, 4 frames\(simulated ? ", simulated walk" : "")").mutedStyle(15)
                WalkthroughDots().padding(.top, 8)
                Spacer()
            }
        case .done:
            if let analysis {
                WalkthroughResultView(place: place, analysis: analysis, result: result, payout: payout, shared: choice.share) {
                    router.dismissCover()
                }
            }
        }
    }

    /// Read the frames, wait at least a moment so it never flashes past, then save.
    private func analyze(_ place: Place, video: URL?) async {
        let start = Date()
        let photos = simulated ? WalkthroughRecorder.shots(for: place) : []
        let found = await WalkthroughAnalyzer.analyze(place: place, video: video, photos: photos, store: store)
        let left = 1.6 - Date().timeIntervalSince(start)
        if left > 0 { try? await Task.sleep(for: .seconds(left)) }
        if choice.share {
            let saved = store.addVideo(place, seconds: seconds, insights: found.insights)
            Cloud.shared.recordWalkthrough(place, seconds: seconds, video: simulated ? nil : video,
                                           insights: found.insights, points: saved.points)
            result = saved
            if !saved.already { payout = store.bountyPayout(for: place) }
        } else {
            store.update { s in s.placeInsights[place.id] = found.insights }
        }
        analysis = found
        withAnimation(.easeInOut(duration: 0.3)) { stage = .done }
        if let video { try? FileManager.default.removeItem(at: video) }
    }
}

/// What the explorer agreed to and chose to share.
struct WalkthroughChoice {
    var publicOnly = false
    var noCloseUps = false
    var share = true
    var guides = false

    var ready: Bool { publicOnly && noCloseUps }
}

/// Three pulsing dots while the phone reads the video.
struct WalkthroughDots: View {
    @State private var on = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 8, height: 8)
                    .scaleEffect(on ? 1 : 0.6)
                    .opacity(on ? 1 : 0.4)
                    .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15), value: on)
            }
        }
        .onAppear { on = true }
    }
}
