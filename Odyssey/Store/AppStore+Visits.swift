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
    /// A check-in only pays when you are this close to the place, in metres.
    static let checkInRadius = 75.0
    /// The longest check-in video the recorder takes, in seconds. It stops on its own there.
    static let maxClipSeconds = 60
}

/// One line of what a check-in pays in coins.
struct RewardLine: Identifiable, Equatable {
    enum Kind: Equatable { case checkIn, first, quest, recommended, videoQuest, task }
    var id: String
    var label: String
    var coins: Int
    var kind: Kind
}

/// Everything a check-in at a place pays right now. The Today's Adventure card,
/// the recorder, the Adventure Complete list and the wallet credit all read this,
/// so what is promised, what is listed and what is added are the same number.
struct CheckInRewards {
    /// Coin lines, in the order they are listed.
    var lines: [RewardLine] = []
    /// XP for the check-in itself.
    var xp = 0
    /// XP for the check-in video, before any 2x boost.
    var videoXp = 0
    var points = 0
    /// False when you already checked in here today: rewards pay once a day.
    var fresh = true
    var first = false
    var recommended = false
    /// How far you are from the place, in metres.
    var metres: Double = 0
    /// True when you are close enough for the check-in to pay.
    var inReach = true
    var quest: Quest?
    var walkQuest: Quest?
    /// Today's Quests this check-in completes and pays.
    var tasks: [String] = []

    /// Coins the full list adds up to.
    var coins: Int { lines.reduce(0) { $0 + $1.coins } }
    /// XP the check-in and its video add up to.
    var totalXp: Int { xp + videoXp }
    /// True when checking in now pays.
    var earnable: Bool { fresh && inReach }
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
    /// The breakdown this check-in was paid from, line by line.
    var rewards = CheckInRewards()
    /// True when you were too far from the place, so nothing was paid.
    var tooFar = false
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

    /// True when you are close enough to a place for a check-in to pay. Without the
    /// phone's real position (location off, or the stage demo) there is nothing to measure.
    func inReach(_ place: Place) -> Bool {
        if state.demoMode || !usingRealLocation { return true }
        return here.distance(to: place.coords) <= Rewards.checkInRadius
    }

    /// What checking in at a place pays right now, line by line. `withVideo` adds what the
    /// check-in video pays in coins (the + flow always records one).
    func checkInRewards(for place: Place, withVideo: Bool = true) -> CheckInRewards {
        var r = CheckInRewards()
        r.metres = usingRealLocation ? here.distance(to: place.coords) : metres(to: place)
        r.inReach = inReach(place)
        r.fresh = !checkedInToday(place)
        guard r.fresh else { return r }
        r.first = isFirst(place)
        r.recommended = isRecommended(place)
        r.quest = questAt(place, kinds: r.first ? ["visit", "first"] : ["visit"])
        r.walkQuest = withVideo ? questAt(place, kinds: ["walk"]) : nil

        r.lines.append(RewardLine(id: "checkin", label: "Check-in reward", coins: Rewards.checkIn.coins, kind: .checkIn))
        r.xp = Rewards.checkIn.xp
        r.points = Rewards.checkIn.points
        if r.first {
            r.lines.append(RewardLine(id: "first", label: "First explorer bonus", coins: Rewards.first.coins, kind: .first))
            r.points += Rewards.first.points
        }
        if let quest = r.quest {
            r.lines.append(RewardLine(id: "quest", label: "\(questRarity(quest).label) quest, \(quest.multiplier)x",
                                      coins: quest.coins * quest.multiplier, kind: .quest))
            r.xp += quest.xp * quest.multiplier
        }
        if r.recommended {
            r.lines.append(RewardLine(id: "picked", label: "Recommended pick bonus", coins: Rewards.recommended.coins, kind: .recommended))
            r.xp += Rewards.recommended.xp
            r.points += Rewards.recommended.points
        }
        if withVideo {
            r.videoXp = Rewards.video.xp
            if let walk = r.walkQuest {
                r.lines.append(RewardLine(id: "video-quest", label: "Video quest, \(walk.multiplier)x",
                                          coins: walk.coins * walk.multiplier, kind: .videoQuest))
                r.videoXp += walk.xp * walk.multiplier
            }
        }

        // Today's Quests this check-in completes: paid here with the rest, not later on Home.
        var open: [String: DailyTask] = [:]
        for task in dailyTasks where !task.claimed { open[task.id] = task }
        let withFriend = [r.quest, r.walkQuest].contains { $0.map { !questPartners($0.id).isEmpty } ?? false }
        var due: [(id: String, label: String)] = []
        if place.id == dailyPick().place.id { due.append(("adventure", "Today's Adventure")) }
        due.append(("new", "Explore somewhere new"))
        if withVideo { due.append(("capture", "Capture an adventure")) }
        if withFriend { due.append(("friend", "Explore with a friend")) }
        for item in due {
            guard let task = open[item.id], task.coins > 0 else { continue }
            r.lines.append(RewardLine(id: "task-" + item.id, label: item.label, coins: task.coins, kind: .task))
            r.points += task.points
            r.tasks.append(item.id)
        }
        return r
    }

