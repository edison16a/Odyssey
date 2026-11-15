//
//  OdysseyWidgetsBundle.swift
//  OdysseyWidgets
//
//  Everything Odyssey puts outside the app: six home and Lock Screen widgets
//  and the adventure Live Activity for the Lock Screen and Dynamic Island.
//

import Foundation
import SwiftUI
import WidgetKit

@main
struct OdysseyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        StreakWidget()
        AdventureWidget()
        CoinsWidget()
        FriendsWidget()
        QuestWidget()
        LeaderboardWidget()
        AdventureLiveActivity()
    }
}
