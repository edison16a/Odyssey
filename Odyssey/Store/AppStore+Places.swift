//
//  AppStore+Places.swift
//  Odyssey
//
//  Looking places up and measuring how far away they are. Curated places
//  live in two prepared areas (Dogpatch in San Francisco and UC Berkeley).
//  When the phone is near one of them, that area becomes home. Distances and
//  the home map always use where you really are once location is on; without
//  it, the demo spot of the chosen area stands in for you.
//

import Foundation

extension AppStore {
    /// A curated place, an OpenStreetMap place seen this session, or one saved by a check-in.
    func place(_ id: String) -> Place? {
        seed.places.first { $0.id == id } ?? osmPlaces[id] ?? state.savedPlaces[id] ?? state.starred[id]
            ?? (liveBounties + state.myBounties).compactMap(\.target.place).first { $0.id == id }
    }

    /// Label and icon for any place.
    func placeKind(_ place: Place) -> (label: String, icon: String) {
        if let category = place.category, let kind = seed.categories[category] {
            return (kind.label, kind.icon)
        }
        if let first = place.cats?.first, let cat = seed.discoverCategory(first) {
            return (cat.one, cat.icon)
        }
        return ("Place", "pin")
    }

    /// The prepared area the phone is in, or the one picked in settings.
    var home: Area {
        if state.useDeviceLocation, let device = deviceLocation {
            let near = seed.areas.values.min { $0.center.distance(to: device) < $1.center.distance(to: device) }
            if let near, near.center.distance(to: device) < 50_000 { return near }
        }
        return seed.areas[state.demoArea] ?? seed.areas["sf"]!
    }

    /// Where you are: the phone's real position whenever location is on, otherwise
    /// the demo spot of the chosen area. Distances and the home map follow it.
    var here: Coord {
        if state.useDeviceLocation, let device = deviceLocation { return device }
        return home.me
    }

    /// True when "here" is the phone's real position rather than the demo spot.
    var usingRealLocation: Bool {
        state.useDeviceLocation && deviceLocation != nil
    }

    /// Curated places in the current area, the ones "near you" lists use.
    var nearbyPlaces: [Place] {
        seed.places.filter { $0.areaID == home.id }
    }

    /// Distance to a place: from you, or for world places from the Explore location when that is closer
    /// (so a picked area like Shibuya still reads in walking minutes).
    func metres(to place: Place) -> Double {
        let fromYou = here.distance(to: place.coords)
        return place.isOSM ? min(fromYou, exploreCenter.distance(to: place.coords)) : fromYou
    }

    /// Where the Explore tab is looking right now.
    var exploreCenter: Coord { exploreLocation.center }

    /// The Explore tab's location: the phone's, or a picked area.
    var exploreLocation: (id: String, label: String, center: Coord, gps: Bool) {
        if let saved = state.discoverLocation, saved.gps == true, let center = saved.center {
            return (saved.id, saved.label ?? "Near you", center, true)
        }
        let fallback = home.id == "berkeley" ? "berkeley" : "sf-dogpatch"
        let id = state.discoverLocation?.id ?? fallback
        let area = seed.discoverPlaces[id] ?? seed.discoverPlaces[fallback]!
        return (id, area.label, area.center, false)
    }

    /// The asset catalog name of a place's photo.
    func photoName(_ place: Place) -> String { Media.name(for: place.photo) }
}
