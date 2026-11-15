//
//  WidgetBridge.swift
//  Odyssey
//
//  Keeps the home screen widgets in step with the app. After every change
//  the store asks for a refresh; this builds the small snapshot the widgets
//  read (streak, coins, today's adventure, friends out exploring, the next
//  quest, the weekly board), copies the photos and renders the map they
//  need into the App Group off the main thread, and reloads their timelines.
//

import Foundation
import MapKit
import UIKit
import WidgetKit

enum WidgetBridge {
    /// Posted after new widget images land, so in app previews can redraw.
    static let imagesChanged = Notification.Name("odyssey.widgetImagesChanged")

    @MainActor private static var lastImages: [String: String] = [:]
    @MainActor private static var mapKey: String?
    @MainActor private static var snapshotter: MKMapSnapshotter?
    @MainActor private static var reloadTask: Task<Void, Never>?
    private static let queue = DispatchQueue(label: "odyssey.widget-files", qos: .utility)

    /// Write the snapshot and settings for the widgets and reload them. The
    /// files are written off the main thread.
    @MainActor
    static func publish(from store: AppStore) {
        let snapshot = snapshot(from: store)
        let prefs = store.state.widgetPrefs
        queue.async {
            SharedStore.save(snapshot)
            SharedStore.save(prefs)
            Task { @MainActor in WidgetCenter.shared.reloadAllTimelines() }
        }
    }

    /// What the widgets show right now, also used by the in app previews.
    @MainActor
    static func snapshot(from store: AppStore) -> WidgetSnapshot {
        let s = store.state
        let rank = store.rank()
        let daily = store.dailyPick()
        let picks = store.forYou().filter { store.status(of: $0).status != .mine && $0.id != daily.place.id }.prefix(3)

        var adventure = pick(daily.place, reason: daily.reason, store: store, image: "widget-adventure.jpg")
        addMap(to: &adventure, place: daily.place, store: store)
        let backups = picks.enumerated().map { index, place in
            pick(place, reason: store.why(place), store: store, image: "widget-pick-\(index).jpg")
        }

        let friends: [FriendActivity] = store.feed.filter { $0.by != "me" }.prefix(5).compactMap { post in
            guard let person = store.person(post.by), let place = store.place(post.placeId) else { return nil }
            var file: String?
            if person.avatar.kind == "photo", let path = person.avatar.value {
                let name = "widget-friend-\(person.id).jpg"
                copy(asset: Media.name(for: path), to: name, maxSide: 160)
                file = name
            }
            return FriendActivity(id: person.id, name: person.name, place: place.name, minutesAgo: post.minutesAgo, imageFile: file)
        }

        let quest = store.openQuests.first.flatMap { q -> QuestSnapshot? in
            guard let place = store.place(q.placeId) else { return nil }
            let rarity = store.questRarity(q)
            return QuestSnapshot(title: q.title, rarity: rarity.label, colorHex: rarity.color, coins: q.coins * q.multiplier,
                                 xp: q.xp * q.multiplier, ends: q.ends, placeName: place.name, placeID: place.id)
        }

        return WidgetSnapshot(
            name: s.user.name, streakDays: s.streak.days, bestStreak: max(s.streak.best, s.streak.days),
            streakLastDay: s.streak.lastDay, coins: s.wallet.coins, xp: s.wallet.xp,
            rankName: rank.current.name, rankColorHex: rank.current.color, nextRankName: rank.next?.name,
            rankProgress: rank.progress, placesExplored: s.stats.explored, firstFinds: s.firsts.count,
            adventure: adventure, picks: Array(backups), friends: friends, quest: quest, updatedAt: Date(),
            board: board(from: store), standing: standing(from: store))
    }

    @MainActor
    private static func pick(_ place: Place, reason: String, store: AppStore, image: String) -> AdventurePick {
        let first = store.status(of: place).status == .new
        copy(asset: Media.name(for: place.photo), to: image, maxSide: 700)
        return AdventurePick(id: place.id, name: place.name, kind: store.placeKind(place).label,
                             symbol: Icon.symbol(store.placeKind(place).icon), distanceMeters: store.metres(to: place),
                             coins: Rewards.checkIn.coins + (first ? Rewards.first.coins : 0), isFirst: first,
                             reason: reason, imageFile: image)
    }

