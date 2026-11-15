//
//  DemoGuideJumps.swift
//  Odyssey
//
//  Every jump in the demo guide, grouped like the mockup's panel: getting
//  in, exploring and rewards, discover, travel and events, bounties,
//  social and you. Each one goes straight to that flow so a presenter
//  never has to click through sign in twice. Ported from demo-panel.js.
//

import Foundation
import SwiftUI

struct DemoGuideJump: Identifiable {
    var id: String
    var label: String
    var icon: String
}

struct DemoGuideGroup: Identifiable {
    var id: String { title }
    var title: String
    var items: [DemoGuideJump]
}

enum DemoGuideJumps {
    static let groups: [DemoGuideGroup] = [
        DemoGuideGroup(title: "Getting in", items: [
            DemoGuideJump(id: "landing", label: "Landing", icon: "diamond"),
            DemoGuideJump(id: "signin", label: "Email and code", icon: "mail"),
            DemoGuideJump(id: "questions", label: "Five questions", icon: "sliders"),
        ]),
        DemoGuideGroup(title: "Explore and get rewarded", items: [
            DemoGuideJump(id: "home", label: "Home", icon: "home"),
            DemoGuideJump(id: "checkin", label: "Check in, photo and selfie", icon: "camera"),
            DemoGuideJump(id: "first", label: "Be the first explorer", icon: "star"),
            DemoGuideJump(id: "walk", label: "Walkthrough video", icon: "video"),
            DemoGuideJump(id: "place", label: "Place page", icon: "building"),
            DemoGuideJump(id: "reveal", label: "Today's Adventure reveal", icon: "eye"),
            DemoGuideJump(id: "streak", label: "Streak and Globie", icon: "flame"),
            DemoGuideJump(id: "power", label: "Streak power up", icon: "bolt"),
            DemoGuideJump(id: "fire", label: "50 days: Globie on fire", icon: "flame"),
            DemoGuideJump(id: "galaxy", label: "100 days: Galaxy Globie", icon: "moon"),
            DemoGuideJump(id: "nova", label: "500 days: Supernova", icon: "sun"),
            DemoGuideJump(id: "widgets", label: "Home screen widgets", icon: "widget"),
            DemoGuideJump(id: "recap", label: "Daily recap", icon: "footprints"),
        ]),
        DemoGuideGroup(title: "Discover", items: [
            DemoGuideJump(id: "explore", label: "Explore near you", icon: "compass"),
            DemoGuideJump(id: "coffee", label: "Coffee near you", icon: "coffee"),
            DemoGuideJump(id: "travel", label: "Travel to Tokyo, keep your taste", icon: "plane"),
            DemoGuideJump(id: "back-home", label: "Back home", icon: "home"),
            DemoGuideJump(id: "forget", label: "Forget what Odyssey learned", icon: "refresh"),
        ]),
        DemoGuideGroup(title: "Travel and events", items: [
            DemoGuideJump(id: "xmap", label: "Explored map", icon: "globe"),
            DemoGuideJump(id: "country", label: "Arrive in a new country", icon: "plane"),
            DemoGuideJump(id: "winter", label: "Winter Wonderland", icon: "snow"),
            DemoGuideJump(id: "mythic", label: "Mythical quest", icon: "diamond"),
        ]),
        DemoGuideGroup(title: "Bounties", items: [
            DemoGuideJump(id: "bounty", label: "A walkthrough bounty", icon: "dollar"),
            DemoGuideJump(id: "business", label: "Odyssey for Business", icon: "store"),
            DemoGuideJump(id: "post-bounty", label: "Post a bounty", icon: "plus"),
        ]),
        DemoGuideGroup(title: "Social", items: [
            DemoGuideJump(id: "friends", label: "Friends map", icon: "users"),
        ]),
        DemoGuideGroup(title: "You", items: [
            DemoGuideJump(id: "profile", label: "Profile", icon: "user"),
            DemoGuideJump(id: "shop", label: "Shop", icon: "bag"),
            DemoGuideJump(id: "globe", label: "Odyssey Globe", icon: "globe"),
            DemoGuideJump(id: "gifts", label: "Gift cards", icon: "gift"),
            DemoGuideJump(id: "boards", label: "Leaderboards", icon: "trophy"),
        ]),
    ]
}

/// Runs a jump. Returns a bounty id when the jump wants the bounty sheet shown here.
@MainActor
struct DemoGuideRunner {
    var store: AppStore
    var router: AppRouter
    var toast: ToastCenter

    /// The SF id when the demo is set at YC, the Berkeley one otherwise.
    private func here(_ sf: String, _ berkeley: String) -> String { store.home.id == "sf" ? sf : berkeley }

    /// Make sure the app is up, on a tab, with nothing pushed or covering it.
    private func inApp(_ tab: AppTab) {
        store.update { s in
            s.session.signedIn = true
            s.session.onboarded = true
        }
        router.cover = nil
        router.paths[tab] = []
        router.tab = tab
    }

    private func later(_ seconds: Double = 0.4, _ run: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            run()
        }
    }

    private func push(_ tab: AppTab, _ route: Route) {
        inApp(tab)
        later { router.paths[tab] = [route] }
    }

    private func present(_ tab: AppTab, _ cover: Cover) {
        inApp(tab)
        later { router.present(cover) }
    }

    func run(_ id: String) -> String? {
        switch id {
        case "landing", "signin":
            store.update { s in s.session.signedIn = false; s.session.onboarded = false }
        case "questions":
            store.update { s in s.session.signedIn = true; s.session.onboarded = false }
        case "home": inApp(.home)
        case "checkin": present(.home, .checkIn(placeID: here("piccino", "strada")))
        case "first": push(.home, .place(here("crane-cove", "indian-rock")))
        case "walk": present(.home, .walkthrough(placeID: here("yc", "soda")))
        case "place": push(.home, .place(here("paper-son", "doe")))
        case "reveal":
            store.update { s in s.dailyReveal = nil; s.dailyPickFor = nil }
            inApp(.home)
        case "streak": push(.home, .streak)
        case "power": present(.home, .powerUp(days: store.state.streak.days + 1))
        case "fire": present(.home, .powerUp(days: 50))
        case "galaxy": present(.home, .powerUp(days: 100))
        case "nova": present(.home, .powerUp(days: 500))
        case "widgets": push(.home, .widgets)
        case "recap": push(.home, .recap)
        case "explore": inApp(.explore)
        case "coffee":
            store.update { s in s.discoverCategory = "coffee" }
            inApp(.explore)
        case "travel":
            NearbyService.choose("tokyo-shibuya", store: store)
            store.update { s in s.discoverCategory = "all" }
            inApp(.explore)
        case "back-home":
            store.update { s in s.discoverLocation = nil }
            inApp(.explore)
        case "forget":
            store.resetTaste()
            toast.show("Taste reset", icon: "refresh")
        case "xmap": present(.profile, .exploredMap(focus: nil))
        case "country": present(.home, .countryScene)
        case "winter", "mythic": push(.home, .quests)
        case "bounty": return here("b-dogpatch", "b-telegraph")
        case "business": push(.profile, .business)
        case "post-bounty": present(.profile, .bountyWizard)
        case "friends": inApp(.friends)
        case "profile": inApp(.profile)
        case "shop": push(.profile, .shop(nil))
        case "globe": present(.profile, .globe)
        case "gifts": push(.profile, .giftCards)
        case "boards": push(.profile, .leaderboard)
        default: break
        }
        return nil
    }
}
