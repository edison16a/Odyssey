//
//  Guide.swift
//  Odyssey
//
//  Onboarding does not stop when the app opens. Globie keeps guiding with
//  spotlights: the screen dims, one control stays lit and a short bubble
//  says what it is for. Screens mark their controls with .guideSpot(_:),
//  and the overlay in GuideOverlay.swift draws around whatever is marked.
//

import Foundation
import Observation
import SwiftUI

/// A control a spotlight can land on.
enum GuideSpot: String, Hashable {
    case hero, start, stats, exploreTab, addFriend
}

/// One spotlight: where it lands, what Globie says and how it moves on.
struct GuideStep: Equatable {
    enum Advance: Equatable {
        /// Tap anywhere to continue.
        case next
        /// The lit control itself has to be tapped.
        case tapSpot
    }

    var spot: GuideSpot
    /// The tab the control lives on. The spotlight only shows there.
    var tab: AppTab
    var title: String
    var text: String
    var advance: Advance = .next
    var button = "Next"
    /// Shows a Directions button for this place next to the main one.
    var directionsTo: String? = nil
    var mood: GlobieMood = .happy
}

@Observable
final class Guide {
    /// Where each marked control is on screen.
    @ObservationIgnored private var frames: [GuideSpot: CGRect] = [:]
    /// Bumped when a frame changes, so only the overlay redraws.
    private(set) var frameStamp = 0

    private(set) var steps: [GuideStep] = []
    private(set) var index = 0
    /// Runs when the tour ends, whether it was finished or skipped.
    @ObservationIgnored private var onFinish: (() -> Void)?

    var step: GuideStep? { index < steps.count ? steps[index] : nil }
    var isRunning: Bool { step != nil }

    func frame(of spot: GuideSpot) -> CGRect? {
        _ = frameStamp
        return frames[spot]
    }

    func place(_ spot: GuideSpot, at rect: CGRect) {
        guard frames[spot] != rect else { return }
        frames[spot] = rect
        // Nothing is listening unless a tour is on, so scrolling stays free.
        if isRunning { frameStamp += 1 }
    }

    func start(_ steps: [GuideStep], onFinish: (() -> Void)? = nil) {
        self.onFinish = onFinish
        index = 0
        withAnimation(.easeOut(duration: 0.3)) { self.steps = steps }
        frameStamp += 1
    }

    func next() {
        Haptics.tap()
        if index + 1 < steps.count {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { index += 1 }
        } else {
            stop()
        }
    }

    func stop() {
        let finish = onFinish
        onFinish = nil
        withAnimation(.easeOut(duration: 0.25)) { steps = [] }
        index = 0
        finish?()
    }
}

extension View {
    /// Mark this view as something a spotlight can land on.
    func guideSpot(_ spot: GuideSpot) -> some View {
        modifier(GuideSpotModifier(spot: spot))
    }
}

private struct GuideSpotModifier: ViewModifier {
    @Environment(Guide.self) private var guide
    var spot: GuideSpot

    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { rect in
            guide.place(spot, at: rect)
        }
    }
}

// MARK: The tours

extension Guide {
    /// Right after onboarding: what Home is for, then on to Explore.
    func startWelcome(store: AppStore) {
        start([
            GuideStep(spot: .hero, tab: .home, title: "Today's adventure",
                      text: "One place picked for you, every day. Go there and tap Start to check in.", mood: .ecstatic),
            GuideStep(spot: .stats, tab: .home, title: "Your rewards",
                      text: "Coins, streak and rank. Every check-in grows all three."),
            GuideStep(spot: .exploreTab, tab: .home, title: "Find more places",
                      text: "Tap Explore to swipe through places near you.", advance: .tapSpot),
        ]) { store.completeFirstStep(.tour) }
    }

    /// Straight to Explore, for the "save a place" step.
    func startExplore() {
        start([GuideStep(spot: .exploreTab, tab: .home, title: "Save a place you like",
                         text: "Tap Explore, then double tap any place you would go to.", advance: .tapSpot)])
    }

    /// How a check-in starts, on today's adventure.
    func startCheckIn(store: AppStore) {
        let place = store.dailyPick().place
        let far = Format.distance(store.metres(to: place))
        start([GuideStep(spot: .start, tab: .home, title: "Your first check-in",
                         text: "Head to \(place.name), \(far) away. Once you are there, tap Start and film a quick look around.",
                         button: "Got it", directionsTo: place.id)])
    }

    /// The + on the Friends tab.
    func startFriend() {
        start([GuideStep(spot: .addFriend, tab: .friends, title: "Bring a friend",
                         text: "Tap + to add someone. Check in together and you both earn 2x coins.", advance: .tapSpot)])
    }
}
