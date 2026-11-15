//
//  AppStore+Travel.swift
//  Odyssey
//
//  Where you have been, for the explored map and the arrival scene. Every
//  city keeps a trail of points you walked; around each point the fog
//  lifts. New countries are added when you arrive. Ported from
//  services/travel.js with the same distances, and the season quests from
//  features/season/season-sheet.js.
//

import Foundation

extension AppStore {
    static let revealMeters = 120.0
    private static let stepMeters = 70.0
    private static let maxGapMeters = 2500.0

    /// Seeded trails per city plus anything walked in the app.
    var trails: [String: [Coord]] {
        var all = seed.travel.trails
        for (city, points) in state.travelTrails { all[city, default: []] += points }
        return all
    }

    /// Trail points with the gaps filled every 70 m, for drawing cleared fog.
    var trailPoints: [Coord] {
        var out: [Coord] = []
        for trail in trails.values {
            for (i, pt) in trail.enumerated() {
                out.append(pt)
                guard i + 1 < trail.count else { continue }
                let next = trail[i + 1]
                let gap = pt.distance(to: next)
                if gap > AppStore.maxGapMeters { continue }
                let n = Int(gap / AppStore.stepMeters)
                if n > 1 {
                    for k in 1..<n {
                        let f = Double(k) / Double(n)
                        out.append(Coord(pt.lat + (next.lat - pt.lat) * f, pt.lng + (next.lng - pt.lng) * f))
                    }
                }
            }
        }
        return out
    }

    var travelCountries: [String] { seed.travel.countries + state.travelCountries }

    /// Countries, states, cities, area uncovered and how much of home is explored.
    func travelStats() -> (countries: Int, states: Int, cities: Int, area: Double, city: Int) {
        let area = Double(trailPoints.count) * AppStore.stepMeters * AppStore.revealMeters * 2 / 1_000_000
        return (travelCountries.count, seed.travel.states.count + state.travelStates.count, trails.count, area, cityShare())
    }

    /// Share of the home city's grid with a walked point nearby, in percent.
    func cityShare() -> Int {
        let points = trails[home.city] ?? []
        let center = home.center
        var hit = 0
        var total = 0
        var lat = center.lat - 0.016
        while lat <= center.lat + 0.024 {
            var lng = center.lng - 0.03
            while lng <= center.lng + 0.02 {
                total += 1
                let cell = Coord(lat, lng)
                if points.contains(where: { $0.distance(to: cell) < AppStore.revealMeters * 2.2 }) { hit += 1 }
                lng += 0.0025
            }
            lat += 0.0025
        }
        return total == 0 ? 0 : Int((Double(hit) / Double(total) * 100).rounded())
    }

    /// Add a walked point to a city's trail.
    func walk(to city: String, point: Coord) {
        update { s in s.travelTrails[city, default: []].append(point) }
    }

    /// Land in a new place. Returns whether the country is new and its number.
    func arrive(_ trip: DemoTrip) -> (isNew: Bool, number: Int) {
        let isNew = !travelCountries.contains(trip.country)
        update { s in
            if isNew { s.travelCountries.append(trip.country) }
            s.travelTrails[trip.city] = trip.trail
        }
        return (isNew, travelCountries.count)
    }

    // MARK: Winter season

    func seasonDone(_ id: String) -> Bool { state.seasonDone[id] ?? false }

    /// Finish a seasonal quest. Returns true when it unlocks the event title.
    @discardableResult
    func completeSeason(_ quest: SeasonQuest) -> Bool {
        let season = extras.season
        let before = state.seasonDone.count
        update { s in
            s.seasonDone[quest.id] = true
            s.wallet.coins += quest.coins
            if before + 1 >= season.goal && !s.earnedBadges.contains("winter") {
                s.earnedBadges.append("winter")
                s.equipped.title = season.reward.title
                s.wallet.coins += season.reward.coins
            }
        }
        return before < season.goal && before + 1 >= season.goal
    }
}
