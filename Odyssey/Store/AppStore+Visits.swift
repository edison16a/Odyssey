//
//  AppStore+Visits.swift
//  Odyssey
//
//  Exploring places. A check-in is the core action: be there, take the
//  BeReal style photo pair, and get rewarded. Being the first Odyssey explorer
//  somewhere pays a bonus and keeps your name on the place. A walkthrough
//  video afterwards is optional and pays bonus XP when it is shared.
//  Ported from services/visits.js and data/visits.js.
//

import Foundation

enum Rewards {
    static let checkIn = (coins: 100, xp: 20, points: 10)
    static let first = (coins: 150, points: 40)
    static let video = (xp: 50, points: 40)
    /// Going somewhere Explore picked for you.
    static let recommended = (coins: 50, xp: 30, points: 25)
}

nonisolated enum PlaceStatus: String, Sendable {
    case mine, new, explored
}

/// Everything the Adventure Complete screen needs.
struct CheckInResult {
    var fresh: Bool
    var first: Bool
    var coins: Int
    var xp: Int
    var points: Int
    var streak: Bool
    var milestone: StreakTier?
    var quest: Quest?
    var partners: [String]
    var before: [Standing]
    var after: [Standing]
    var rankBefore: RankInfo
    var rankAfter: RankInfo
    var post: Post
    /// True when Explore had recommended this place, which paid a bonus.
    var recommended = false
    /// A leaderboard milestone this check-in reached, celebrated after the rank up.
    var board: BoardMoment? = nil
}

struct VideoResult {
    var already: Bool
    var xp: Int
    var points: Int
    var coins: Int
    var quest: Quest?
}

extension AppStore {
    /// "mine" once you explored it, "new" when nobody on Odyssey has, otherwise "explored".
    func status(of place: Place) -> (status: PlaceStatus, explorers: Int) {
        let count = visitCount(place)
        if state.visited.contains(place.id) { return (.mine, count + 1) }
        if place.status == "unexplored" { return (.new, 0) }
        return (.explored, count)
    }

    func isFirst(_ place: Place) -> Bool { status(of: place).status == .new }

    func checkedInToday(_ place: Place) -> Bool { state.checkins[place.id] == Format.today() }

    /// An open quest at this place, if any.
    func questAt(_ place: Place, kinds: [String]) -> Quest? {
        seed.quests.first { q in
            q.placeId == place.id && state.questsDone[q.id] == nil && kinds.contains(q.kind) && questReady(q)
        }
    }

    /// Post a check-in. Rewards pay once per place per day.
    func checkIn(_ place: Place, caption: String, photoFile: String?, selfieFile: String?) -> CheckInResult {
        let fresh = !checkedInToday(place)
        let first = fresh && isFirst(place)
        let before = standings()
        let rankBefore = rank()
        let quest = fresh ? questAt(place, kinds: first ? ["visit", "first"] : ["visit"]) : nil
        let bonusCoins = quest.map { $0.coins * $0.multiplier } ?? 0
        let bonusXp = quest.map { $0.xp * $0.multiplier } ?? 0
        let picked = fresh && isRecommended(place)
        let coins = fresh ? Rewards.checkIn.coins + (first ? Rewards.first.coins : 0) + bonusCoins
            + (picked ? Rewards.recommended.coins : 0) : 0
        let points = fresh ? Rewards.checkIn.points + (first ? Rewards.first.points : 0)
            + (picked ? Rewards.recommended.points : 0) : 0

        let post = addPost(placeId: place.id, kind: "visit", caption: caption, first: first, photoFile: photoFile, selfieFile: selfieFile)
        if fresh {
            update { s in
                s.checkins[place.id] = Format.today()
                if place.isOSM { s.savedPlaces[place.id] = place }
                s.wallet.coins += coins
                s.wallet.points += points
                if !s.visited.contains(place.id) {
                    s.visited.append(place.id)
                    s.stats.explored += 1
                }
                if let quest { s.questsDone[quest.id] = Format.today() }
                if first {
                    s.firsts.append(place.id)
                    if !s.earnedBadges.contains("first-explorer") { s.earnedBadges.append("first-explorer") }
                }
            }
            tasteExplored(place)
        }
        var xp = fresh ? addXp(Rewards.checkIn.xp + bonusXp + (picked ? Rewards.recommended.xp : 0), boostable: false) : 0
        if fresh { xp += demoJump(place, rankBefore: rankBefore) }
        let streak = fresh ? claimStreak() : false
        let milestone = streak ? streakReached() : nil
        let after = standings()
        let board = fresh ? boardMoment(before: before, after: after) : nil
        if let board { award(board) }
        let result = CheckInResult(fresh: fresh, first: first, coins: coins, xp: xp, points: points, streak: streak,
                                   milestone: milestone, quest: quest, partners: quest.map { questPartners($0.id) } ?? [],
                                   before: before, after: after, rankBefore: rankBefore, rankAfter: rank(), post: post,
                                   recommended: picked, board: board)
        Cloud.shared.recordCheckIn(place, caption: caption, photoFile: photoFile, selfieFile: selfieFile, result: result)
        completeFirstStep(.checkIn)
        return result
    }

