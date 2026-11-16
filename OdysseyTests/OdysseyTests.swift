//
//  OdysseyTests.swift
//  OdysseyTests
//
//  Checks that the Swift port behaves like the HTML mockup: the same
//  rewards, streak rules, taste learning, formatting and seeded history.
//  Reference numbers were computed by running the mockup's JavaScript.
//

import Foundation
import MapKit
import SwiftUI
import Testing
@testable import Odyssey

@MainActor
struct RewardTests {
    @Test func firstExplorerCheckInPaysTheBonus() {
        let store = AppStore(preview: true)
        let place = store.place("marina")!
        let before = store.state.wallet.coins
        let result = store.checkIn(place, caption: "")
        #expect(result.first)
        #expect(result.coins == 250)
        #expect(store.state.wallet.coins == before + 250)
        #expect(store.state.firsts.contains("marina"))
        #expect(store.status(of: place).status == .mine)
    }

    @Test func secondCheckInTheSameDayPaysNothing() {
        let store = AppStore(preview: true)
        let place = store.place("valley-life")!
        let first = store.checkIn(place, caption: "")
        let again = store.checkIn(place, caption: "")
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

/// The store only redraws screens for changes they can show, and the walked hexes are
/// worked out a stretch at a time. Both exist to keep scrolling smooth.
@MainActor
struct PerformanceTests {
    /// True when a screen that read `read` would redraw after `change`.
    private func redraws(_ store: AppStore, reading read: () -> Void, after change: () -> Void) -> Bool {
        let fired = Fired()
        withObservationTracking(read) { fired.value = true }
        change()
        return fired.value
    }

    private final class Fired: @unchecked Sendable { var value = false }

    @Test func aStateChangeRedrawsScreensThatReadState() {
        let store = AppStore(preview: true)
        let fired = redraws(store, reading: { _ = store.state.wallet.coins }, after: {
            store.update { $0.wallet.coins += 1 }
        })
        #expect(fired)
    }

    @Test func footprintsAndRecommendationsDoNotRedrawEveryScreen() {
        let store = AppStore(preview: true)
        let walk = [Coord(37.7600, -122.3900), Coord(37.7604, -122.3900), Coord(37.7608, -122.3900)]
        let km = store.state.stats.km
        #expect(redraws(store, reading: { _ = store.state.wallet.coins }, after: { store.recordFootprints(walk) }) == false)
        #expect(store.state.footprints.count == 3)
        #expect(store.state.stats.km > km)
        let place = store.seed.places[0]
        #expect(redraws(store, reading: { _ = store.state.wallet.coins }, after: { store.markRecommended([place]) }) == false)
        #expect(store.isRecommended(place))
    }

    @Test func footprintScreensStillFollowTheWalk() {
        let store = AppStore(preview: true)
        let walk = [Coord(37.7600, -122.3900), Coord(37.7604, -122.3900)]
        #expect(redraws(store, reading: { _ = store.footprintArea }, after: { store.recordFootprints(walk) }))
        #expect(redraws(store, reading: { _ = store.kmWalked }, after: {
            store.recordFootprints([Coord(37.7608, -122.3900)])
        }))
    }

    @Test func walkedHexesGrowTheSameAsWorkingThemOutFromScratch() {
        var path: [Coord] = []
        for i in 0..<400 { path.append(Coord(37.76 + Double(i) * 0.0002, -122.39 + Double(i % 7) * 0.0003)) }
        _ = FootGrid.cachedCells(Array(path.prefix(150)))
        let grown = FootGrid.cachedCells(path)
        #expect(grown == FootGrid.cells(along: path))
        // A trimmed path (the oldest points dropped) starts over rather than keeping stale hexes.
        let trimmed = Array(path.dropFirst(100)) + [Coord(37.9, -122.3)]
        #expect(FootGrid.cachedCells(trimmed) == FootGrid.cells(along: trimmed))
    }
}

