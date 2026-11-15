//
//  RecapBuilder.swift
//  Odyssey
//
//  Builds a daily recap: the ordered stops with their places, plus totals.
//  Today's seeded stops get your own check-ins and walkthroughs from today
//  appended, so the recap grows as you explore. The home tile, the recap
//  screen and the day share card all read this one builder, like the
//  mockup's recap-data.js.
//

import CoreLocation
import Foundation

struct RecapDay {
    struct Stop: Identifiable {
        var id: Int
        var place: Place
        var time: String
        var action: String
        var coins: Int
        var xp: Int
        var note: String?
        var seconds: Int
        var first: Bool
    }

    var id: String
    var date: String
    var title: String
    var start: String
    var movingMin: Int
    var stops: [Stop]
    var km: Double

    var coins: Int { stops.reduce(0) { $0 + $1.coins } }
    var xp: Int { stops.reduce(0) { $0 + $1.xp } }
    var firsts: Int { stops.filter(\.first).count }

    /// The stop to feature: the first place you discovered, else the first stop.
    var hero: Place? { (stops.first { $0.first } ?? stops.first)?.place }
    var duration: String { moving }

    /// "1h 36m" from minutes.
    var moving: String {
        let hours = movingMin / 60
        return (hours > 0 ? "\(hours)h " : "") + "\(movingMin % 60)m"
    }
}

enum RecapBuilder {
    /// Walking routes run longer than straight lines between stops.
    private static let streetFactor = 1.3

    /// Today's recap id for the area you are in.
    static func todayID(_ store: AppStore) -> String {
        store.home.id == "sf" ? "today-sf" : "today"
    }

    /// Recaps worth showing here: today first, then earlier days in this area.
    static func available(_ store: AppStore) -> [Recap] {
        let today = todayID(store)
        let home = store.home.id
        let rest = store.seed.recaps.filter { $0.id != today && !$0.id.hasPrefix("today") && ($0.area ?? "berkeley") == home }
        return store.seed.recaps.filter { $0.id == today } + rest
    }

    /// Today's recap, never missing.
    static func today(_ store: AppStore) -> RecapDay {
        build(store) ?? RecapDay(id: "today", date: "Today", title: todayTitle(store), start: "", movingMin: 0, stops: [], km: 0)
    }

    static func build(_ store: AppStore, id: String? = nil) -> RecapDay? {
        let wanted = id ?? todayID(store)
        guard let base = store.seed.recaps.first(where: { $0.id == wanted }) ?? store.seed.recaps.first else { return nil }
        var stops: [RecapDay.Stop] = []
        for stop in base.stops {
            guard let place = store.place(stop.placeId) else { continue }
            stops.append(RecapDay.Stop(id: stops.count, place: place, time: stop.time, action: stop.action, coins: stop.coins,
                                       xp: stop.xp, note: stop.note, seconds: stop.seconds ?? 0, first: stop.first ?? false))
        }
        if base.id.hasPrefix("today") { stops += sessionStops(store, startingAt: stops.count) }
        var meters = 0.0
        for i in stops.indices.dropFirst() {
            meters += stops[i - 1].place.coords.distance(to: stops[i].place.coords) * streetFactor
        }
        let title = base.id.hasPrefix("today") ? todayTitle(store) : base.title
        return RecapDay(id: base.id, date: base.date, title: title, start: base.start, movingMin: base.movingMin,
                        stops: stops, km: max(0.4, meters / 1000))
    }

    /// "Your adventure today in SF": today is an adventure, never a run or a workout.
    static func todayTitle(_ store: AppStore) -> String {
        let city = store.home.city
        let short = ["San Francisco": "SF", "Los Angeles": "LA", "New York": "NYC"][city] ?? city
        return "Your adventure today in \(short)"
    }

    /// Your own check-ins today, with a walkthrough if you recorded one.
    private static func sessionStops(_ store: AppStore, startingAt index: Int) -> [RecapDay.Stop] {
        let s = store.state
        let day = Format.today()
        var stops: [RecapDay.Stop] = []
        for (placeId, date) in s.checkins.sorted(by: { $0.key < $1.key }) where date == day {
            guard let place = store.place(placeId) else { continue }
            let first = s.firsts.contains(placeId)
            let video = s.videos[placeId]?.first { $0.date == day }
            stops.append(RecapDay.Stop(id: index + stops.count, place: place, time: "Just now", action: video == nil ? "visit" : "video",
                                       coins: Rewards.checkIn.coins + (first ? Rewards.first.coins : 0),
                                       xp: Rewards.checkIn.xp + (video == nil ? 0 : Rewards.video.xp),
                                       note: nil, seconds: video?.seconds ?? 0, first: first))
        }
        return stops
    }

    /// The first part of the route, cut at the given share of its length.
    static func partialRoute(_ coords: [Coord], _ share: Double) -> [CLLocationCoordinate2D] {
        guard coords.count > 1, share < 1 else { return coords.map(\.location) }
        let legs = zip(coords, coords.dropFirst()).map { $0.distance(to: $1) }
        let total = legs.reduce(0, +)
        var left = total * share
        var out = [coords[0].location]
        for (i, leg) in legs.enumerated() {
            if left >= leg {
                out.append(coords[i + 1].location)
                left -= leg
            } else {
                let f = leg > 0 ? left / leg : 0
                let a = coords[i], b = coords[i + 1]
                out.append(Coord(a.lat + (b.lat - a.lat) * f, a.lng + (b.lng - a.lng) * f).location)
                break
            }
        }
        return out
    }
}
