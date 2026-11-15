//
//  OdysseyTests.swift
//  OdysseyTests
//
//  Checks that the Swift port behaves like the HTML mockup: the same
//  rewards, streak rules, taste learning, formatting and seeded history.
//  Reference numbers were computed by running the mockup's JavaScript.
//

import Foundation
import SwiftUI
import Testing
@testable import Odyssey

@MainActor
struct RewardTests {
    @Test func firstExplorerCheckInPaysTheBonus() {
        let store = AppStore(preview: true)
        let place = store.place("marina")!
        let before = store.state.wallet.coins
        let result = store.checkIn(place, caption: "", photoFile: nil, selfieFile: nil)
        #expect(result.first)
        #expect(result.coins == 250)
        #expect(store.state.wallet.coins == before + 250)
        #expect(store.state.firsts.contains("marina"))
        #expect(store.status(of: place).status == .mine)
    }

    @Test func secondCheckInTheSameDayPaysNothing() {
        let store = AppStore(preview: true)
        let place = store.place("valley-life")!
        let first = store.checkIn(place, caption: "", photoFile: nil, selfieFile: nil)
        let again = store.checkIn(place, caption: "", photoFile: nil, selfieFile: nil)
        #expect(first.coins == 100)
        #expect(again.fresh == false)
        #expect(again.coins == 0)
        #expect(store.state.myPosts.count == 2)
    }

    @Test func streakCountsOncePerDay() {
        let store = AppStore(preview: true)
        let start = store.state.streak.days
        #expect(store.claimStreak())
        #expect(store.claimStreak() == false)
        #expect(store.state.streak.days == start + 1)
        #expect(store.globieMood == .happy)
    }

    @Test func walkthroughPaysOncePerPlacePerDay() {
        let store = AppStore(preview: true)
        let place = store.place("haas")!
        let first = store.addVideo(place, seconds: 30, insights: nil)
        let again = store.addVideo(place, seconds: 30, insights: nil)
        #expect(first.xp == 50)
        #expect(again.already)
        #expect(again.xp == 0)
    }
}

@MainActor
struct TasteTests {
    @Test func thumbsUpThenUndoLeavesNoTrace() {
        let store = AppStore(preview: true)
        let place = store.place("cheese-board")!
        #expect(store.vote(place, 1) == 1)
        #expect(store.voteOf(place) == 1)
        #expect(store.vote(place, 1) == 0)
        #expect(store.state.taste.votes.isEmpty)
        #expect(store.state.taste.weights.values.allSatisfy { abs($0) < 0.0001 })
    }

    @Test func thumbsDownDropsAPlaceFromPicks() {
        let store = AppStore(preview: true)
        let place = store.place("cheese-board")!
        store.vote(place, -1)
        #expect(!store.rankForYou([place]).contains(place))
    }
}

struct MatchesTheMockupTests {
    @Test func formatting() {
        #expect(Format.distance(212) == "210 m")
        #expect(Format.distance(1530) == "1.5 km")
        #expect(Format.walkTime(240) == "3 min walk")
        #expect(Format.ago(34) == "34m")
        #expect(Format.ago(190) == "3h")
        #expect(Format.compact(1240) == "1.2k")
        #expect(Format.ordinal(1) == "1st")
        #expect(Format.ordinal(11) == "11th")
        #expect(Format.ordinal(22) == "22nd")
        #expect(Format.ordinal(113) == "113th")
    }

    @Test func hashesMatchTheBrowser() {
        #expect(StableHash.fnv("doe") == 3_832_068_579)
        #expect(StableHash.fnv("n14125736295") == 2_069_722_834)
        let next = StableHash.generator("doecount")
        #expect(next() == 0.032)
        #expect(next() == 0.293)
    }

    @Test @MainActor func seededHistoryMatches() {
        let store = AppStore(preview: true)
        #expect(store.visitCount(store.place("doe")!) == 61)
    }

    @Test @MainActor func openingHoursReadAsWords() {
        #expect(NearbyService.hoursText("Mo-Su 11:00-18:00") == "Daily 11:00 to 18:00")
        #expect(NearbyService.hoursText("24/7") == "Open 24 hours")
    }

    @Test func streakForms() {
        #expect(StreakTiers.tier(for: 99).id == "fire")
        #expect(StreakTiers.next(after: 99)?.days == 100)
        #expect(StreakTiers.milestones.first == 10)
    }

    @Test func svgPathsParse() {
        let eyes = SVGPath.path("m40 39 1.9 4.1 4.4.5-3.3 3 .9 4.4-3.9-2.2-3.9 2.2.9-4.4-3.3-3 4.4-.5z").boundingRect
        #expect(eyes.minX > 35 && eyes.maxX < 47)
        #expect(eyes.minY >= 38.9 && eyes.maxY < 52)
    }

    @Test func mediaNames() {
        #expect(Media.name(for: "assets/media/places/doe-library.jpg") == "places-doe-library")
        #expect(Media.name(for: "assets/vendor/brands/amazon.svg") == "brands-amazon")
    }
}

@MainActor
struct BountyAndTravelTests {
    @Test func bountySlicesMatchTheMockup() {
        let store = AppStore(preview: true)
        let telegraph = store.bounty("b-telegraph")!
        #expect(store.bountySlice(telegraph) == 8.33)
    }

    @Test func walkthroughAtABountyPaysCash() {
        let store = AppStore(preview: true)
        let place = store.place("greek-theatre")!
        let cash = store.state.wallet.cash
        let payout = store.bountyPayout(for: place)
        #expect(payout != nil)
        #expect(store.state.wallet.cash > cash)
        #expect(store.bounty("b-greek")!.crew.contains("me"))
    }

    @Test func arrivingSomewhereNewAddsACountry() {
        let store = AppStore(preview: true)
        let before = store.travelCountries.count
        let result = store.arrive(store.extras.demoTrip)
        #expect(result.isNew)
        #expect(store.travelCountries.count == before + 1)
        #expect(store.arrive(store.extras.demoTrip).isNew == false)
    }

    @Test func seasonUnlocksThePolarTitleOnce() {
        let store = AppStore(preview: true)
        let quest = store.extras.season.quests[0]
        #expect(store.completeSeason(quest))
        #expect(store.state.equipped.title == "polar-explorer")
        #expect(store.completeSeason(store.extras.season.quests[1]) == false)
    }
}

struct SeedDataTests {
    /// Every field the models expect is in seed.json, so the app cannot crash on launch reading it.
    @Test func seedDecodesCompletely() {
        let seed = Seed.shared
        #expect(seed.places.count == 43)
        #expect(seed.exploredShapes.streets.count > 300)
        let extras = SeedExtras.shared
        #expect(extras.bounties.count == 5)
        #expect(!extras.credits.isEmpty)
    }
}
