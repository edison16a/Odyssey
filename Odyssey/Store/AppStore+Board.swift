//
//  AppStore+Board.swift
//  Odyssey
//
//  Leaderboard milestones and the stage demo. Reaching the top 100 or the
//  top 10 of any board earns a badge, a laurel frame and a banner, and the
//  check-in that gets you there carries the moment so the app can
//  celebrate it. The rewards are defined here and added to the seeded
//  lists when the seed loads, so the shop, pickers and profile treat them
//  like every other badge and cosmetic.
//
//  Demo mode sets up the hackathon story: Y Combinator is unclaimed, you
//  sit just under the next rank and just outside the top 100 of the city,
//  and the YC check-in carries you up a rank and into the city's top 10.
//

import Foundation

/// A leaderboard milestone reached by a check-in.
struct BoardMoment: Identifiable, Hashable {
    /// 10 or 100.
    var top: Int
    var position: Int
    var previous: Int
    var scopeLabel: String
    var id: String { "\(top)-\(scopeLabel)" }
}

nonisolated enum BoardRewards {
    static let badges: [Badge] = [
        Badge(id: "top-100", name: "Top 100", icon: "trophy", color: "#2b59ff",
              desc: "Reached the top 100 of a leaderboard", streak: nil),
        Badge(id: "top-10", name: "Top 10", icon: "crown", color: "#d39b00",
              desc: "Reached the top 10 of a leaderboard", streak: nil),
    ]

    static let frames: [Cosmetic] = [
        Cosmetic(id: "laurel-silver", name: "Silver Laurel", price: nil, rarity: "earned",
                 desc: "For the top 100 of a leaderboard", earnedBy: "top-100", streak: nil),
        Cosmetic(id: "laurel-gold", name: "Golden Laurel", price: nil, rarity: "earned",
                 desc: "For the top 10 of a leaderboard", earnedBy: "top-10", streak: nil),
    ]

    static let banners: [Banner] = [
        Banner(id: "board-top-100", name: "Top 100", city: nil, label: "Top 100 explorer",
               photo: "assets/media/cities/san-francisco.jpg", price: nil, rarity: "earned", focus: "50% 40%",
               placeId: nil, earnedBy: "top-100", streak: nil),
        Banner(id: "board-top-10", name: "Top 10", city: nil, label: "Top 10 explorer",
               photo: "assets/media/streak/gold.jpg", price: nil, rarity: "earned", focus: "50% 50%",
               placeId: nil, earnedBy: "top-10", streak: nil),
    ]

    /// Adds the leaderboard rewards to a freshly decoded seed.
    static func extend(_ seed: inout Seed) {
        seed.badges += badges.filter { b in !seed.badges.contains { $0.id == b.id } }
        seed.frames += frames.filter { f in !seed.frames.contains { $0.id == f.id } }
        seed.banners += banners.filter { b in !seed.banners.contains { $0.id == b.id } }
    }
}

extension AppStore {
    /// The best milestone crossed between two sets of standings, if any.
    func boardMoment(before: [Standing], after: [Standing]) -> BoardMoment? {
        var best: BoardMoment?
        for new in after {
            guard let old = before.first(where: { $0.scope.id == new.scope.id }) else { continue }
            for top in [10, 100] where new.position <= top && old.position > top {
                if best == nil || top < best!.top || (top == best!.top && new.position < best!.position) {
                    best = BoardMoment(top: top, position: new.position, previous: old.position, scopeLabel: new.scope.label)
                }
            }
        }
        return best
    }

    /// Hand out the badges, frame and banner for a milestone and wear them.
    func award(_ moment: BoardMoment) {
        let ids = moment.top == 10 ? ["top-100", "top-10"] : ["top-100"]
        update { s in
            for id in ids where !s.earnedBadges.contains(id) { s.earnedBadges.append(id) }
            s.equipped.frame = moment.top == 10 ? "laurel-gold" : "laurel-silver"
            s.equipped.banner = moment.top == 10 ? "board-top-10" : "board-top-100"
            if !s.equipped.badges.contains(ids.last!) { s.equipped.badges.insert(ids.last!, at: 0) }
            if s.equipped.badges.count > 3 { s.equipped.badges.removeLast(s.equipped.badges.count - 3) }
        }
    }

    /// The best leaderboard badge you hold, for rows and chips.
    var boardBadge: Badge? {
        let id = state.earnedBadges.contains("top-10") ? "top-10" : (state.earnedBadges.contains("top-100") ? "top-100" : nil)
        return id.flatMap { seed.badge($0) }
    }

    // MARK: Demo mode

    /// Points that put you at a given position on the city board.
    func cityPoints(for position: Int) -> Int {
        guard let city = seed.scopes.first(where: { $0.id == "city" }) else { return 0 }
        return Int((city.spread * log(city.population * 0.5 / Double(max(1, position)))).rounded(.up))
    }

    /// Y Combinator while the stage demo is on and it is still waiting to be claimed,
    /// so the home map opens there wherever the phone really is.
    var demoFocus: Coord? {
        guard state.demoMode, let yc = place("yc"), status(of: yc).status != .mine else { return nil }
        return yc.coords
    }

    /// Turn the stage demo on or off.
    func setDemoMode(_ on: Bool) {
        update { s in
            s.demoMode = on
            guard on else { return }
            s.visited.removeAll { $0 == "yc" }
            s.firsts.removeAll { $0 == "yc" }
            s.checkins["yc"] = nil
            s.questsDone["q-yc"] = nil
            s.demoArea = "sf"
            s.earnedBadges.removeAll { $0 == "top-10" || $0 == "top-100" }
        }
        guard on else { return }
        // Just under Voyager, and 11th in the city: one check-in from the top 10.
        let voyager = seed.ranks.indices.contains(4) ? seed.ranks[4].xp : 900
        update { s in
            s.wallet.xp = voyager - 15
            s.wallet.points = cityPoints(for: 11)
        }
    }

    /// The demo's YC check-in: up a rank and into the city's top 10. Returns the XP it added.
    func demoJump(_ place: Place, rankBefore: RankInfo) -> Int {
        guard state.demoMode, place.id == "yc" else { return 0 }
        let target = rankBefore.next.map { $0.xp + 10 } ?? state.wallet.xp
        let extra = max(0, target - state.wallet.xp)
        let points = cityPoints(for: 7)
        update { s in
            s.wallet.xp += extra
            s.wallet.points = max(s.wallet.points, points)
        }
        return extra
    }
}
