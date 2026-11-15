//
//  CheckInFlow.swift
//  Odyssey
//
//  Posting, the core of Odyssey. The + button opens straight onto the
//  camera, where one press takes the place and you together. Then say where
//  you are (unless you came from a place), add a caption and post it to
//  friends. The first check-in of the day powers up the streak, then
//  Adventure Complete shows the rewards and offers the optional walkthrough.
//  Ported from features/checkin/checkin.js.
//

import Foundation
import SwiftUI
import UIKit

struct CheckInFlow: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toast
    var placeID: String?

    private enum Stage { case camera, pick, compose, power, adventure }

    @State private var stage: Stage = .camera
    @State private var place: Place?
    @State private var placeImage: UIImage?
    @State private var selfieImage: UIImage?
    @State private var result: CheckInResult?
    @State private var camera = DualCamera()
    @State private var started = false
    /// True when this flow started the Live Activity or moved it to "Posting", so closing early ends it.
    @State private var ownsActivity = false

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
                    AdventureCompleteView(place: place, result: result, placeImage: placeImage, selfieImage: selfieImage)
                        .transition(.opacity)
                }
            default:
                capture
            }
        }
        .onAppear(perform: begin)
        .onDisappear {
            camera.stop()
            // Closed before posting: do not leave "Posting your adventure" on the Lock Screen.
            if result == nil && ownsActivity { LiveActivityService.shared.end(immediately: true) }
        }
    }

    private var capture: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconButton(icon: "close", label: "Close") { router.dismissCover() }
                Text(title)
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
                case .camera:
                    CheckInDualStep(camera: camera, hint: place.map { "Snap \($0.name), and you" } ?? "The place and you, in one tap",
                                    fallbackPlace: place?.photo ?? store.nearestPlace?.photo ?? "",
                                    fallbackSelfie: store.state.user.sampleSelfie ?? "assets/media/people/p09.jpg",
                                    onTaken: taken, onMode: switchMode)
                case .pick:
                    CheckInPickStep { chosen in choose(chosen) }
                default:
                    if let place, let placeImage, let selfieImage {
                        CheckInComposeStep(place: place, placeImage: placeImage, selfieImage: selfieImage) { caption in
                            post(caption)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        }
    }

    private var title: String {
        switch stage {
        case .camera: return place?.name ?? "New post"
        default: return "Check in"
        }
    }

    /// Both photos are in: say where you are next, or go straight to the caption.
    private func taken(_ placePhoto: UIImage, _ selfie: UIImage) {
        placeImage = placePhoto
        selfieImage = selfie
        camera.stop()
        if place != nil { photosReady() }
        withAnimation(.easeInOut(duration: 0.3)) { stage = place == nil ? .pick : .compose }
    }

    private func photosReady() {
        LiveActivityService.shared.captured()
        ownsActivity = true
    }

    /// Video opens a walkthrough of where you are; Daily Map opens today's map.
    private func switchMode(_ mode: PostMode) {
        switch mode {
        case .picture:
            return
        case .video:
            guard let target = place ?? store.lastCheckInToday else {
                toast.show("Check in somewhere first, then record the inside", icon: "camera")
                return
            }
            camera.stop()
            router.cover = .walkthrough(placeID: target.id)
        case .dailyMap:
            camera.stop()
            router.cover = .dayShare
        }
    }

    private func begin() {
        guard !started else { return }
        started = true
        if let placeID, let found = store.place(placeID) { attach(found) }
    }

    /// The place this post is for, with its Live Activity.
    private func attach(_ chosen: Place) {
        place = chosen
        if !LiveActivityService.shared.isRunning || LiveActivityService.shared.placeID != chosen.id {
            LiveActivityService.shared.start(place: chosen, store: store)
            ownsActivity = true
        }
    }

    /// Picked after the photos were taken.
    private func choose(_ chosen: Place) {
        attach(chosen)
        photosReady()
        withAnimation(.easeInOut(duration: 0.3)) { stage = .compose }
    }

    /// Save the photo pair, post the check-in, then show the power up or the rewards.
    private func post(_ caption: String) {
        // A second tap during the transition would post the check-in twice.
        guard let place, result == nil else { return }
        let text = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let photoFile = placeImage.flatMap { PhotoStore.save($0, prefix: "place") }
        let selfieFile = selfieImage.flatMap { PhotoStore.save($0, prefix: "selfie") }
        let outcome = store.checkIn(place, caption: text.isEmpty ? "Exploring \(place.name)." : text,
                                    photoFile: photoFile, selfieFile: selfieFile)
        result = outcome
        LiveActivityService.shared.complete(coins: outcome.coins, streak: store.state.streak.days)
        Haptics.success()
        withAnimation(.easeInOut(duration: 0.35)) { stage = outcome.streak ? .power : .adventure }
    }
}
