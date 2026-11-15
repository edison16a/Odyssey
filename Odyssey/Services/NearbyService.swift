//
//  NearbyService.swift
//  Odyssey
//
//  What is around you for the Explore tab. With your real location Odyssey
//  asks the OpenStreetMap Overpass API, trying public mirrors in turn and
//  remembering answers for the session. The prepared areas (Dogpatch, the
//  Mission, Berkeley, Shibuya) come from the snapshot bundled in seed.json,
//  which is also the fallback when every mirror is down. WorldPlaces uses
//  the same fetch for the home map, wherever you are.
//  Ported from services/nearby.js.
//

import Foundation
import MapKit

struct NearbyResult {
    var places: [Place]
    var live: Bool
    var note: String
}

enum NearbyService {
    private static let mirrors = [
        "https://overpass-api.de/api/interpreter",
        "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter",
    ]
    private static let radius = 1200
    @MainActor private static var cache: [String: [OSMRaw]] = [:]

    /// The prepared areas, in the order the picker shows them.
    static func locations(_ store: AppStore) -> [(id: String, label: String, center: Coord)] {
        ["sf-dogpatch", "sf-mission", "berkeley", "tokyo-shibuya"].compactMap { id in
            store.seed.discoverPlaces[id].map { (id, $0.label, $0.center) }
        }
    }

    static func choose(_ id: String, store: AppStore) {
        store.update { s in s.discoverLocation = AppState.DiscoverLocation(id: id, label: nil, center: nil, gps: nil) }
    }

    /// Switch Explore to the phone's location. Returns false when permission is off.
    static func useDevice(store: AppStore, location: LocationService) async -> Bool {
        guard let coord = await location.currentLocation() else { return false }
        let rounded = Coord((coord.lat * 100_000).rounded() / 100_000, (coord.lng * 100_000).rounded() / 100_000)
        let label = await location.name(rounded)
        store.update { s in s.discoverLocation = AppState.DiscoverLocation(id: "gps", label: label, center: rounded, gps: true) }
        return true
    }

    /// Places around the Explore location.
    static func around(store: AppStore) async -> NearbyResult {
        let result = await aroundUnregistered(store: store)
        // One assignment instead of one per place, so the app redraws once.
        var all = store.osmPlaces
        for place in result.places { all[place.id] = place }
        store.osmPlaces = all
        return result
    }

    private static func aroundUnregistered(store: AppStore) async -> NearbyResult {
        let loc = store.exploreLocation
        if !loc.gps, let area = store.seed.discoverPlaces[loc.id] {
            return NearbyResult(places: area.places.map { normalize($0, store: store, register: false) }, live: false, note: "")
        }
        if let raw = await fetchLive(center: loc.center, store: store) {
            return NearbyResult(places: raw.map { normalize($0, store: store, register: false) }, live: true, note: "")
        }
        let areas = store.seed.discoverPlaces.values.sorted { $0.center.distance(to: loc.center) < $1.center.distance(to: loc.center) }
        guard let nearest = areas.first else { return NearbyResult(places: [], live: false, note: "") }
        let close = nearest.center.distance(to: loc.center) < 900
        return NearbyResult(places: nearest.places.map { normalize($0, store: store, register: false) }, live: false,
                            note: close ? "" : "Could not reach OpenStreetMap, showing \(nearest.label)")
    }

    /// A curated Odyssey place within 60 m with the same first word lends its real photo.
    private static func curatedMatch(_ name: String, _ coords: Coord, store: AppStore) -> Place? {
        let word = name.lowercased().split(separator: " ").first.map(String.init) ?? ""
        return store.seed.places.first { p in
            p.coords.distance(to: coords) < 60 && (p.name.lowercased().split(separator: " ").first.map(String.init) ?? "") == word
        }
    }

