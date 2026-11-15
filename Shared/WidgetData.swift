//
//  WidgetData.swift
//  Shared by the app and the widgets.
//
//  The app writes a small snapshot of what the widgets show (streak, coins,
//  today's adventure, friends out exploring, the next quest) into the App
//  Group container every time something changes. Widgets only ever read it,
//  so they never need the app's full state or seed data.
//

import Foundation
import ImageIO
import SwiftUI
import UIKit

/// One recommended place, already worked out by the app.
nonisolated struct AdventurePick: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var name: String
    var kind: String
    var symbol: String
    var distanceMeters: Double
    var coins: Int
    var isFirst: Bool
    var reason: String
    var imageFile: String?
    /// A static map around the place, rendered by the app for the widget.
    var mapFile: String?
    /// Where the place and you sit on that map, as 0 to 1 fractions of its width and height.
    var placeX: Double?
    var placeY: Double?
    var youX: Double?
    var youY: Double?

    var walkMinutes: Int { max(1, Int((distanceMeters / 80).rounded())) }
    var distanceText: String {
        distanceMeters < 1000 ? "\(Int((distanceMeters / 10).rounded()) * 10) m" : String(format: "%.1f km", distanceMeters / 1000)
    }
}

nonisolated struct FriendActivity: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var name: String
    var place: String
    var minutesAgo: Int
    var imageFile: String?

    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }
    var agoText: String {
        if minutesAgo < 1 { return "now" }
        if minutesAgo < 60 { return "\(minutesAgo)m" }
        if minutesAgo < 1440 { return "\(minutesAgo / 60)h" }
        return "\(minutesAgo / 1440)d"
    }
}

nonisolated struct QuestSnapshot: Codable, Hashable, Sendable {
    var title: String
    var rarity: String
    var colorHex: String
    var coins: Int
    var xp: Int
    var ends: String
    var placeName: String
    var placeID: String
}

nonisolated struct WidgetSnapshot: Codable, Sendable {
    var name: String
    var streakDays: Int
    var bestStreak: Int
    /// "yyyy-MM-dd" of the last day that counted, so widgets can tell after midnight.
    var streakLastDay: String?
    var coins: Int
    var xp: Int
    var rankName: String
    var rankColorHex: String
    var nextRankName: String?
    var rankProgress: Double
    var placesExplored: Int
    var firstFinds: Int
    var adventure: AdventurePick?
    var picks: [AdventurePick]
    var friends: [FriendActivity]
    var quest: QuestSnapshot?
    var updatedAt: Date
    /// This week's board of friends and you, and your best city standing. Older saves have neither.
    var board: [BoardEntry]? = nil
    var standing: StandingSnapshot? = nil

    var claimedToday: Bool { streakLastDay == WidgetDay.key(Date()) }
    var tier: StreakTier { StreakTiers.tier(for: streakDays) }
    var nextTier: StreakTier? { StreakTiers.next(after: streakDays) }

    var mood: GlobieMood {
        if streakDays == 0 { return .sad }
        if claimedToday && StreakTiers.milestones.contains(streakDays) { return .ecstatic }
        return claimedToday ? .happy : .sleepy
    }

    /// The last seven days, oldest first, marked done while inside the streak.
    func week(on date: Date = Date()) -> [(letter: String, done: Bool, today: Bool)] {
        WidgetSnapshot.streakWeek(days: streakDays, lastDay: streakLastDay, on: date)
    }

    static func streakWeek(days streakDays: Int, lastDay: String?, on date: Date = Date()) -> [(letter: String, done: Bool, today: Bool)] {
        let letters = ["S", "M", "T", "W", "T", "F", "S"]
        let calendar = Calendar.current
        let claimedToday = lastDay == WidgetDay.key(date)
        let before = streakDays - (claimedToday ? 1 : 0)
        return (0..<7).map { i in
            let back = 6 - i
            let day = calendar.date(byAdding: .day, value: -back, to: date) ?? date
            let weekday = calendar.component(.weekday, from: day) - 1
            return (letters[weekday], back == 0 ? claimedToday : back <= before, back == 0)
        }
    }

    static let placeholder = WidgetSnapshot(
        name: "Edison Law", streakDays: 6, bestStreak: 21, streakLastDay: nil, coins: 1240, xp: 640,
        rankName: "Pathfinder", rankColorHex: "#2b59ff", nextRankName: "Voyager", rankProgress: 0.35,
        placesExplored: 48, firstFinds: 3,
        adventure: AdventurePick(id: "piccino", name: "Long Bridge Pizza", kind: "Food", symbol: "fork.knife",
                                 distanceMeters: 210, coins: 250, isFirst: true, reason: "You love good food. Independent",
                                 imageFile: "asset:widget-placeholder-photo", mapFile: "asset:widget-placeholder-map",
                                 placeX: 0.58, placeY: 0.4, youX: 0.34, youY: 0.68),
        picks: [],
        friends: [
            FriendActivity(id: "nina", name: "Nina Park", place: "Soda Hall", minutesAgo: 34, imageFile: nil),
            FriendActivity(id: "jordan", name: "Jordan Ellis", place: "Caffe Strada", minutesAgo: 55, imageFile: nil),
            FriendActivity(id: "marco", name: "Marco Silva", place: "Cheese Board Pizza", minutesAgo: 60, imageFile: nil),
        ],
        quest: QuestSnapshot(title: "Catch the sunset at Indian Rock with a friend", rarity: "Mythical", colorHex: "#d39b00",
                             coins: 400, xp: 150, ends: "Ends in 5h 12m", placeName: "Indian Rock", placeID: "indian-rock"),
        updatedAt: Date(), board: BoardEntry.samples,
        standing: StandingSnapshot(position: 87, pct: 4, scope: "San Francisco"))
}

