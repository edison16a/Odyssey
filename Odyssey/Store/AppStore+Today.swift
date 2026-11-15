//
//  AppStore+Today.swift
//  Odyssey
//
//  Today's Quests on Home: five small daily tasks built from what you
//  already do (check-ins, videos, quests with friends). Each one pays a
//  bonus once a day, automatically, the moment it is complete.
//

import Foundation

struct DailyTask: Identifiable, Equatable {
    enum Action: Equatable { case adventure, capture, explore, friends }

    var id: String
    var title: String
    var detail: String
    var icon: String
    /// What it pays: "+100", "2x"... shown on the reward pill.
    var reward: String
    var coins: Int
    var points: Int
    var done: Int
    var target: Int
    var claimed: Bool
    var action: Action

    var complete: Bool { done >= target }
    var progress: Double { target == 0 ? 1 : min(1, Double(done) / Double(target)) }
}

extension AppStore {
    /// Places checked in today.
    var checkedInTodayIDs: [String] {
        let today = Format.today()
        return state.checkins.filter { $0.value == today }.map(\.key)
    }

    var videosToday: Int {
        let today = Format.today()
        return state.videos.values.reduce(0) { $0 + $1.filter { $0.date == today }.count }
    }

    /// Did a quest with friends who joined get done today?
    var exploredWithFriendToday: Bool {
        let today = Format.today()
        return state.questsDone.contains { id, day in day == today && !questPartners(id).isEmpty }
    }

    var dailyTasks: [DailyTask] {
        let today = Format.today()
        let daily = dailyPick().place
        let claimed = { (id: String) in self.state.dailyTasks[id] == today }
        let checkins = checkedInTodayIDs
        let newToday = checkins.filter { id in state.visited.contains(id) }.count
        return [
            DailyTask(id: "adventure", title: "Complete today's adventure", detail: daily.name, icon: "map.fill",
                      reward: "+150", coins: 150, points: 0, done: checkins.contains(daily.id) ? 1 : 0, target: 1,
                      claimed: claimed("adventure"), action: .adventure),
            DailyTask(id: "new", title: "Explore somewhere new", detail: "Check in at any place", icon: "sparkles",
                      reward: "+100", coins: 100, points: 0, done: min(newToday, 1), target: 1,
                      claimed: claimed("new"), action: .explore),
            DailyTask(id: "capture", title: "Capture an adventure", detail: "Record a quick video", icon: "video.fill",
                      reward: "+50", coins: 50, points: 0, done: min(videosToday, 1), target: 1,
                      claimed: claimed("capture"), action: .capture),
            DailyTask(id: "friend", title: "Explore with a friend", detail: "Join a quest together", icon: "person.2.fill",
                      reward: "2x", coins: 200, points: 0, done: exploredWithFriendToday ? 1 : 0, target: 1,
                      claimed: claimed("friend"), action: .friends),
            DailyTask(id: "video", title: "Contribute a location video", detail: "Film 2 places today", icon: "film.stack",
                      reward: "+40 pts", coins: 0, points: 40, done: min(videosToday, 2), target: 2,
                      claimed: claimed("video"), action: .capture),
        ]
    }

    /// Pay every task that is complete but not yet paid today. Returns what was paid.
    @discardableResult
    func claimDailyTasks() -> [DailyTask] {
        let ready = dailyTasks.filter { $0.complete && !$0.claimed }
        guard !ready.isEmpty else { return [] }
        let today = Format.today()
        update { s in
            for task in ready {
                s.dailyTasks[task.id] = today
                s.wallet.coins += task.coins
                s.wallet.points += task.points
            }
        }
        return ready
    }

    /// Places a friend has been, newest first (from what friends shared).
    var friendAdventures: [(place: Place, by: Person)] {
        var seen = Set<String>()
        var out: [(Place, Person)] = []
        for post in seed.posts.sorted(by: { $0.minutesAgo < $1.minutesAgo }) where isFriend(post.by) {
            guard !seen.contains(post.placeId), let place = place(post.placeId), let person = person(post.by) else { continue }
            seen.insert(post.placeId)
            out.append((place, person))
        }
        return out
    }
}
