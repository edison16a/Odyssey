//
//  WorldPlaces.swift
//  Odyssey
//
//  Every shop, cafe, park and museum around you, wherever you are. Two free
//  sources are merged: Apple Maps points of interest (through MapKit, no key
//  needed) and OpenStreetMap through Overpass. Apple is good at shops and
//  restaurants, OpenStreetMap at parks, libraries and small local spots, so
//  together they cover nearly everything. The same place from both is kept
//  once.
//
//  The world is loaded in tiles about a kilometre across, each one at most
//  once per launch, and lands in the store in a single change so the map
//  redraws once.
//

import CoreLocation
import Foundation
import MapKit

enum WorldPlaces {
    @MainActor private static var loaded: Set<String> = []
    @MainActor private static var loading: Set<String> = []

    /// Apple categories, grouped so each search stays under MapKit's result cap.
    private static let groups: [[MKPointOfInterestCategory]] = [
        [.cafe, .bakery],
        [.restaurant],
        [.store],
        [.park, .beach, .nationalPark],
        [.museum, .theater, .movieTheater, .library, .university, .amusementPark, .zoo, .aquarium],
        [.nightlife, .brewery, .winery, .fitnessCenter, .gasStation, .stadium],
    ]

    private static func tile(_ c: Coord) -> String {
        String(format: "%.2f,%.2f", (c.lat * 100).rounded() / 100, (c.lng * 100).rounded() / 100)
    }

    /// Load the places around a point unless that tile is already in.
    @MainActor
    static func load(around center: Coord, store: AppStore) async {
        let key = tile(center)
        guard !loaded.contains(key), !loading.contains(key) else { return }
        loading.insert(key)
        defer { loading.remove(key) }

        async let osm = NearbyService.fetchLive(center: center, store: store)
        async let apple = searchApple(center: center)
        let fromApple = await apple
        // Show Apple's pins immediately; an unavailable Overpass mirror can take much longer.
        register(fromApple, center: center, store: store)
        let fromOSM = await osm ?? []
        register(fromOSM, center: center, store: store)
        if !fromOSM.isEmpty || !fromApple.isEmpty { loaded.insert(key) }
    }

    @MainActor
    private static func register(_ batch: [OSMRaw], center: Coord, store: AppStore) {
        var all = store.osmPlaces
        var kept = store.seed.places + all.values.filter { $0.coords.distance(to: center) < 2500 }
        for raw in batch {
            let place = NearbyService.normalize(raw, store: store, register: false)
            if all[place.id] == nil, !duplicate(place, in: kept) {
                all[place.id] = place
                kept.append(place)
            }
        }
        store.osmPlaces = all
    }

    private static func duplicate(_ place: Place, in list: [Place]) -> Bool {
        list.contains { $0.coords.distance(to: place.coords) < 40 && sameName($0.name, place.name) }
    }

    /// "Blue Bottle Coffee" and "Blue Bottle" are the same spot.
    private static func sameName(_ a: String, _ b: String) -> Bool {
        let x = a.lowercased(), y = b.lowercased()
        if x == y || x.hasPrefix(y) || y.hasPrefix(x) { return true }
        let first = { (s: String) in s.split(separator: " ").first.map(String.init) ?? s }
        return first(x).count > 3 && first(x) == first(y)
    }

    private static func searchApple(center: Coord) async -> [OSMRaw] {
        await withTaskGroup(of: [OSMRaw].self) { group in
            for categories in groups {
                group.addTask { await search(center: center, categories: categories) }
            }
            var out: [OSMRaw] = []
            for await batch in group { out += batch }
            return out
        }
    }

    private static func search(center: Coord, categories: [MKPointOfInterestCategory]) async -> [OSMRaw] {
        let request = MKLocalPointsOfInterestRequest(center: center.location, radius: 1000)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: categories)
        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }
        return response.mapItems.compactMap(raw)
    }

    /// One Apple map item in the same shape as an OpenStreetMap feature.
    private static func raw(_ item: MKMapItem) -> OSMRaw? {
        guard let name = item.name, !name.isEmpty, let category = item.pointOfInterestCategory,
              let cat = category.discoverID else { return nil }
        let mark = item.placemark
        let c = mark.coordinate
        var tags = ["source": "apple"]
        tags["addr:housenumber"] = mark.subThoroughfare
        tags["addr:street"] = mark.thoroughfare
        tags["website"] = item.url?.absoluteString
        tags["phone"] = item.phoneNumber
        let id = "a" + String(StableHash.fnv("\(name)|\(Int(c.latitude * 10_000))|\(Int(c.longitude * 10_000))"))
        return OSMRaw(id: id, name: name, lat: c.latitude, lng: c.longitude, cats: [cat], tags: tags)
    }
}

extension MKPointOfInterestCategory {
    /// The Explore category an Apple category belongs to.
    var discoverID: String? {
        switch self {
        case .cafe: return "coffee"
        case .bakery: return "dessert"
        case .restaurant: return "food"
        case .store: return "shopping"
        case .park, .beach, .nationalPark: return "park"
        case .library: return "library"
        case .university: return "study"
        case .museum, .theater, .movieTheater, .amusementPark, .zoo, .aquarium, .stadium: return "entertainment"
        case .nightlife, .brewery, .winery: return "nightlife"
        case .fitnessCenter: return "fitness"
        case .gasStation: return "gas"
        default: return nil
        }
    }
}

extension Place {
    /// True for places found through Apple Maps, which asks for a credit line.
    var fromAppleMaps: Bool { source == "apple" || tags?["source"] == "apple" }
}