    /// Post a check-in. Rewards pay once per place per day, and only when you are there.
    /// Everything paid comes from `checkInRewards`, so it matches what was promised.
    func checkIn(_ place: Place, caption: String, photoFile: String?, selfieFile: String?, withVideo: Bool = true) -> CheckInResult {
        let rewards = checkInRewards(for: place, withVideo: withVideo)
        let earn = rewards.earnable
        let first = earn && rewards.first
        let before = standings()
        let rankBefore = rank()
        let quest = earn ? rewards.quest : nil
        let picked = earn && rewards.recommended
        let coins = earn ? rewards.coins : 0
        let points = earn ? rewards.points : 0

        let post = addPost(placeId: place.id, kind: "visit", caption: caption, first: first, photoFile: photoFile, selfieFile: selfieFile)
        if earn {
            let today = Format.today()
            update { s in
                s.checkins[place.id] = today
                if place.isOSM { s.savedPlaces[place.id] = place }
                s.wallet.coins += coins
                s.wallet.points += points
                if !s.visited.contains(place.id) {
                    s.visited.append(place.id)
                    s.stats.explored += 1
                }
                if let quest { s.questsDone[quest.id] = today }
                // The video quest is paid here, so the video itself does not pay it again.
                if let walk = rewards.walkQuest { s.questsDone[walk.id] = today }
                for task in rewards.tasks { s.dailyTasks[task] = today }
                if first {
                    s.firsts.append(place.id)
                    if !s.earnedBadges.contains("first-explorer") { s.earnedBadges.append("first-explorer") }
                }
            }
            tasteExplored(place)
        }
        var xp = earn ? addXp(rewards.xp, boostable: false) : 0
        if earn { xp += demoJump(place, rankBefore: rankBefore) }
        let streak = earn ? claimStreak() : false
        let milestone = streak ? streakReached() : nil
        let after = standings()
        let board = earn ? boardMoment(before: before, after: after) : nil
        if let board { award(board) }
        let result = CheckInResult(fresh: earn, first: first, coins: coins, xp: xp, points: points, streak: streak,
                                   milestone: milestone, quest: quest, partners: quest.map { questPartners($0.id) } ?? [],
                                   before: before, after: after, rankBefore: rankBefore, rankAfter: rank(), post: post,
                                   recommended: picked, board: board, rewards: rewards,
                                   tooFar: rewards.fresh && !rewards.inReach)
        Cloud.shared.recordCheckIn(place, caption: caption, photoFile: photoFile, selfieFile: selfieFile, result: result)
        completeFirstStep(.checkIn)
        return result
    }

    /// A walkthrough video the explorer chose to share. Pays once per place per day.
    /// `rewarded` is false for a check-in video taken too far from the place: it is kept but pays nothing.
    func addVideo(_ place: Place, seconds: Int, insights: AppState.Insights?, rewarded: Bool = true) -> VideoResult {
        let already = !rewarded || (state.videos[place.id] ?? []).contains { $0.date == Format.today() }
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