    /// One place shape for everything, registered so its page can open by id.
    static func normalize(_ raw: OSMRaw, store: AppStore, register: Bool = true) -> Place {
        let coords = Coord(raw.lat, raw.lng)
        let t = raw.tags
        let match = curatedMatch(raw.name, coords, store: store)
        let cat = raw.cats.first ?? "food"
        let pool = store.seed.categoryPhotos[cat] ?? store.seed.categoryPhotos["food"] ?? []
        let photo = match?.photo ?? (pool.isEmpty ? "" : pool[Int(StableHash.fnv(raw.id) % UInt32(pool.count))])
        let address = [t["addr:housenumber"], t["addr:street"]].compactMap { $0 }.joined(separator: " ")
        // About a third of the world's places have no explorer yet, so there is always a first to claim.
        let unexplored = match == nil && StableHash.fnv(raw.id) % 100 < 35
        let place = Place(id: "osm-" + raw.id, name: raw.name, category: nil, coords: coords, photo: photo,
                          address: address, rating: nil, reviews: nil, status: unexplored ? "unexplored" : nil, blurb: nil,
                          hours: hoursText(t["opening_hours"]), area: nil, cats: raw.cats, tags: t,
                          photoKind: match == nil ? "category" : "place", curated: match?.id,
                          website: t["website"] ?? "", source: "osm")
        if register { store.osmPlaces[place.id] = place }
        return place
    }

    /// OpenStreetMap hours ("Mo-Fr 08:30-15:00; Sa,Su 10:00-12:00") in plain words.
    static func hoursText(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        if raw == "24/7" { return "Open 24 hours" }
        let days = ["Mo": "Mon", "Tu": "Tue", "We": "Wed", "Th": "Thu", "Fr": "Fri", "Sa": "Sat", "Su": "Sun"]
        return raw.split(separator: ";").prefix(2).map { part -> String in
            var text = part.trimmingCharacters(in: .whitespaces)
            if text.hasPrefix("Mo-Su") { text = "Daily" + text.dropFirst(5) }
            for (short, long) in days {
                text = text.replacingOccurrences(of: "\\b\(short)\\b", with: long, options: .regularExpression)
            }
            text = text.replacingOccurrences(of: "([A-Za-z])-([A-Za-z])", with: "$1 to $2", options: .regularExpression)
            text = text.replacingOccurrences(of: "(\\d\\d:\\d\\d)-(\\d\\d:\\d\\d)", with: "$1 to $2", options: .regularExpression)
            text = text.replacingOccurrences(of: ",(?=[A-Za-z])", with: ", ", options: .regularExpression)
            return text
        }.joined(separator: ", ")
    }

    private static func query(_ center: Coord, store: AppStore) -> String {
        var byKey: [String: [String]] = [:]
        for pair in store.seed.discoverCategories.flatMap(\.osm) where pair.count == 2 {
            if !(byKey[pair[0]] ?? []).contains(pair[1]) { byKey[pair[0], default: []].append(pair[1]) }
        }
        let around = "(around:\(radius),\(center.lat),\(center.lng))"
        let parts = byKey.keys.sorted().map { key in
            "nwr[\"\(key)\"~\"^(\(byKey[key]!.joined(separator: "|")))$\"][\"name\"]\(around);"
        }
        return "[out:json][timeout:25];(" + parts.joined() + ");out center tags 400;"
    }

    private struct OverpassResponse: Decodable {
        struct Element: Decodable {
            struct Center: Decodable { var lat: Double; var lon: Double }
            var type: String
            var id: Int
            var lat: Double?
            var lon: Double?
            var center: Center?
            var tags: [String: String]?
        }
        var elements: [Element]
    }

    static func fetchLive(center: Coord, store: AppStore) async -> [OSMRaw]? {
        let key = String(format: "%.3f,%.3f", center.lat, center.lng)
        if let cached = cache[key] { return cached }
        let body = "data=" + (query(center, store: store).addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")
        for mirror in mirrors {
            guard let url = URL(string: mirror) else { continue }
            var request = URLRequest(url: url, timeoutInterval: 25)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.setValue("Odyssey iOS", forHTTPHeaderField: "User-Agent")
            request.httpBody = body.data(using: .utf8)
            guard let reply = try? await URLSession.shared.data(for: request),
                  (reply.1 as? HTTPURLResponse)?.statusCode == 200,
                  let decoded = try? JSONDecoder().decode(OverpassResponse.self, from: reply.0) else { continue }
            let places: [OSMRaw] = decoded.elements.compactMap { e in
                let tags = e.tags ?? [:]
                guard let name = tags["name"], let lat = e.lat ?? e.center?.lat, let lng = e.lon ?? e.center?.lon else { return nil }
                let cats = store.seed.categories(for: tags)
                guard !cats.isEmpty else { return nil }
                return OSMRaw(id: String(e.type.prefix(1)) + String(e.id), name: name, lat: lat, lng: lng, cats: cats, tags: tags)
            }
            cache[key] = places
            return places
        }
        return nil
    }

    /// Open walking directions in Apple Maps.
    static func directions(to place: Place) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coords.location))
        item.name = place.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}
