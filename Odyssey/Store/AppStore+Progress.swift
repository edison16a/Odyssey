//
//  AppStore+Progress.swift
//  Odyssey
//
//  XP and rank tiers, the daily streak and its milestones, and leaderboard
//  standings, ported from services/progress.js and services/streak.js.
//

import Foundation

struct RankInfo {
    var xp: Int
    var tier: Int
    var current: Rank
    var next: Rank?
    var progress: Double
    var toNext: Int
}

struct Standing: Identifiable {
    var position: Int
    var pct: Double
    var scope: Scope
    var id: String { scope.id }
}

extension AppStore {
    func rank(xp: Int? = nil) -> RankInfo {
        let total = xp ?? state.wallet.xp
        let tier = seed.rankIndex(for: total)
        let current = seed.ranks[tier]
        let next = tier + 1 < seed.ranks.count ? seed.ranks[tier + 1] : nil
        let progress = next.map { min(1, max(0, Double(total - current.xp) / Double(max(1, $0.xp - current.xp)))) } ?? 1
        return RankInfo(xp: total, tier: tier, current: current, next: next, progress: progress, toNext: next.map { $0.xp - total } ?? 0)
    }

    /// Add XP. A banked 2x boost doubles walkthrough XP once.
    @discardableResult
    func addXp(_ amount: Int, boostable: Bool) -> Int {
        var gained = amount
        update { s in
            if boostable, (s.boosts["xp2"] ?? 0) > 0 {
                gained = amount * 2
                s.boosts["xp2", default: 0] -= 1
            }
            s.wallet.xp += gained
        }
        return gained
    }

    var streakClaimedToday: Bool { state.streak.lastDay == Format.today() }

    /// One streak credit per local day. Returns true when today was new.
    @discardableResult
    func claimStreak() -> Bool {
        let day = Format.today()
        guard state.streak.lastDay != day else { return false }
        update { s in
            s.streak.days += 1
            s.streak.lastDay = day
        }
        return true
    }

    /// Record today's streak day. Returns the tier reached today, or nil on an ordinary day.
    func streakReached() -> StreakTier? {
        let days = state.streak.days
        let tier = StreakTiers.all.first { $0.days == days && $0.days > 0 }
        update { s in
            s.streak.best = max(s.streak.best, days)
            if let tier, !s.earnedBadges.contains("streak-\(tier.days)") {
                s.earnedBadges.append("streak-\(tier.days)")
            }
        }
        return tier
    }

    /// Equip what a milestone unlocked: its Globie frame and its banner.
    func equipTier(_ tier: StreakTier) {
        update { s in
            s.equipped.frame = "globie-\(tier.id)"
            if seed.banner("streak-\(tier.id)") != nil { s.equipped.banner = "streak-\(tier.id)" }
        }
    }

    var streakTier: StreakTier { StreakTiers.tier(for: state.streak.days) }

    /// Globie's mood: ecstatic on a milestone day, happy once today counts.
    var globieMood: GlobieMood {
        if state.streak.days == 0 { return .sad }
        if streakClaimedToday && StreakTiers.milestones.contains(state.streak.days) { return .ecstatic }
        return streakClaimedToday ? .happy : .sleepy
    }

    /// The last seven days, oldest first.
    var streakWeek: [(letter: String, done: Bool, today: Bool)] {
        WidgetSnapshot.streakWeek(days: state.streak.days, lastDay: state.streak.lastDay)
    }

    func standing(_ scope: Scope, points: Int) -> Standing {
        let share = 0.5 * exp(-Double(points) / scope.spread)
        let position = max(1, Int((scope.population * share).rounded()))
        let pct = max(0.1, (share * 1000).rounded() / 10)
        var labeled = scope
        if scope.id == "city" { labeled.label = home.city }
        return Standing(position: position, pct: pct, scope: labeled)
    }

    func standings(points: Int? = nil) -> [Standing] {
        seed.scopes.map { standing($0, points: points ?? state.wallet.points) }
    }

    var bestStanding: Standing {
        standings().min { $0.pct < $1.pct }!
    }
}
