//
//  AdventureActivity.swift
//  Shared by the app and the widgets.
//
//  The Live Activity for an adventure in progress. It sits on the Lock
//  Screen and in the Dynamic Island from the moment you head out to a place
//  until the check-in is done: how far is left, the coins waiting there,
//  and then what you earned.
//

import ActivityKit
import Foundation

nonisolated enum AdventureStage: String, Codable, Hashable, Sendable {
    case heading, arrived, captured, complete

    var title: String {
        switch self {
        case .heading: return "On the way"
        case .arrived: return "You're here"
        case .captured: return "Photo taken"
        case .complete: return "Adventure complete"
        }
    }

    /// How far along the adventure is, for the progress bar.
    var step: Int {
        switch self {
        case .heading: return 0
        case .arrived: return 1
        case .captured: return 2
        case .complete: return 3
        }
    }
}

nonisolated struct AdventureActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable, Sendable {
        var stage: AdventureStage
        var distanceMeters: Double
        /// How much of the walk is done, 0 to 1.
        var progress: Double
        var coinsEarned: Int
        var streakDays: Int
        var message: String

        var distanceText: String {
            distanceMeters < 1000 ? "\(Int((distanceMeters / 10).rounded()) * 10) m" : String(format: "%.1f km", distanceMeters / 1000)
        }
    }

    var placeID: String
    var placeName: String
    var kind: String
    var symbol: String
    var reward: Int
    var isFirst: Bool
    var tierID: String
}