@MainActor
struct WorldMapAndFundingTests {
    @Test func friendsLinksKeepTheExistingFriendsScreen() {
        let store = AppStore(preview: true)
        let router = AppRouter()
        router.open(URL(string: "odyssey://friends")!, store: store)
        #expect(router.tab == .home)
        #expect(router.path(.home) == [.friends])
        #expect(AppTab.allCases == [.home, .worldMap, .explore, .profile])
    }

    @Test func oldMapLinksSelectTheSharedWorldMap() {
        let router = AppRouter()
        router.present(.exploredMap(focus: "trip"))
        #expect(router.tab == .worldMap)
        #expect(router.cover == nil)
        #expect(router.worldMapFocus == "trip")
    }

    @Test func movingTheCameraOrPhoneDoesNotReplaceTheBountyTarget() {
        let store = AppStore(preview: true)
        let remote = store.place("doe")!
        let map = store.worldMap
        map.select(remote)
        map.bountyTarget = remote
        map.fly(to: Coord(48.8566, 2.3522))
        store.deviceLocation = Coord(37.7749, -122.4194)
        #expect(map.selectedPlace?.id == remote.id)
        #expect(map.bountyTarget?.coords == remote.coords)
        #expect(map.position.camera?.centerCoordinate.latitude == 48.8566)
    }

    @Test func olderBountiesDecodeWithoutNewFields() throws {
        let original = SeedExtras.shared.bounties[0]
        let decoded = try JSONDecoder().decode(Bounty.self, from: JSONEncoder().encode(original))
        #expect(decoded.maxExplorers == nil)
        #expect(decoded.durationDays == nil)
        #expect(decoded.daysRemaining == original.days)
    }

    @Test func fundedBountiesNeverCreditAnUnverifiedPayout() {
        let store = AppStore(preview: true)
        let place = store.place("greek-theatre")!
        var funded = store.bounty("b-greek")!
        funded.id = "funded-test"
        funded.paidWith = "whop"
        funded.maxExplorers = 6
        funded.pool = 100
        funded.expiresAt = Date().addingTimeInterval(86400).timeIntervalSince1970 * 1000
        store.liveBounties = [funded]
        let cash = store.state.wallet.cash
        #expect(store.bountySlice(funded) == 16.66)
        #expect(store.bountySlice(funded) * 6 <= funded.pool)
        #expect(store.bountyPayout(for: place) == nil)
        #expect(store.state.wallet.cash == cash)
    }

    @Test func expiredBountiesAreExcludedAndCanonicalRecordsWin() {
        let store = AppStore(preview: true)
        var bounty = store.bounty("b-greek")!
        bounty.id = "paid-expired"
        store.update { $0.myBounties = [bounty] }
        bounty.expiresAt = Date().addingTimeInterval(-1).timeIntervalSince1970 * 1000
        bounty.paidWith = "whop"
        store.liveBounties = [bounty]
        #expect(store.bounties.filter { $0.id == bounty.id }.count == 1)
        #expect(!store.openBounties.contains { $0.id == bounty.id })
    }

    @Test func unknownAmenitiesAreNotInferredFromBusinessCategory() {
        let store = AppStore(preview: true)
        var place = store.place("doe")!
        place.tags = nil
        #expect(store.amenities(of: place).isEmpty)
        place.tags = ["wheelchair": "yes", "toilets": "yes"]
        #expect(Set(store.amenities(of: place)) == ["accessible", "bathroom"])
    }
}

@MainActor
struct RemoteBountyIdentityTests {
    @Test func sameVenueAcrossMapProvidersFindsItsFundedBounty() {
        let store = AppStore(preview: true)
        var place = store.place("strada")!
        var bounty = SeedExtras.shared.bounties[0]
        bounty.id = "remote-venue"
        bounty.target = BountyTarget(kind: "place", placeId: "apple-id-on-another-phone", name: place.name, place: place)
        bounty.center = place.coords
        bounty.recorded = 0
        bounty.paidWith = "whop"
        bounty.maxExplorers = 5
        store.liveBounties = [bounty]
        place.id = "osm-id-on-this-phone"
        #expect(store.bounty(for: place)?.id == bounty.id)
        place.coords = Coord(0, 0)
        #expect(store.bounty(for: place) == nil)
    }
}
