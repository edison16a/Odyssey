//
//  Models.swift
//  Odyssey
//
//  Plain data shapes for everything in seed.json, which is exported from the
//  HTML mockup by tools/export-seed.mjs. Field names match the mockup, so the
//  JSON decodes directly. Optional fields are the ones only some records have.
//

import Foundation
import SwiftUI

/// A place you can explore: one of Odyssey's curated places or one from
/// OpenStreetMap (source "osm", which also carries cats and tags).
nonisolated struct Place: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var category: String?
    var coords: Coord
    var photo: String
    var address: String?
    var rating: Double?
    var reviews: Int?
    /// "explored" or "unexplored" (nobody on Odyssey has been yet).
    var status: String?
    var blurb: String?
    var hours: String?
    var area: String?
    var cats: [String]?
    var tags: [String: String]?
    var photoKind: String?
    var curated: String?
    var website: String?
    var source: String?
    /// Every photo of the place, first one first. Optional so older data still decodes.
    var photos: [String]?

    var isOSM: Bool { source == "osm" }
    /// The photos to page through: `photos` when there are any, otherwise the single `photo`.
    var gallery: [String] {
        if let photos, !photos.isEmpty { return photos }
        return photo.isEmpty ? [] : [photo]
    }
    var areaID: String { area ?? "berkeley" }
}

nonisolated struct Avatar: Codable, Hashable, Sendable {
    /// "photo" (a bundled image), "local" (a file the user took) or "none".
    var kind: String
    var value: String?
}

nonisolated struct Person: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var handle: String
    var avatar: Avatar
    var frame: String
    var rank: Int
    var xp: Int
    var explored: Int
    var contributions: Int
    var friend: Bool
    var city: String
    var bio: String
    var effect: String?
    var icon: String?
    var banner: String?

    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }
}

nonisolated struct Contact: Codable, Hashable, Sendable {
    var name: String
    var detail: String
    var onOdyssey: Bool
}

nonisolated struct Milestone: Codable, Hashable, Sendable {
    var type: String
    var big: String?
    var eyebrow: String
    var line: String
    var sub: String
    var color: String
    var tier: Int?
    var photo: Bool?
}

/// A Strava style day post: the route of a whole day out.
nonisolated struct DayPost: Codable, Hashable, Sendable {
    var title: String
    var when: String
    var km: Double
    var time: String
    var firsts: Int
    var stops: [String]
}

nonisolated struct Post: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var by: String
    var placeId: String
    /// "visit", "walk", "milestone" or "day".
    var kind: String
    var minutesAgo: Int
    var caption: String
    var seconds: Int?
    var first: Bool?
    var likes: Int
    var comments: Int
    var milestone: Milestone?
    var day: DayPost?
    var createdAt: Date?
}

nonisolated struct Rank: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var xp: Int
    var color: String
    var perk: String
}

nonisolated struct Badge: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var icon: String
    var color: String
    var desc: String
    var streak: Int?
}

nonisolated struct Scope: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var label: String
    var population: Double
    var spread: Double
}

nonisolated struct Explorer: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var years: String
    var region: String
    var glyph: String
    var color: String
    var tier: Int
    var known: String
    var trait: String
    var benchmarkKm: Double
}

/// A shop item: frame, effect or title. Earned items have no price.
nonisolated struct Cosmetic: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var price: Int?
    var rarity: String
    var desc: String?
    var earnedBy: String?
    var streak: Int?
}

nonisolated struct Banner: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var city: String?
    var label: String
    var photo: String
    var price: Int?
    var rarity: String
    var focus: String?
    var placeId: String?
    var earnedBy: String?
    var streak: Int?
}

nonisolated struct CoinPack: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var coins: Int
    var price: String
}

nonisolated struct Boost: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var desc: String
    var price: Int
    var icon: String
}

nonisolated struct Quest: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var placeId: String
    /// "visit", "first" or "walk".
    var kind: String
    var rarity: String
    var multiplier: Int
    var withFriend: Bool?
    var title: String
    var coins: Int
    var xp: Int
    var ends: String

    var needsFriend: Bool { withFriend ?? false }
}

