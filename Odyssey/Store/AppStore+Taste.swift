//
//  AppStore+Taste.swift
//  Odyssey
//
//  What you love, learned over time. Every place is described by a few
//  features (categories, cuisine, independent or chain, wifi, outdoor
//  seating, open late, quiet or lively...). A thumbs up nudges each feature
//  up, a thumbs down nudges it down, and a check-in counts as a small thumbs
//  up. Recommendations add those weights up, plus closeness and the
//  interests from onboarding. Ported from services/taste.js, with the same
//  numbers, so it ranks places the same way the mockup does.
//

import Foundation

extension AppStore {
    private static let step = 0.6
    private static let cap = 4.0

    private static let curated: [String: [String]] = [
        "cafe": ["coffee", "study"], "food": ["food"], "library": ["library", "study"], "books": ["shopping"],
        "outdoors": ["park"], "museum": ["entertainment"], "landmark": ["entertainment"], "market": ["food", "shopping"],
        "gym": ["fitness"], "campus": ["study", "startup"], "office": ["startup", "study"], "transit": [],
    ]
    private static let interestCats: [String: [String]] = [
        "food": ["food", "coffee", "dessert"], "books": ["library", "study"], "outdoors": ["park"],
        "culture": ["entertainment"], "nightlife": ["nightlife"], "travel": ["entertainment", "park"],
        "startups": ["startup", "study"], "coffee": ["coffee"],
    ]
    static let phrase: [String: String] = [
        "indie": "independent", "chain": "big chains", "wifi": "wifi", "outdoor": "outdoor seating", "quiet": "quiet",
        "lively": "lively", "vegan": "vegan options", "late": "open late", "accessible": "step free access", "hidden": "hidden gems",
    ]
    private static let interestName: [String: String] = [
        "food": "good food", "books": "books", "outdoors": "the outdoors", "culture": "art and culture",
        "nightlife": "nights out", "travel": "new places",
        "startups": "startups", "coffee": "cafes",
    ]
    private static let own = ["hidden", "indie", "outdoor", "wifi", "vegan", "late", "quiet", "accessible"]

    func tasteCategories(_ place: Place) -> [String] {
        place.cats ?? AppStore.curated[place.category ?? ""] ?? []
    }

    /// Feature keys for a place, curated or from OpenStreetMap.
    func features(_ place: Place) -> [String] {
        let vibe = state.placeInsights[place.id]?.vibe ?? ""
        if let hit = featureCache[place.id], hit.vibe == vibe { return hit.features }
        let feats = computeFeatures(place)
        featureCache[place.id] = (vibe, feats)
        return feats
    }