    /// A walkthrough video the explorer chose to share. Pays once per place per day.
    func addVideo(_ place: Place, seconds: Int, insights: AppState.Insights?) -> VideoResult {
        let already = (state.videos[place.id] ?? []).contains { $0.date == Format.today() }
        let quest = already ? nil : questAt(place, kinds: ["walk"])
        let bonusCoins = quest.map { $0.coins * $0.multiplier } ?? 0
        let bonusXp = quest.map { $0.xp * $0.multiplier } ?? 0
        update { s in
            s.videos[place.id, default: []].append(AppState.Video(date: Format.today(), seconds: seconds, insights: insights))
            if !already {
                s.wallet.points += Rewards.video.points
                s.wallet.coins += bonusCoins
                s.stats.contributions += 1
            }
            if let quest { s.questsDone[quest.id] = Format.today() }
            if let insights { s.placeInsights[place.id] = insights }
        }
        let xp = already ? 0 : addXp(Rewards.video.xp + bonusXp, boostable: true)
        return VideoResult(already: already, xp: xp, points: already ? 0 : Rewards.video.points, coins: bonusCoins, quest: quest)
    }

    /// Places you have explored, newest first.
    var myPlaces: [Place] {
        state.visited.reversed().compactMap { place($0) }
    }

    // MARK: Seeded history per place, identical to the mockup's

    private static let crew = ["diego", "hana", "nina", "jordan", "priya", "sam", "omar", "ava", "marco"]

    /// How many explorers have checked in here, before you.
    func visitCount(_ place: Place) -> Int {
        if place.status == "unexplored" { return 0 }
        let rand = StableHash.generator(place.id + "count")
        return Int((12 + rand() * 40 + Double(place.reviews ?? 100) / 25).rounded())
    }

    func firstExplorer(_ place: Place) -> (by: String, date: String)? {
        if place.status == "unexplored" {
            return state.firsts.contains(place.id) ? ("me", Format.today()) : nil
        }
        let post = seed.posts.first { $0.placeId == place.id && $0.first == true && $0.by != "me" }
        let rand = StableHash.generator(place.id + "first")
        let month = 1 + Int(rand() * 9)
        let day = 1 + Int(rand() * 27)
        let by = post?.by ?? AppStore.crew[Int(rand() * Double(AppStore.crew.count))]
        return (by, String(format: "2026-%02d-%02d", month, day))
    }

    /// The regulars: people with the most visits here, most first.
    func topExplorers(_ place: Place) -> [(id: String, visits: Int)] {
        if place.status == "unexplored" { return [] }
        let rand = StableHash.generator(place.id + "top")
        let picked = Array(AppStore.crew.filter { _ in rand() > 0.45 }.prefix(5))
        return picked.map { (id: $0, visits: 1 + Int(rand() * 14)) }.sorted { $0.visits > $1.visits }
    }

    /// Walkthrough videos shared for this place, including your own.
    func videoCount(_ place: Place) -> Int {
        let mine = state.videos[place.id]?.count ?? 0
        if place.status == "unexplored" { return mine }
        return Int(StableHash.generator(place.id + "videos")() * 6) + mine
    }

    /// 18 weeks of visit counts for the activity grid.
    func activity(_ place: Place) -> [Int] {
        let rand = StableHash.generator(place.id + "activity")
        let busy = place.status == "unexplored" ? 0 : min(1, Double(visitCount(place)) / 60)
        return (0..<(18 * 7)).map { _ in
            let r = rand()
            return r > 1 - busy * 0.5 ? Int((rand() * 4).rounded(.up)) : 0
        }
    }
}