nonisolated struct QuestRarity: Codable, Hashable, Sendable {
    var label: String
    var color: String
    var odds: String
}

nonisolated struct AppNotification: Codable, Identifiable, Hashable, Sendable {
    nonisolated struct Target: Codable, Hashable, Sendable {
        var post: String?
        var place: String?
        var request: String?
        var screen: String?
    }
    var id: String
    var kind: String
    var by: String?
    var text: String
    var minutesAgo: Int
    var open: Target?
}

nonisolated struct Question: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var prompt: String
    var sub: String
    var photo: String
    var icon: String
}

nonisolated struct RecapStop: Codable, Hashable, Sendable {
    var placeId: String
    var time: String
    var action: String
    var coins: Int
    var xp: Int
    var note: String?
    var seconds: Int?
    var first: Bool?
}

nonisolated struct Recap: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var area: String?
    var date: String
    var title: String
    var start: String
    var movingMin: Int
    var stops: [RecapStop]
}

nonisolated struct GiftCard: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var color: String
    var accent: String?
    var logo: String
    var amounts: [Int]
    var tag: String?
}

nonisolated struct Area: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var city: String
    var neighborhood: String
    var region: String
    var center: Coord
    var me: Coord
    var spot: String
}

nonisolated struct Category: Codable, Hashable, Sendable {
    var label: String
    var icon: String
}

nonisolated struct DiscoverCategory: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var label: String
    var one: String
    var icon: String
    var heading: String
    var osm: [[String]]
}

/// A raw place from the OpenStreetMap snapshot or a live Overpass answer.
nonisolated struct OSMRaw: Codable, Hashable, Sendable {
    var id: String
    var name: String
    var lat: Double
    var lng: Double
    var cats: [String]
    var tags: [String: String]
}

nonisolated struct DiscoverArea: Codable, Hashable, Sendable {
    var label: String
    var center: Coord
    var places: [OSMRaw]
}

nonisolated struct Country: Codable, Hashable, Sendable {
    var name: String
    var flag: String
    var first: String?
}

nonisolated struct TravelData: Codable, Hashable, Sendable {
    var countries: [String]
    var states: [String]
    /// Walked routes per city; a city with a trail counts as explored.
    var trails: [String: [Coord]]
}

/// Real outlines around explored places, from tools/build-explored.mjs in the mockup.
nonisolated struct ExploredShapes: Codable, Sendable {
    nonisolated struct Shape: Codable, Sendable {
        var kind: String
        var rings: [[Coord]]?
        var streets: [String: [Double]]?
    }
    nonisolated struct Street: Codable, Sendable {
        /// A few small paths in OpenStreetMap have no name.
        var name: String?
        var line: [Coord]
    }
    nonisolated struct Region: Codable, Sendable {
        var id: String
        var name: String
        var rings: [[Coord]]
    }
    var shapes: [String: Shape]
    var streets: [String: Street]
    var cities: [Region]
    var states: [Region]
}

/// Turns a mockup media path into the asset catalog name tools/build-assets.py made.
nonisolated enum Media {
    static func name(for path: String) -> String {
        var name = path
        for prefix in ["assets/media/", "assets/vendor/", "assets/"] where name.hasPrefix(prefix) {
            name = String(name.dropFirst(prefix.count))
            break
        }
        if let dot = name.lastIndex(of: ".") { name = String(name[..<dot]) }
        return name.replacingOccurrences(of: "/", with: "-")
    }
}

extension Color {
    /// Rarity colors from the shop.
    static func rarity(_ rarity: String) -> Color {
        switch rarity {
        case "common": return Color(hex: "#17a35a")
        case "rare": return Color(hex: "#2b59ff")
        case "epic": return Color(hex: "#8a5cff")
        case "legendary": return Color(hex: "#f2b21b")
        case "earned": return Color(hex: "#d39b00")
        default: return Color(hex: "#a1a1aa")
        }
    }
}
