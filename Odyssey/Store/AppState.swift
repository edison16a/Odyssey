//
//  AppState.swift
//  Odyssey
//
//  Everything the app remembers, in one value saved as JSON on the phone.
//  It keeps the mockup's shape (the seed's initialState decodes straight
//  into it), and every field decodes with a fallback so a save from an
//  older build still opens after new fields are added.
//

import Foundation

nonisolated struct AppState: Codable, Sendable {
    nonisolated struct Session: Codable, Sendable {
        var signedIn = false
        var email = ""
        var onboarded = false
    }

    nonisolated struct User: Codable, Sendable {
        var id = "me"
        var name = "Edison Law"
        var handle = "edisonlaw"
        var bio = ""
        var city = "Berkeley"
        var avatar = Avatar(kind: "none", value: nil)
        var sampleSelfie: String? = "assets/media/people/p09.jpg"
    }

    nonisolated struct Wallet: Codable, Sendable {
        var coins = 1240
        var xp = 640
        var points = 340
        var cash = 16.65
    }

    nonisolated struct Streak: Codable, Sendable {
        var days = 6
        var lastDay: String?
        var best = 21
    }

    nonisolated struct Stats: Codable, Sendable {
        var friends = 128
        var explored = 48
        var contributions = 23
        var km = 212.0
    }

    nonisolated struct Equipped: Codable, Sendable {
        var frame = "dual"
        var banner = "city-san-francisco"
        var effect = "embers"
        var title = "trailblazer"
        var explorer = "ibn-battuta"
        var badges: [String] = ["first-explorer", "scholar", "streak-7"]
    }

    /// What a walkthrough taught Odyssey about a place.
    nonisolated struct Insights: Codable, Hashable, Sendable {
        var vibe: String?
        var summary: String?
        var tags: [String]?
        var source: String?
    }

    nonisolated struct Video: Codable, Hashable, Sendable {
        var date: String
        var seconds: Int
        var insights: Insights?
    }

    nonisolated struct Vote: Codable, Hashable, Sendable {
        var v: Int
        var name: String
        var features: [String]
        var at: Double
    }

    nonisolated struct Taste: Codable, Sendable {
        var weights: [String: Double] = [:]
        var votes: [String: Vote] = [:]
    }

    /// Where the Explore tab is looking: a saved demo area or the phone's location.
    nonisolated struct DiscoverLocation: Codable, Hashable, Sendable {
        var id: String
        var label: String?
        var center: Coord?
        var gps: Bool?
    }

    var version = 9
    var session = Session()
    var interests: [String: Bool] = ["startups": true, "coffee": true, "culture": true]
    var user = User()
    var wallet = Wallet()
    var streak = Streak()
    var stats = Stats()
    /// The default look (Dual Element, Sparkler Globie, Ivy Vines, Trailblazer) is owned from the start.
    var owned: [String] = ["frame-dual", "banner-streak-spark", "effect-vines", "title-trailblazer",
                           "banner-city-san-francisco", "effect-embers"]
    var equipped = Equipped()
    var earnedBadges: [String] = []
    var boosts: [String: Int] = ["xp2": 0, "streak-freeze": 1]
    var demoArea = "sf"
    var checkins: [String: String] = [:]
    var videos: [String: [Video]] = [:]
    var firsts: [String] = []
    var taste = Taste()
    var placeInsights: [String: Insights] = [:]
    var discoverLocation: DiscoverLocation?
    var discoverCategory = "all"
    var savedPlaces: [String: Place] = [:]
    var questInvites: [String: [String: String]] = [:]
    var questsDone: [String: String] = [:]
    /// Today's Quests on Home: task id -> the day its reward was paid.
    var dailyTasks: [String: String] = [:]
    /// Deals claimed through Whop (mocked): deal id to the discount code.
    var claimedDeals: [String: String] = [:]
    /// Sources connected in onboarding: "photos", "google", "yelp".
    var connectedSources: [String] = []
    /// One-time tips already shown, e.g. "explore-feed".
    var tipsSeen: [String] = []
    var myPosts: [Post] = []
    var friends: [String] = []
    /// Real Odyssey users added from your contacts, keyed by their user id,
    /// so they show in your friends list like the seeded explorers do.
    var cloudPeople: [String: Person] = [:]
    var requests: [String] = []
    var storiesSeen: [String: Bool] = [:]
    var likes: [String: Bool] = [:]
    var readNotifications: [String] = []
    var visited: [String] = []
    var giftCards: [RedeemedCard] = []
    /// The day today's adventure was revealed, and the place it landed on.
    var dailyReveal: String?
    var dailyPickFor: DailyPick?
    var widgetPrefs = WidgetPrefs()
    /// Follow the phone's real location for distances and the home map.
    var useDeviceLocation = true
    /// Bounties you posted as a business, and your walkthroughs toward every bounty.
    var myBounties: [Bounty] = []
    var bountyProgress: [String: BountyProgress] = [:]
    /// Winter season quests you finished.
    var seasonDone: [String: Bool] = [:]
    /// Trails walked in the app per city, and countries and states you arrived in.
    var travelTrails: [String: [Coord]] = [:]
    var travelCountries: [String] = []
    var travelStates: [String] = []
    /// Your real walked path, thinned to a point every 15 m or so. The ground
    /// around it counts as explored; places still need a check-in to be yours.
    var footprints: [Coord] = []
    /// Keep recording footprints while the app is in the background.
    var trackInBackground = false
    /// Places you starred, kept whole so world places still open after a relaunch.
    var starred: [String: Place] = [:]
    /// Places Explore recommended to you lately; checking in at one pays a bonus.
    var recommended: [String] = []
    /// The stage demo: YC starts unclaimed and its check-in lands you on the boards.
    var demoMode = false

    nonisolated struct BountyProgress: Codable, Hashable, Sendable {
        var recorded = 0
        var earned = 0.0
    }

    nonisolated struct DailyPick: Codable, Hashable, Sendable {
        var date: String
        var placeId: String
    }

    nonisolated struct RedeemedCard: Codable, Hashable, Sendable, Identifiable {
        var id: String
        var brand: String
        var amount: Int
        var code: String
        var date: String
    }

    init() {}

    nonisolated enum CodingKeys: String, CodingKey {
        case version, session, interests, user, wallet, streak, stats, owned, equipped, earnedBadges, boosts, demoArea,
             checkins, videos, firsts, taste, placeInsights, discoverLocation, discoverCategory, savedPlaces, questInvites,
             questsDone, myPosts, friends, cloudPeople, requests, storiesSeen, likes, readNotifications, visited, giftCards, dailyReveal, dailyPickFor, widgetPrefs,
             useDeviceLocation, myBounties, bountyProgress, seasonDone, travelTrails, travelCountries, travelStates,
             footprints, trackInBackground, starred, recommended, demoMode, dailyTasks, claimedDeals, connectedSources, tipsSeen
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppState()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        version = value(.version, d.version)
        let savedVersion = version
        session = value(.session, d.session)
        interests = value(.interests, d.interests)
        // Version 6 swapped the books and travel questions for startups and cafes.
        if version < 6 {
            interests = d.interests
            version = d.version
        }
        user = value(.user, d.user)
        wallet = value(.wallet, d.wallet)
        streak = value(.streak, d.streak)
        stats = value(.stats, d.stats)
        owned = value(.owned, d.owned)
        equipped = value(.equipped, d.equipped)
        earnedBadges = value(.earnedBadges, d.earnedBadges)
        boosts = value(.boosts, d.boosts)
        demoArea = value(.demoArea, d.demoArea)
        checkins = value(.checkins, d.checkins)
        videos = value(.videos, d.videos)
        firsts = value(.firsts, d.firsts)
        taste = value(.taste, d.taste)
        placeInsights = value(.placeInsights, d.placeInsights)
        discoverLocation = value(.discoverLocation, d.discoverLocation)
        discoverCategory = value(.discoverCategory, d.discoverCategory)
        savedPlaces = value(.savedPlaces, d.savedPlaces)
        questInvites = value(.questInvites, d.questInvites)
        questsDone = value(.questsDone, d.questsDone)
        dailyTasks = value(.dailyTasks, d.dailyTasks)
        claimedDeals = value(.claimedDeals, d.claimedDeals)
        connectedSources = value(.connectedSources, d.connectedSources)
        tipsSeen = value(.tipsSeen, d.tipsSeen)
        myPosts = value(.myPosts, d.myPosts)
        friends = value(.friends, d.friends)
        cloudPeople = value(.cloudPeople, d.cloudPeople)
        requests = value(.requests, d.requests)
        storiesSeen = value(.storiesSeen, d.storiesSeen)
        likes = value(.likes, d.likes)
        readNotifications = value(.readNotifications, d.readNotifications)
        visited = value(.visited, d.visited)
        giftCards = value(.giftCards, d.giftCards)
        dailyReveal = value(.dailyReveal, d.dailyReveal)
        dailyPickFor = value(.dailyPickFor, d.dailyPickFor)
        widgetPrefs = value(.widgetPrefs, d.widgetPrefs)
        useDeviceLocation = value(.useDeviceLocation, d.useDeviceLocation)
        myBounties = value(.myBounties, d.myBounties)
        bountyProgress = value(.bountyProgress, d.bountyProgress)
        seasonDone = value(.seasonDone, d.seasonDone)
        travelTrails = value(.travelTrails, d.travelTrails)
        travelCountries = value(.travelCountries, d.travelCountries)
        travelStates = value(.travelStates, d.travelStates)
        footprints = value(.footprints, d.footprints)
        trackInBackground = value(.trackInBackground, d.trackInBackground)
        starred = value(.starred, d.starred)
        recommended = value(.recommended, d.recommended)
        demoMode = value(.demoMode, d.demoMode)
        if savedVersion < 7 { applyEdisonDemo() }
        // Version 8: the new default look, owned and worn.
        if savedVersion < 8 {
            equipped.frame = d.equipped.frame
            equipped.banner = d.equipped.banner
            equipped.effect = d.equipped.effect
            equipped.title = d.equipped.title
            for id in d.owned where !owned.contains(id) { owned.append(id) }
        }
        // Version 9: Ember Drift and the San Francisco banner become the defaults.
        if savedVersion < 9 {
            equipped.banner = d.equipped.banner
            equipped.effect = d.equipped.effect
            for id in d.owned where !owned.contains(id) { owned.append(id) }
        }
        version = d.version
    }

    /// Version 7: Edison's demo profile. Demo mode on, 15 XP short of Voyager,
    /// 11th in San Francisco so the Y Combinator check-in lifts him into the top 10,
    /// a 99 day streak, 7,281 coins and his own photo.
    private mutating func applyEdisonDemo() {
        demoMode = true
        demoArea = "sf"
        wallet.coins = 7281
        wallet.xp = 885
        wallet.points = 492
        streak.days = 99
        streak.best = max(streak.best, 99)
        if user.avatar.kind == "none" { user.avatar = Avatar(kind: "photo", value: "assets/media/people/edison.jpg") }
        visited.removeAll { $0 == "yc" }
        firsts.removeAll { $0 == "yc" }
        checkins["yc"] = nil
        questsDone["q-yc"] = nil
        earnedBadges.removeAll { $0 == "top-10" || $0 == "top-100" }
    }
}

