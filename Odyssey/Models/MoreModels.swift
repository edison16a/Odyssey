//
//  MoreModels.swift
//  Odyssey
//
//  The rest of seed.json: business bounties and their areas, the winter
//  season, the demo trip to Paris, the demo walks and the photo credits.
//  Read from the same file as Seed, kept apart so each stays readable.
//

import Foundation

nonisolated struct BountyTarget: Codable, Hashable, Sendable {
    /// "place" or "area".
    var kind: String
    var placeId: String?
    var name: String?
}

/// A business paying explorers for walkthroughs of a place or an area.
nonisolated struct Bounty: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var sponsor: String
    var logo: String
    var color: String
    var title: String
    var target: BountyTarget
    var center: Coord
    var radius: Double
    var pool: Double
    /// "videos" pays per walkthrough, "even" splits the pool across the crew.
    var split: String
    var firstBonus: Double
    var videos: Int
    var recorded: Int
    var days: Int
    var crew: [String]
    var mine: Bool?
    /// Filled in by the store: what you earned from it so far.
    var earned: Double?
}

nonisolated struct BountyArea: Codable, Identifiable, Hashable, Sendable {
    var area: String
    var id: String
    var name: String
    var center: Coord
    var radius: Double
}

nonisolated struct SeasonQuest: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var glyph: String
    var color: String
    var spot: String
    var km: Double
    var coins: Int
}

nonisolated struct Season: Codable, Hashable, Sendable {
    nonisolated struct Reward: Codable, Hashable, Sendable {
        var title: String
        var coins: Int
    }
    var id: String
    var name: String
    var ends: String
    var goal: Int
    var reward: Reward
    var quests: [SeasonQuest]
}

nonisolated struct DemoTrip: Codable, Hashable, Sendable {
    var country: String
    var city: String
    var coords: Coord
    var trail: [Coord]
}

nonisolated struct Credit: Codable, Hashable, Sendable {
    var file: String
    var title: String
    var creator: String
    var license: String
    var url: String
}

nonisolated struct SeedExtras: Decodable, Sendable {
    var bounties: [Bounty]
    var bountyAreas: [BountyArea]
    var season: Season
    var demoTrip: DemoTrip
    var demoWalk: [Coord]
    var demoWalkSf: [Coord]
    var credits: [Credit]

    static let shared: SeedExtras = {
        guard let url = Bundle.main.url(forResource: "seed", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let extras = try? JSONDecoder().decode(SeedExtras.self, from: data) else {
            fatalError("seed.json is missing its bounty, season or travel data")
        }
        return extras
    }()

    func seasonQuest(_ id: String) -> SeasonQuest? { season.quests.first { $0.id == id } }
}
