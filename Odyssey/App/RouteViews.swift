//
//  RouteViews.swift
//  Odyssey
//
//  Maps every route and cover onto its screen. Each screen lives in its
//  feature folder under Features/.
//

import Foundation
import SwiftUI

struct RouteView: View {
    var route: Route

    var body: some View {
        switch route {
        case .place(let id): PlaceView(placeID: id)
        case .streak: StreakView()
        case .widgets: WidgetsGalleryView()
        case .widgetEditor(let kind): WidgetEditorView(kind: kind)
        case .shop(let tab): ShopView(initialTab: tab)
        case .leaderboard: LeaderboardView()
        case .ranks: RanksView()
        case .recap: RecapView()
        case .person(let id): PersonView(personID: id)
        case .search: SearchView()
        case .notifications: NotificationsView()
        case .editProfile: EditProfileView()
        case .quests: QuestsView()
        case .giftCards: GiftCardsView()
        case .addFriends: AddFriendsView()
        case .firsts: FirstFindsView()
        case .history: AdventureHistoryView()
        case .settings: SettingsView()
        case .friendsMap: FriendsMapView()
        case .business: BusinessView()
        case .demoGuide: DemoGuideView()
        case .admin: AdminView()
        case .tasteProfile: TasteProfileView()
        }
    }
}

struct CoverView: View {
    var cover: Cover

    var body: some View {
        ZStack {
            screen
            RewardPopOverlay()
            ToastOverlay()
        }
    }

    @ViewBuilder private var screen: some View {
        switch cover {
        case .checkIn(let id): CheckInFlow(placeID: id)
        case .story(let person, let post): StoryViewer(startPersonID: person, postID: post)
        case .walkthrough(let id): WalkthroughFlow(placeID: id)
        case .dayShare: DayShareView()
        case .powerUp(let days): PowerUpPreview(days: days)
        case .bountyWizard: BountyWizardView()
        case .globe: GlobeView()
        case .exploredMap(let focus): ExploredMapView(focus: focus)
        case .countryScene: CountrySceneView()
        case .scan(let id): ScanFlow(placeID: id)
        case .scanViewer(let id): ScanViewerView(scanID: id)
        }
    }
}
