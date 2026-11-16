//
//  AppStore+Guide.swift
//  Odyssey
//
//  The first steps a new explorer takes after onboarding: the tour, a saved
//  place and a friend. Each one is ticked off wherever it happens in the
//  app, and finishing all three pays a welcome bonus.
//  Progress lives in tipsSeen, so a save from an older build still opens.
//

import Foundation

enum FirstStep: String, CaseIterable, Identifiable {
    case tour, save, friend

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tour: return "Take the quick tour"
        case .save: return "Save a place you like"
        case .friend: return "Add a friend"
        }
    }

    var detail: String {
        switch self {
        case .tour: return "See how Home works."
        case .save: return "Open Explore and double tap a place."
        case .friend: return "Explore together for 2x coins."
        }
    }

    var icon: String {
        switch self {
        case .tour: return "sparkles"
        case .save: return "heart.fill"
        case .friend: return "person.2.fill"
        }
    }
}

extension AppStore {
    /// Coins for finishing every first step.
    static let welcomeBonus = 200

    private static let guideOn = "guide:on"
    private static let guideClaimed = "guide:claimed"
    private static let guideHidden = "guide:hidden"

    /// True from the end of onboarding until the welcome bonus is claimed.
    var guideOn: Bool {
        state.tipsSeen.contains(AppStore.guideOn) && !state.tipsSeen.contains(AppStore.guideClaimed)
    }

    /// The first steps card shows on Home until it is claimed or hidden.
    var firstStepsShown: Bool { guideOn && !state.tipsSeen.contains(AppStore.guideHidden) }

    func firstStepDone(_ step: FirstStep) -> Bool {
        state.tipsSeen.contains("guide:done:" + step.rawValue)
    }

    var firstStepsDone: Int { FirstStep.allCases.filter(firstStepDone).count }

    /// The step to do next, in order; nil once all three are done.
    var nextFirstStep: FirstStep? { FirstStep.allCases.first { !firstStepDone($0) } }

    /// The welcome tour still has to run (or was cut short by closing the app).
    var welcomeTourPending: Bool { guideOn && !firstStepDone(.tour) }

    /// Onboarding just ended: start the first steps from zero.
    func beginGuide() {
        update { s in
            s.tipsSeen.removeAll { $0.hasPrefix("guide:") || $0 == "explore-feed" }
            s.tipsSeen.append(AppStore.guideOn)
        }
    }

    /// Tick a step off. Does nothing for explorers who joined before the guide existed.
    func completeFirstStep(_ step: FirstStep) {
        guard guideOn, !firstStepDone(step) else { return }
        update { s in s.tipsSeen.append("guide:done:" + step.rawValue) }
    }

    /// Pay the welcome bonus once every step is done. Returns the coins paid.
    @discardableResult
    func claimFirstSteps() -> Int {
        guard guideOn, nextFirstStep == nil else { return 0 }
        update { s in
            s.tipsSeen.append(AppStore.guideClaimed)
            s.wallet.coins += AppStore.welcomeBonus
        }
        return AppStore.welcomeBonus
    }

    func hideFirstSteps() {
        guard !state.tipsSeen.contains(AppStore.guideHidden) else { return }
        update { s in s.tipsSeen.append(AppStore.guideHidden) }
    }
}
