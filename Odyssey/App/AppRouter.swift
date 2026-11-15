//
//  AppRouter.swift
//  Odyssey
//
//  Navigation for the whole app: which tab is open, the pushed screens on
//  each tab, and the full screen flows (check-in, stories, walkthroughs)
//  that cover everything. Widgets and the Live Activity open the app with
//  odyssey:// links, which land here too.
//

import Foundation
import Observation
import SwiftUI

enum AppTab: String, CaseIterable, Hashable {
    case home, friends, explore, profile

    var title: String {
        switch self {
        case .home: return "Home"
        case .friends: return "Friends"
        case .explore: return "Explore"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .friends: return "person.2"
        case .explore: return "safari"
        case .profile: return "person"
        }
    }
}

/// Screens pushed onto a tab.
enum Route: Hashable {
    case place(String)
    case streak
    case widgets
    case widgetEditor(OdysseyWidgetKind)
    case shop(String?)
    case leaderboard
    case ranks
    case recap
    case person(String)
    case search
    case notifications
    case editProfile
    case quests
    case giftCards
    case addFriends
    case firsts
    case history
    case settings
    case friendsMap
    case business
    case demoGuide
    case admin
    case tasteProfile
}

/// Flows that cover the whole screen.
enum Cover: Identifiable, Hashable {
    case checkIn(placeID: String?)
    case story(personID: String, postID: String?)
    case walkthrough(placeID: String)
    case dayShare
    case powerUp(days: Int)
    case bountyWizard
    case globe
    case exploredMap(focus: String?)
    case countryScene
    /// Record a walkthrough video to turn a place into a 3D space. Nil picks the nearest place by GPS.
    case scan(placeID: String?)
    /// Walk around inside a finished 3D scan.
    case scanViewer(scanID: String)

    var id: String {
        switch self {
        case .checkIn(let id): return "checkin-\(id ?? "")"
        case .story(let person, let post): return "story-\(person)-\(post ?? "")"
        case .walkthrough(let id): return "walk-\(id)"
        case .dayShare: return "day"
        case .powerUp(let days): return "power-\(days)"
        case .bountyWizard: return "bounty-new"
        case .globe: return "globe"
        case .exploredMap(let focus): return "explored-\(focus ?? "")"
        case .countryScene: return "country"
        case .scan(let id): return "scan-\(id ?? "")"
        case .scanViewer(let id): return "scan-view-\(id)"
        }
    }
}

@Observable
final class AppRouter {
    var tab: AppTab = .home
    var paths: [AppTab: [Route]] = [:]
    var cover: Cover?
    /// Bumped when a tab is tapped while open, so it can scroll to the top.
    var scrollToTop: [AppTab: Int] = [:]

    func path(_ tab: AppTab) -> [Route] { paths[tab] ?? [] }

    func binding(_ tab: AppTab) -> Binding<[Route]> {
        Binding(get: { self.paths[tab] ?? [] }, set: { self.paths[tab] = $0 })
    }

    func push(_ route: Route) {
        paths[tab, default: []].append(route)
    }

    func pop() {
        guard !(paths[tab] ?? []).isEmpty else { return }
        paths[tab]?.removeLast()
    }

    func popToRoot() { paths[tab] = [] }

    func select(_ next: AppTab) {
        if next == tab {
            if path(next).isEmpty {
                scrollToTop[next, default: 0] += 1
            } else {
                paths[next] = []
            }
        } else {
            tab = next
        }
    }

    func present(_ next: Cover) {
        cover = next
    }

    func dismissCover() { cover = nil }

    /// odyssey://checkin, odyssey://checkin/<place>, odyssey://place/<id>, odyssey://streak,
    /// odyssey://widgets, odyssey://explore, odyssey://friends, odyssey://quests.
    func open(_ url: URL, store: AppStore) {
        guard url.scheme == "odyssey", store.state.session.signedIn else { return }
        let host = url.host ?? ""
        let id = url.pathComponents.dropFirst().first
        cover = nil
        switch host {
        case "checkin":
            present(.checkIn(placeID: id))
        case "place":
            tab = .home
            paths[.home] = id.map { [.place($0)] } ?? []
        case "streak":
            tab = .home
            paths[.home] = [.streak]
        case "widgets":
            tab = .profile
            paths[.profile] = [.widgets]
        case "explore":
            tab = .explore
            paths[.explore] = []
        case "friends":
            tab = .friends
            paths[.friends] = []
        case "quests":
            tab = .home
            paths[.home] = [.quests]
        case "shop":
            tab = .profile
            paths[.profile] = [.shop(nil)]
        case "leaderboard":
            tab = .profile
            paths[.profile] = [.leaderboard]
        default:
            tab = .home
        }
    }
}