nonisolated enum WidgetDay {
    static func key(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// The widgets Odyssey offers. The app's gallery and the extension share this list.
nonisolated enum OdysseyWidgetKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case streak, adventure, coins, friends, quest, leaderboard

    var id: String { rawValue }
    /// The kind string WidgetKit uses for this widget.
    var kindID: String { "odyssey.\(rawValue)" }

    var title: String {
        switch self {
        case .streak: return "Streak"
        case .adventure: return "Today's Adventure"
        case .coins: return "Coins and Rank"
        case .friends: return "Friends Exploring"
        case .quest: return "Quest"
        case .leaderboard: return "Leaderboard"
        }
    }

    var blurb: String {
        switch self {
        case .streak: return "Globie wakes up when today counts and changes form at every milestone."
        case .adventure: return "One place picked for you each day, with the coins waiting there."
        case .coins: return "Your balance and how close you are to the next rank."
        case .friends: return "Who is out exploring right now, and where."
        case .quest: return "The quest you are working on and how long is left."
        case .leaderboard: return "Where you stand this week against friends and your city."
        }
    }

    var symbol: String {
        switch self {
        case .streak: return "flame.fill"
        case .adventure: return "location.north.fill"
        case .coins: return "circle.hexagongrid.fill"
        case .friends: return "person.2.fill"
        case .quest: return "flag.fill"
        case .leaderboard: return "trophy.fill"
        }
    }

    var sizes: [WidgetSize] {
        switch self {
        case .streak: return [.small, .medium, .circular, .rectangular, .inline]
        case .adventure: return [.small, .medium, .rectangular]
        case .coins: return [.small, .circular, .rectangular]
        case .friends: return [.medium]
        case .quest: return [.small, .medium, .rectangular]
        case .leaderboard: return [.small, .medium, .large, .rectangular]
        }
    }

    var defaultStyle: WidgetStyle {
        switch self {
        case .streak: return .globie
        case .adventure: return .map
        case .coins, .friends, .quest, .leaderboard: return .vivid
        }
    }

    var styles: [WidgetStyle] {
        switch self {
        case .adventure: return [.map, .photo, .light, .dark]
        case .streak: return [.globie, .light, .dark]
        case .leaderboard: return [.vivid, .light, .dark]
        default: return [.vivid, .light, .dark, .globie]
        }
    }
}

nonisolated enum WidgetSize: String, Codable, Sendable, CaseIterable {
    case small, medium, large, circular, rectangular, inline

    var label: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .circular: return "Lock Screen circle"
        case .rectangular: return "Lock Screen"
        case .inline: return "Above the clock"
        }
    }

    var isAccessory: Bool { self == .circular || self == .rectangular || self == .inline }

    /// Point size on a 6.1 inch iPhone, used for in app previews.
    var previewSize: CGSize {
        switch self {
        case .small: return CGSize(width: 158, height: 158)
        case .medium: return CGSize(width: 338, height: 158)
        case .large: return CGSize(width: 338, height: 354)
        case .circular: return CGSize(width: 72, height: 72)
        case .rectangular: return CGSize(width: 160, height: 72)
        case .inline: return CGSize(width: 240, height: 26)
        }
    }
}

