//
//  AppStore+Amenities.swift
//  Odyssey
//
//  Amenity tags for any place. The SF demo places carry tags seeded in
//  Convex; places found live on the phone (Apple Maps, OpenStreetMap) get
//  the same rules applied from their category, so filters work everywhere.
//

import Foundation

extension AppStore {
    func amenities(of place: Place) -> [String] {
        if let tags = placeFeatures[place.id], !tags.isEmpty { return tags }
        let cats = ([place.category ?? ""] + (place.cats ?? []) + [placeKind(place).label]).joined(separator: " ").lowercased()
        let r = StableHash.generator(place.id + "amenity")
        var out: [String] = []
        func add(_ f: String, _ p: Double = 1) { if r() < p { out.append(f) } }
        if cats.range(of: "cafe|coffee|bakery|library|study|cowork|office|tea", options: .regularExpression) != nil {
            add("wifi"); add("seating"); add("outlets", 0.8); add("bathroom", 0.85)
            add("quiet", cats.contains("library") || cats.contains("study") ? 1 : 0.35)
        } else if cats.range(of: "restaurant|food|pizza|fast|deli|dessert|ice|sweet|bar|pub|brew", options: .regularExpression) != nil {
            add("seating"); add("bathroom", 0.9); add("wifi", 0.45); add("outlets", 0.2)
        } else if cats.range(of: "park|outdoor|garden|beach|view|playground", options: .regularExpression) != nil {
            add("seating", 0.8); add("bathroom", 0.4); add("wifi", 0.15)
        } else if cats.range(of: "museum|gallery|art|theat|cinema|landmark|entertainment|campus", options: .regularExpression) != nil {
            add("bathroom"); add("elevator", 0.7); add("seating", 0.6); add("wifi", 0.5)
        } else if cats.range(of: "fitness|gym|sport|climb", options: .regularExpression) != nil {
            add("wifi", 0.7); add("bathroom"); add("seating", 0.3)
        } else {
            add("seating", 0.5); add("bathroom", 0.4); add("wifi", 0.4)
        }
        add("accessible", 0.65)
        return out
    }
}