/// The seeded content of the app, exported from the mockup into seed.json.
nonisolated struct Seed: Decodable, Sendable {
    var places: [Place]
    var categories: [String: Category]
    var areas: [String: Area]
    var people: [Person]
    var contacts: [Contact]
    var ranks: [Rank]
    var rankShare: [Double]
    var badges: [Badge]
    var scopes: [Scope]
    var explorers: [Explorer]
    var frames: [Cosmetic]
    var effects: [Cosmetic]
    var titles: [Cosmetic]
    var coinPacks: [CoinPack]
    var boosts: [Boost]
    var banners: [Banner]
    var quests: [Quest]
    var questRarity: [String: QuestRarity]
    var posts: [Post]
    var storyOrder: [String]
    var notifications: [AppNotification]
    var questions: [Question]
    var interestCategories: [String: [String]]
    var interestLabels: [String: String]
    var recaps: [Recap]
    var countries: [String: Country]
    var travel: TravelData
    var giftCards: [GiftCard]
    var coinsPerDollar: Double
    var discoverCategories: [DiscoverCategory]
    var discoverPlaces: [String: DiscoverArea]
    var categoryPhotos: [String: [String]]
    var exploredShapes: ExploredShapes
    var initialState: AppState

    static let shared: Seed = {
        guard let url = Bundle.main.url(forResource: "seed", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            fatalError("seed.json is missing from the app bundle")
        }
        do {
            var seed = try JSONDecoder().decode(Seed.self, from: data)
            BoardRewards.extend(&seed)
            return seed
        } catch {
            fatalError("seed.json could not be read: \(error)")
        }
    }()

    func discoverCategory(_ id: String) -> DiscoverCategory? { discoverCategories.first { $0.id == id } }
    func person(_ id: String) -> Person? { people.first { $0.id == id } }
    func banner(_ id: String) -> Banner? { banners.first { $0.id == id } }
    func badge(_ id: String) -> Badge? { badges.first { $0.id == id } }
    func quest(_ id: String) -> Quest? { quests.first { $0.id == id } }
    func explorer(_ id: String) -> Explorer? { explorers.first { $0.id == id } }

    /// Tier index for a lifetime XP total.
    func rankIndex(for xp: Int) -> Int {
        var tier = 0
        for (i, rank) in ranks.enumerated() where xp >= rank.xp { tier = i }
        return tier
    }

    /// Categories an OpenStreetMap feature belongs to, from its tags.
    func categories(for tags: [String: String]) -> [String] {
        var cats = discoverCategories.filter { cat in cat.osm.contains { pair in pair.count == 2 && tags[pair[0]] == pair[1] } }.map(\.id)
        let wifi = ["wlan", "yes", "wifi"].contains(tags["internet_access"] ?? "")
        if tags["amenity"] == "cafe" && wifi && !cats.contains("study") { cats.append("study") }
        return cats
    }
}
