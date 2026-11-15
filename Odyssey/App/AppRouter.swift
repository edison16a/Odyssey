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
    case home, worldMap, explore, profile

    var title: String {
        switch self {
        case .home: return "Home"
        case .worldMap: return "World Map"
        case .explore: return "Explore"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .worldMap: return "globe.americas"
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
    case friends
    case friendsMap
    case business
    case demoGuide
    case admin
    case tasteProfile
}

/// Flows that cover the whole screen.
enum Cover: Identifiable, Hashable {
    case checkIn(placeID: String?)
    case walkthrough(placeID: String)
    case dayShare
    case powerUp(days: Int)
    case bountyWizard
    case setBounty(placeID: String?)
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
        case .walkthrough(let id): return "walk-\(id)"
        case .dayShare: return "day"
        case .powerUp(let days): return "power-\(days)"
        case .bountyWizard: return "bounty-new"
        case .setBounty(let id): return "set-bounty-\(id ?? "new")"
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
    /// Consumed by World Map when opening an older travel-map link.
    var worldMapFocus: String?
    /// Set by the odyssey://bounty-paid/<id> link Whop's checkout hands back to.
    var paidBountyID: String?
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
        if case .exploredMap(let focus) = next {
            openWorldMap(focus: focus)
            return
        }
        cover = next
    }

    func openWorldMap(focus: String? = nil) {
        cover = nil
        worldMapFocus = focus
        paths[.worldMap] = []
        tab = .worldMap
    }

    func dismissCover() { cover = nil }

    /// odyssey://checkin, odyssey://checkin/<place>, odyssey://place/<id>, odyssey://streak,
    /// odyssey://widgets, odyssey://explore, odyssey://friends, odyssey://quests.
    func open(_ url: URL, store: AppStore) {
        guard url.scheme == "odyssey", store.state.session.signedIn else { return }
        let host = url.host ?? ""
        let id = url.pathComponents.dropFirst().first
        if host == "bounty-paid" {
            // Back from Whop checkout: leave the Set bounty flow open so it can show the result.
            paidBountyID = id
            return
        }
        cover = nil
        switch host {
        case "onboarding":
            // Demo reset: replay onboarding (connect, compile, gem reveal) without signing out.
            store.update { s in s.session.onboarded = false }
        case "checkin":
            present(.checkIn(placeID: id))
        case "scan":
            // odyssey://scan films a new 3D scan; odyssey://scan/<scan id> opens a finished one.
            if let id { present(.scanViewer(scanID: id)) } else { present(.scan(placeID: nil)) }
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
        case "map", "world-map":
            tab = .worldMap
            paths[.worldMap] = []
        case "friends":
            tab = .home
            paths[.home] = [.friends]
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