    /// Frame a square map on the place, wide enough to show you when you are
    /// close, note where both sit on it, and render it when either changed.
    @MainActor
    private static func addMap(to pick: inout AdventurePick, place: Place, store: AppStore) {
        let file = "widget-adventure-map.jpg"
        let target = MKMapPoint(place.coords.location)
        let here = store.here
        let distance = here.distance(to: place.coords)
        let showYou = distance > 60 && distance < 4_000
        let spanMeters = showYou ? min(8_000, max(700, distance * 2.6)) : 900
        let side = spanMeters * MKMapPointsPerMeterAtLatitude(place.coords.lat)
        let placeY = 0.58
        let rect = MKMapRect(x: target.x - side / 2, y: target.y - side * placeY, width: side, height: side)
        pick.mapFile = file
        pick.placeX = 0.5
        pick.placeY = placeY
        if showYou {
            let you = MKMapPoint(here.location)
            let x = (you.x - rect.minX) / side
            let y = (you.y - rect.minY) / side
            if (0.06...0.94).contains(x) && (0.06...0.94).contains(y) {
                pick.youX = x
                pick.youY = y
            }
        }
        let key = "\(place.id)|\(Int(here.lat * 2_000))|\(Int(here.lng * 2_000))|\(Int(spanMeters))"
        guard key != mapKey else { return }
        mapKey = key
        renderMap(rect, to: file)
    }

    /// A clean, muted map with no points of interest, drawn off the main thread.
    @MainActor
    private static func renderMap(_ rect: MKMapRect, to file: String) {
        let options = MKMapSnapshotter.Options()
        options.mapRect = rect
        options.size = CGSize(width: 350, height: 350)
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        options.preferredConfiguration = configuration
        options.traitCollection = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .light), UITraitCollection(displayScale: 2),
        ])
        let next = MKMapSnapshotter(options: options)
        snapshotter?.cancel()
        snapshotter = next
        next.start(with: queue) { snapshot, _ in
            guard let image = snapshot?.image else {
                Task { @MainActor in mapKey = nil }
                return
            }
            SharedStore.writeImage(image, named: file, maxSide: 700)
            Task { @MainActor in
                snapshotter = nil
                scheduleReload()
            }
        }
    }

    /// Copy a bundled photo, or one saved on the phone, into the App Group off
    /// the main thread, only when it changed.
    @MainActor
    static func copy(asset: String? = nil, path: URL? = nil, to file: String, maxSide: CGFloat) {
        let source = asset ?? path?.path ?? ""
        guard !source.isEmpty, lastImages[file] != source else { return }
        lastImages[file] = source
        queue.async {
            guard let image = asset.flatMap({ UIImage(named: $0) }) ?? path.flatMap({ UIImage(contentsOfFile: $0.path) }) else { return }
            SharedStore.writeImage(image, named: file, maxSide: maxSide)
            Task { @MainActor in scheduleReload() }
        }
    }

    /// Several images often land together; reload the widgets once for all of them.
    @MainActor
    private static func scheduleReload() {
        reloadTask?.cancel()
        reloadTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
            NotificationCenter.default.post(name: imagesChanged, object: nil)
        }
    }
}

extension AppStore {
    /// Nearby curated places, best for you first. Stations are not much of an adventure.
    func forYou() -> [Place] {
        rankForYou(nearbyPlaces.filter { $0.category != "transit" })
    }

    var dailyRevealed: Bool { state.dailyReveal == Format.today() }

    /// Today's pick tries for somewhere nobody on Odyssey has explored, among the
    /// places Odyssey thinks you will like most, rotating by date. Once revealed
    /// it is saved for the day so checking in does not swap it.
    func dailyPick() -> (place: Place, reason: String, rare: Bool) {
        let day = Format.today()
        var chosen: Place?
        if let saved = state.dailyPickFor, saved.date == day { chosen = self.place(saved.placeId) }
        if chosen == nil {
            let ranked = forYou()
            let fresh = Array(ranked.filter { status(of: $0).status == .new }.prefix(3))
            let open = Array(ranked.filter { status(of: $0).status != .mine }.prefix(4))
            let pool = !fresh.isEmpty ? fresh : !open.isEmpty ? open : ranked
            let dayNumber = Int(Date().timeIntervalSince1970 / 86400)
            chosen = pool.isEmpty ? seed.places[0] : pool[dayNumber % pool.count]
        }
        let place = chosen!
        let rare = status(of: place).status == .new
        return (place, why(place) + "." + (rare ? " Nobody on Odyssey has been yet." : ""), rare)
    }

    /// Open today's sealed card and keep the pick for the day.
    func revealDaily() {
        let pick = dailyPick()
        update { s in
            s.dailyReveal = Format.today()
            s.dailyPickFor = AppState.DailyPick(date: Format.today(), placeId: pick.place.id)
        }
    }
}