nonisolated enum WidgetStyle: String, Codable, Sendable, CaseIterable, Identifiable {
    case light, dark, globie, photo, map, vivid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .globie: return "Streak form"
        case .photo: return "Photo"
        case .map: return "Map"
        case .vivid: return "Color"
        }
    }
}

/// What the explorer chose in the app's widget editor.
nonisolated struct WidgetPrefs: Codable, Equatable, Sendable {
    var styles: [String: WidgetStyle] = [:]
    var showWeek = true
    var showReason = true
    var showNextRank = true
    var friendCount = 3

    func style(for kind: OdysseyWidgetKind) -> WidgetStyle {
        styles[kind.rawValue] ?? kind.defaultStyle
    }
}

/// Reads and writes the files the app and widgets share.
nonisolated enum SharedStore {
    static let groupID = "group.com.edisonlaw.Odyssey"

    /// The App Group folder, or the app's own documents if the group is not set up yet.
    static var container: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            return url
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func url(_ name: String) -> URL { container.appendingPathComponent(name) }

    static func read<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    static func write<T: Encodable>(_ value: T, to name: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url(name), options: .atomic)
    }

    static func snapshot() -> WidgetSnapshot { read(WidgetSnapshot.self, from: "widget-snapshot.json") ?? .placeholder }
    static func save(_ snapshot: WidgetSnapshot) { write(snapshot, to: "widget-snapshot.json") }
    static func prefs() -> WidgetPrefs { read(WidgetPrefs.self, from: "widget-prefs.json") ?? WidgetPrefs() }
    static func save(_ prefs: WidgetPrefs) { write(prefs, to: "widget-prefs.json") }

    /// A small JPEG the app left for the widgets, such as today's adventure photo.
    /// Widget images stay decoded in memory until the file on disk changes.
    nonisolated(unsafe) private static let imageCache = NSCache<NSString, UIImage>()

    /// A shared image, decoded already shrunk to `maxSide` pixels. Widgets live in about 30 MB
    /// and WidgetKit refuses to draw a widget whose images add up to too many pixels, so
    /// nothing here is ever decoded at full size.
    static func image(_ file: String?, maxSide: CGFloat = 480) -> UIImage? {
        guard let file, !file.isEmpty else { return nil }
        // "asset:" names come from the widget's own asset catalog, for previews.
        if file.hasPrefix("asset:") {
            let name = String(file.dropFirst(6))
            let key = "\(name)@asset@\(Int(maxSide))" as NSString
            if let hit = imageCache.object(forKey: key) { return hit }
            guard let full = UIImage(named: name) else { return nil }
            let image = shrink(full, maxSide: maxSide)
            imageCache.setObject(image, forKey: key)
            return image
        }
        let path = url(file).path
        let stamp = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let key = "\(file)@\(stamp)@\(Int(maxSide))" as NSString
        if let hit = imageCache.object(forKey: key) { return hit }
        guard let image = thumbnail(at: url(file), maxSide: maxSide) else { return nil }
        imageCache.setObject(image, forKey: key)
        return image
    }

    /// Decode straight to a small bitmap with ImageIO, never holding the full image.
    private static func thumbnail(at url: URL, maxSide: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxSide),
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    private static func shrink(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let pixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let ratio = maxSide / max(pixels.width, pixels.height)
        guard ratio < 1 else { return image }
        let target = CGSize(width: (pixels.width * ratio).rounded(), height: (pixels.height * ratio).rounded())
        return image.preparingThumbnail(of: target) ?? image
    }

    static func writeImage(_ image: UIImage, named file: String, maxSide: CGFloat = 700) {
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = resized.jpegData(compressionQuality: 0.8) else { return }
        try? data.write(to: url(file), options: .atomic)
    }
}
