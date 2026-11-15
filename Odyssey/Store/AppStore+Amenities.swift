import Foundation

extension AppStore {
    /// Only explicit OSM tags describe a real venue. Category-based guesses aren't evidence.
    func amenities(of place: Place) -> [String] {
        if state.demoMode, let demo = placeFeatures[place.id] { return demo }
        let tags = place.tags ?? [:]
        var out: [String] = []
        if ["yes", "wlan"].contains(tags["internet_access"] ?? "") || tags["wifi"] == "yes" { out.append("wifi") }
        if tags["outdoor_seating"] == "yes" || tags["indoor_seating"] == "yes" || tags["seating"] == "yes" { out.append("seating") }
        if tags["toilets"] == "yes" || tags["amenity"] == "toilets" { out.append("bathroom") }
        if tags["socket"] == "yes" { out.append("outlets") }
        if tags["wheelchair"] == "yes" { out.append("accessible") }
        if tags["highway"] == "elevator" || tags["elevator"] == "yes" { out.append("elevator") }
        return out
    }
}
