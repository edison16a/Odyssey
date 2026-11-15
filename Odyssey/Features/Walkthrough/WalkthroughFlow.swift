//
//  WalkthroughFlow.swift
//  Odyssey
//
//  A video of a place, opened from a place screen. It opens straight onto
//  the recorder, then the phone reads a few frames, the place's details
//  improve and the video pays its XP and contribution points.
//  The + button uses the same recorder and saving through CheckInFlow.
//  Ported from features/walkthrough/walkthrough.js.
//

import Foundation
import SwiftUI

struct WalkthroughFlow: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var placeID: String

    private enum Stage { case record, analyzing, done }

    @State private var stage: Stage = .record
    @State private var seconds = 0
    @State private var simulated = false
    @State private var saved: WalkthroughSaved?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconButton(icon: "close", label: "Close") { router.dismissCover() }
                Text(store.place(placeID)?.name ?? "Video").font(.system(size: 17, weight: .bold)).lineLimit(1).frame(maxWidth: .infinity)
                Color.clear.frame(width: 40, height: 40)
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
        case .record:
            WalkthroughRecorder(place: place) { length, video, isSimulated in
                seconds = length
                simulated = isSimulated
                withAnimation(.easeInOut(duration: 0.3)) { stage = .analyzing }
                Task {
                    saved = await WalkthroughSaved.save(place, seconds: length, video: video, simulated: isSimulated, store: store)
                    withAnimation(.easeInOut(duration: 0.3)) { stage = .done }
                }
            }
        case .analyzing:
            WalkthroughAnalyzing(seconds: seconds, simulated: simulated)
        case .done:
            if let saved {
                WalkthroughResultView(place: place, analysis: saved.analysis, result: saved.result, payout: saved.payout) {
                    router.dismissCover()
                }
            }
        }
    }
}

/// What saving a video found and paid.
struct WalkthroughSaved {
    var analysis: WalkthroughAnalysis
    var result: VideoResult
    var payout: BountyPayout?

    /// Read the frames, wait at least a moment so it never flashes past, then save the
    /// contribution locally and to the cloud, and delete the local file.
    static func save(_ place: Place, seconds: Int, video: URL?, simulated: Bool, store: AppStore, rewarded: Bool = true) async -> WalkthroughSaved {
        let start = Date()
        let photos = simulated ? WalkthroughRecorder.shots(for: place) : []
        let found = await WalkthroughAnalyzer.analyze(place: place, video: video, photos: photos, store: store)
        let left = 1.6 - Date().timeIntervalSince(start)
        if left > 0 { try? await Task.sleep(for: .seconds(left)) }
        let result = store.addVideo(place, seconds: seconds, insights: found.insights, rewarded: rewarded)
        Cloud.shared.recordWalkthrough(place, seconds: seconds, video: simulated ? nil : video,
                                       insights: found.insights, points: result.points)
        let payout = result.already ? nil : store.bountyPayout(for: place)
        if let video { try? FileManager.default.removeItem(at: video) }
        return WalkthroughSaved(analysis: found, result: result, payout: payout)
    }
}

/// Globie watching the video while the phone reads it.
struct WalkthroughAnalyzing: View {
    @Environment(AppStore.self) private var store
    var seconds: Int
    var simulated: Bool

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            GlobieView(mood: .happy, form: store.streakTier.id, size: 96)
            Text("Watching your video").font(.system(size: 22, weight: .bold)).tracking(-0.4).padding(.top, 6)
            Text("\(seconds) seconds\(simulated ? ", simulated" : "")").mutedStyle(15)
            WalkthroughDots().padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
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