    private func computeFeatures(_ place: Place) -> [String] {
        let t = place.tags ?? [:]
        let cats = tasteCategories(place)
        var out = cats.map { "cat:" + $0 }
        for cuisine in (t["cuisine"] ?? "").split(separator: ";") {
            out.append("cuisine:" + cuisine.trimmingCharacters(in: .whitespaces).lowercased())
        }
        out.append(t["brand"] != nil ? "chain" : "indie")
        if ["wlan", "yes", "wifi"].contains(t["internet_access"] ?? "") { out.append("wifi") }
        if t["outdoor_seating"] == "yes" { out.append("outdoor") }
        if t["diet:vegan"] == "yes" || t["diet:vegan"] == "only" { out.append("vegan") }
        if t["wheelchair"] == "yes" { out.append("accessible") }
        let hours = t["opening_hours"] ?? ""
        if hours.range(of: #"24/7|2[2-4]:|0[0-3]:\d\d$"#, options: .regularExpression) != nil { out.append("late") }
        let insight = state.placeInsights[place.id]
        if insight?.vibe == "quiet" { out.append("quiet") }
        else if insight?.vibe == "lively" { out.append("lively") }
        else if cats.contains("library") || (cats.contains("coffee") && out.contains("wifi") && t["brand"] == nil) { out.append("quiet") }
        else if cats.contains("nightlife") { out.append("lively") }
        if t["brand"] == nil && StableHash.fnv(place.id) % 100 < 38 { out.append("hidden") }
        var seen = Set<String>()
        return out.filter { seen.insert($0).inserted }
    }

    func voteOf(_ place: Place) -> Int { state.taste.votes[place.id]?.v ?? 0 }

    /// Thumbs up (1), thumbs down (-1), or the same thumb again to undo (0).
    @discardableResult
    func vote(_ place: Place, _ v: Int) -> Int {
        let previous = voteOf(place)
        let next = previous == v ? 0 : v
        let delta = Double(next - previous)
        let feats = features(place)
        update { s in
            for f in feats {
                s.taste.weights[f] = max(-AppStore.cap, min(AppStore.cap, (s.taste.weights[f] ?? 0) + AppStore.step * delta))
            }
            if next != 0 {
                s.taste.votes[place.id] = AppState.Vote(v: next, name: place.name, features: feats, at: Date().timeIntervalSince1970 * 1000)
            } else {
                s.taste.votes.removeValue(forKey: place.id)
            }
        }
        cloudPicks[place.id] = nil
        Cloud.shared.recordVote(place, value: next)
        return next
    }

    /// Checking in somewhere is a quiet vote of confidence.
    func tasteExplored(_ place: Place) {
        let feats = features(place)
        update { s in
            for f in feats { s.taste.weights[f] = min(AppStore.cap, (s.taste.weights[f] ?? 0) + AppStore.step * 0.3) }
        }
    }

    /// The onboarding interest this place fits, if any.
    func interest(for place: Place) -> String? {
        let cats = tasteCategories(place)
        let order = ["startups", "coffee", "culture", "food", "books", "outdoors", "travel", "nightlife"]
        return order.first { key in
            (state.interests[key] ?? false) && (AppStore.interestCats[key] ?? []).contains { cats.contains($0) }
        }
    }

    /// Higher is better. metres is the walking distance from where you are.
    func score(_ place: Place, metres: Double) -> Double {
        let w = state.taste.weights
        let learned = features(place).reduce(0) { $0 + (w[$1] ?? 0) }
        let near = 1.4 * exp(-metres / 700)
        let prior = interest(for: place) != nil ? 0.6 : 0
        return learned + prior + near + (voteOf(place) > 0 ? 2.5 : 0) + Double(StableHash.fnv(place.id) % 97) / 1000
    }

    /// Sort places for you. Places you gave a thumbs down drop out.
    func rankForYou(_ places: [Place]) -> [Place] {
        var hasher = Hasher()
        for place in places { hasher.combine(place.id) }
        return memo("rank-\(hasher.finalize())") { rankUncached(places) }
    }

    private func rankUncached(_ places: [Place]) -> [Place] {
        // The server's Supermemory-backed score when it has one, the phone's otherwise.
        places.filter { voteOf($0) >= 0 }
            .map { ($0, cloudPicks[$0.id]?.score ?? score($0, metres: metres(to: $0))) }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    private func similarLiked(_ place: Place) -> String? {
        let mine = Set(features(place).filter { !$0.hasPrefix("cat:") })
        var best: (name: String, shared: Int)?
        for (id, vote) in state.taste.votes where vote.v > 0 && id != place.id {
            let shared = vote.features.filter { mine.contains($0) }.count
            if shared >= 2 && (best == nil || shared > best!.shared) { best = (vote.name, shared) }
        }
        return best?.name
    }

    /// A short, honest reason this place was recommended.
    func why(_ place: Place, metres: Double? = nil) -> String {
        if let pick = cloudPicks[place.id], !pick.reason.isEmpty { return pick.reason }
        let distance = metres ?? self.metres(to: place)
        // Walk minutes are all that distance changes in the sentence.
        return memo("why-\(place.id)-\(Int((distance / 80).rounded()))") { whyUncached(place, distance: distance) }
    }

    private func whyUncached(_ place: Place, distance: Double) -> String {
        let w = state.taste.weights
        if let like = similarLiked(place) { return "Like \(like), which you liked" }
        let feats = features(place)
        let catName = tasteCategories(place).first.flatMap { seed.discoverCategory($0)?.label.lowercased() } ?? "spots"
        let top = feats.filter { AppStore.phrase[$0] != nil && (w[$0] ?? 0) >= 0.5 }.sorted { (w[$0] ?? 0) > (w[$1] ?? 0) }.prefix(2)
        if !top.isEmpty {
            return "Because you like " + top.compactMap { AppStore.phrase[$0] }.joined(separator: " and ") + " " + catName
        }
        let walk = "\(max(1, Int((distance / 80).rounded()))) min walk"
        let business = tasteCategories(place).contains { ["coffee", "food", "shopping", "nightlife", "dessert", "fitness"].contains($0) }
        let ownFeature = feats.first { AppStore.own.contains($0) && $0 != "indie" && (business || $0 != "hidden") }
            ?? (business && feats.contains("indie") ? "indie" : nil)
        let detail: String
        switch ownFeature {
        case "hidden"?: detail = "A hidden gem"
        case "indie"?: detail = "Independent"
        case .some(let f): detail = "Has " + (AppStore.phrase[f] ?? f)
        case .none: detail = ""
        }
        if let interest = interest(for: place) {
            return "You love " + (AppStore.interestName[interest] ?? interest) + (detail.isEmpty ? "" : ". " + detail) + ", " + walk
        }
        return (detail.isEmpty ? "Close by" : detail) + ", " + walk
    }

    /// The strongest learned likes and dislikes.
    func tasteSummary() -> (likes: [String], dislikes: [String], votes: Int) {
        let w = state.taste.weights
        let keys = w.keys.filter { AppStore.phrase[$0] != nil || $0.hasPrefix("cuisine:") || $0.hasPrefix("cat:") }
        func label(_ f: String) -> String {
            if let p = AppStore.phrase[f] { return p }
            if f.hasPrefix("cat:") { return seed.discoverCategory(String(f.dropFirst(4)))?.label ?? String(f.dropFirst(4)) }
            return String(f.dropFirst(8)).replacingOccurrences(of: "_", with: " ")
        }
        let likes = keys.filter { (w[$0] ?? 0) >= 0.5 }.sorted { (w[$0] ?? 0) > (w[$1] ?? 0) }.prefix(4).map(label)
        let dislikes = keys.filter { (w[$0] ?? 0) <= -0.5 }.sorted { (w[$0] ?? 0) < (w[$1] ?? 0) }.prefix(2).map(label)
        return (Array(likes), Array(dislikes), state.taste.votes.count)
    }

    func resetTaste() {
        update { s in s.taste = AppState.Taste() }
        Cloud.shared.resetTaste()
    }
}
