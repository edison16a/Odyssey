//
//  MoreWidgetViews.swift
//  Shared by the app and the widgets.
//
//  Picks the right content for each widget kind, and where a tap on each
//  widget takes you.
//

import Foundation
import SwiftUI

/// Picks the right widget content for a kind.
struct OdysseyWidgetContent: View {
    var kind: OdysseyWidgetKind
    var size: WidgetSize
    var snapshot: WidgetSnapshot
    var prefs: WidgetPrefs

    var body: some View {
        switch kind {
        case .streak: StreakWidgetView(size: size, snapshot: snapshot, prefs: prefs)
        case .adventure: AdventureWidgetView(size: size, snapshot: snapshot, prefs: prefs)
        case .coins: CoinsWidgetView(size: size, snapshot: snapshot, prefs: prefs)
        case .friends: FriendsWidgetView(size: size, snapshot: snapshot, prefs: prefs)
        case .quest: QuestWidgetView(size: size, snapshot: snapshot, prefs: prefs)
        case .leaderboard: LeaderboardWidgetView(size: size, snapshot: snapshot, prefs: prefs)
        }
    }

    /// Where a tap on the widget takes you.
    static func link(_ kind: OdysseyWidgetKind, _ snapshot: WidgetSnapshot) -> URL? {
        switch kind {
        case .streak: return URL(string: snapshot.claimedToday ? "odyssey://streak" : "odyssey://checkin")
        case .adventure: return URL(string: "odyssey://place/" + (snapshot.adventure?.id ?? ""))
        case .coins: return URL(string: "odyssey://shop")
        case .friends: return URL(string: "odyssey://friends")
        case .quest: return URL(string: "odyssey://quests")
        case .leaderboard: return URL(string: "odyssey://leaderboard")
        }
    }
}
