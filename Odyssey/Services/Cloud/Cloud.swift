//
//  Cloud.swift
//  Odyssey
//
//  Keeps the phone and Convex in step. The phone stays the fast, offline
//  source of truth for the screens; Convex gets everything that matters:
//
//  - your profile, wallet, streak and stats (for friends and leaderboards)
//  - every check-in with its photo and selfie, uploaded to Convex storage
//  - walkthrough videos you chose to share, and what they taught Odyssey
//  - every swipe and star, which also teach Supermemory your taste
//  - the whole app state, so signing in on a new phone brings it all back
//
//  Explore asks Convex to rank nearby places with the Supermemory-backed
//  recommender; until an answer comes back (or with no network) the phone's
//  own ranking is used.
//

import Foundation
import Observation
import UIKit

/// One recommendation from the server.
struct CloudPick: Equatable {
    var score: Double
    var reason: String
}

@Observable
final class Cloud {
    static let shared = Cloud()

    private(set) var signedIn = ConvexAPI.shared.isSignedIn
    private(set) var syncing = false
    private(set) var lastSynced: Date?
    private(set) var lastError: String?
    /// Supermemory profile facts from the last recommendation, for the taste page.
    private(set) var profileFacts: [String] = []
    private(set) var usedSupermemory = false

    @ObservationIgnored private weak var store: AppStore?
    @ObservationIgnored private let api = ConvexAPI.shared
    @ObservationIgnored private var stateWork: Task<Void, Never>?
    @ObservationIgnored private var lastProfileKey = ""
    @ObservationIgnored private var lastStatsKey = ""
    @ObservationIgnored private var rankedPools: Set<Int> = []

    private init() {
        api.onSignedOut = { [weak self] in
            Task { @MainActor in self?.signedIn = false }
        }
    }

    /// Called once at launch.
    func attach(_ store: AppStore) {
        self.store = store
        guard signedIn else { return }
        Task { await afterSignIn(restore: false) }
    }

    // MARK: Sign in

    func sendCode(email: String) async throws {
        try await api.sendCode(email: email)
    }

    /// Verify the code, then make sure a profile exists and pull down saved state.
    func verify(email: String, code: String) async throws {
        try await api.verify(email: email, code: code)
        signedIn = true
        await afterSignIn(restore: true)
    }

    // MARK: Text-in (phone) sign in

    struct TextInLogin: Equatable {
        var code: String
        var nonce: String
        /// Odyssey's iMessage line, or nil while phone sign-in is not set up.
        var line: String?
    }

    func startTextIn() async throws -> TextInLogin {
        guard let d = try await api.mutation("phoneAuth:start") as? [String: Any],
              let code = d["code"] as? String, let nonce = d["nonce"] as? String else { throw ConvexError.badResponse }
        return TextInLogin(code: code, nonce: nonce, line: d["line"] as? String)
    }

    /// "pending", "confirmed", "used" or "expired" ("pending" if the network hiccups).
    func textInStatus(nonce: String) async -> String {
        let d = try? await api.query("phoneAuth:status", ["nonce": nonce]) as? [String: Any]
        return d?["state"] as? String ?? "pending"
    }

    func verifyTextIn(nonce: String) async throws {
        try await api.verifyTextIn(nonce: nonce)
        signedIn = true
        await afterSignIn(restore: true)
    }

    func signOut() async {
        stateWork?.cancel()
        await pushState()
        await api.signOut()
        signedIn = false
        profileFacts = []
        store?.clearCloudPicks()
    }

    private func afterSignIn(restore: Bool) async {
        guard let store else { return }
        syncing = true
        defer { syncing = false }
        do {
            let s = store.state
            try await api.mutation("users:bootstrap", obj([
                "name": s.user.name,
                "handle": s.user.handle,
                "city": s.user.city,
                "interests": s.interests.filter(\.value).map(\.key).sorted(),
                "onboarded": s.session.onboarded,
                "coins": Double(s.wallet.coins),
                "xp": Double(s.wallet.xp),
                "points": Double(s.wallet.points),
                "cash": s.wallet.cash,
            ]))
            if restore, let saved = try await api.query("users:getState") as? [String: Any],
               let json = saved["state"] as? String, let data = json.data(using: .utf8),
               let remote = try? JSONDecoder().decode(AppState.self, from: data) {
                store.restoreFromCloud(remote)
            }
            await pushState()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: State

    /// The store changed: send a snapshot once things settle.
    func stateChanged() {
        guard signedIn else { return }
        stateWork?.cancel()
        stateWork = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await self?.pushState()
        }
    }

    func pushState() async {
        guard signedIn, let store else { return }
        let s = store.state
        do {
            let data = try JSONEncoder().encode(s)
            let json = String(decoding: data, as: UTF8.self)
            try await api.mutation("users:saveState", ["version": Double(s.version), "state": json])

            let statsKey = "\(s.wallet.coins)|\(s.wallet.xp)|\(s.wallet.points)|\(s.wallet.cash)|\(s.streak.days)|\(s.stats.explored)|\(s.stats.contributions)|\(s.firsts.count)"
            if statsKey != lastStatsKey {
                try await api.mutation("users:syncStats", obj([
                    "coins": Double(s.wallet.coins), "xp": Double(s.wallet.xp), "points": Double(s.wallet.points),
                    "cash": s.wallet.cash, "streakDays": Double(s.streak.days), "streakBest": Double(s.streak.best),
                    "streakLastDay": s.streak.lastDay, "explored": Double(s.stats.explored),
                    "contributions": Double(s.stats.contributions), "firsts": Double(s.firsts.count), "km": s.stats.km,
                ]))
                lastStatsKey = statsKey
            }
            let interests = s.interests.filter(\.value).map(\.key).sorted()
            let avatar = s.user.avatar
            let profileKey = [s.user.name, s.user.handle, s.user.bio, s.user.city, interests.joined(separator: ","), "\(s.session.onboarded)",
                              avatar.kind, avatar.value ?? ""].joined(separator: "|")
            if profileKey != lastProfileKey {
                // An uploaded photo ("local") goes up through uploadAvatar; bundled photos and "none" are just names.
                let avatarFields: [String: Any?] = avatar.kind == "local" ? [:]
                    : ["avatarKind": avatar.kind == "photo" ? "photo" : "none", "avatarPath": avatar.kind == "photo" ? avatar.value : nil]
                try await api.mutation("users:updateProfile", obj([
                    "name": s.user.name, "bio": s.user.bio, "city": s.user.city,
                    "interests": interests, "onboarded": s.session.onboarded,
                ].merging(avatarFields) { a, _ in a }))
                lastProfileKey = profileKey
            }
            lastSynced = Date()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Adventures

    /// A check-in: upload the photos, then record it (Convex decides who was first).
    func recordCheckIn(_ place: Place, caption: String, photoFile: String?, selfieFile: String?, result: CheckInResult) {
        guard signedIn, let store else { return }
        let features = store.features(place)
        let city = store.state.user.city
        Task {
            do {
                let photo = try await uploadPhoto(photoFile, kind: "checkin-photo", placeId: place.id)
                let selfie = try await uploadPhoto(selfieFile, kind: "selfie", placeId: place.id)
                try await api.mutation("adventures:checkIn", obj([
                    "place": placeArgs(place),
                    "day": Format.today(),
                    "caption": caption,
                    "photoStorageId": photo,
                    "selfieStorageId": selfie,
                    "first": result.first,
                    "recommended": result.recommended,
                    "coins": Double(result.coins),
                    "xp": Double(result.xp),
                    "points": Double(result.points),
                    "questId": result.quest?.id,
                    "features": features,
                    "city": city,
                    "clientPostId": result.post.id,
                ]))
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    /// A walkthrough the explorer chose to share. The raw video stays private in storage.
    func recordWalkthrough(_ place: Place, seconds: Int, video: URL?, insights: AppState.Insights?, points: Int) {
        guard signedIn, let store else { return }
        let features = store.features(place)
        let city = store.state.user.city
        // Read now: the recorder deletes its file as soon as the analysis is done.
        let bytes = video.flatMap { try? Data(contentsOf: $0) }
        Task {
            do {
                var videoId: String?
                if let bytes, bytes.count < 200_000_000 {
                    let id = try await api.upload(bytes, contentType: "video/quicktime")
                    try await api.mutation("files:registerUpload", obj([
                        "storageId": id, "kind": "walkthrough", "fileName": "walk-\(UUID().uuidString.prefix(8)).mov", "placeId": place.id,
                    ]))
                    videoId = id
                }
                try await api.mutation("adventures:addWalkthrough", obj([
                    "place": placeArgs(place),
                    "seconds": Double(seconds),
                    "videoStorageId": videoId,
                    "insights": insights.map { i in obj(["vibe": i.vibe, "summary": i.summary, "tags": i.tags, "source": i.source]) },
                    "points": Double(points),
                    "features": features,
                    "city": city,
                ]))
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    /// Profile photo: upload and point the profile at it.
    func uploadAvatar(file: String) {
        guard signedIn else { return }
        Task {
            do {
                if let id = try await uploadPhoto(file, kind: "avatar", placeId: nil) {
                    try await api.mutation("users:updateProfile", ["avatarKind": "upload", "avatarStorageId": id])
                }
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    // MARK: Social and rewards

    /// A place's contribution history from Convex: explorers per day for 18 weeks and the latest walkthroughs.
    func placeHistory(_ placeID: String) async -> PlaceHistory? {
        guard let d = try? await api.query("history:forPlace", ["placeId": placeID]) as? [String: Any] else { return nil }
        let days = (d["days"] as? [Any] ?? []).map { ($0 as? NSNumber)?.intValue ?? 0 }
        let recent = (d["recent"] as? [[String: Any]] ?? []).map { r in
            PlaceHistory.Item(
                name: r["name"] as? String ?? "Explorer",
                personID: r["demoId"] as? String,
                seconds: (r["seconds"] as? NSNumber)?.intValue ?? 0,
                summary: r["summary"] as? String,
                vibe: r["vibe"] as? String,
                at: Date(timeIntervalSince1970: ((r["createdAt"] as? NSNumber)?.doubleValue ?? 0) / 1000)
            )
        }
        return PlaceHistory(days: days, total: (d["total"] as? NSNumber)?.intValue ?? 0,
                            explorers: (d["explorers"] as? NSNumber)?.intValue ?? 0, recent: recent)
    }

    /// Everyone who contributed to a place, most walkthroughs first.
    func placeContributors(_ placeID: String) async -> PlaceContributors? {
        guard let d = try? await api.query("history:contributors", ["placeId": placeID]) as? [String: Any] else { return nil }
        let people = (d["people"] as? [[String: Any]] ?? []).map { r in
            PlaceContributors.Person(
                name: r["name"] as? String ?? "Explorer",
                personID: r["demoId"] as? String,
                count: (r["count"] as? NSNumber)?.intValue ?? 0,
                seconds: (r["seconds"] as? NSNumber)?.intValue ?? 0,
                summary: r["summary"] as? String,
                lastAt: Date(timeIntervalSince1970: ((r["lastAt"] as? NSNumber)?.doubleValue ?? 0) / 1000)
            )
        }
        return PlaceContributors(total: (d["total"] as? NSNumber)?.intValue ?? 0, people: people)
    }

    func recordFriend(_ id: String, status: String) {
        guard signedIn else { return }
        send("social:setFriend", ["friendKey": id, "status": status])
    }

    func recordLike(_ postId: String, on: Bool) {
        guard signedIn else { return }
        send("social:setLike", ["postKey": postId, "on": on])
    }

    func recordBounty(_ bounty: Bounty) {
        guard signedIn, let data = try? JSONEncoder().encode(bounty),
              let json = try? JSONSerialization.jsonObject(with: data) else { return }
        send("social:postBounty", ["bounty": json])
    }

    func recordGiftCard(_ card: AppState.RedeemedCard) {
        guard signedIn else { return }
        send("social:redeemGiftCard", ["brand": card.brand, "amount": Double(card.amount), "code": card.code, "day": card.date])
    }

    // MARK: Taste

    func recordVote(_ place: Place, value: Int) {
        guard signedIn, let store else { return }
        let args = obj([
            "placeId": place.id, "placeName": place.name, "value": Double(value),
            "features": store.features(place), "city": store.state.user.city,
        ])
        send("taste:vote", args)
    }

    func recordStar(_ place: Place, on: Bool) {
        guard signedIn, let store else { return }
        send("taste:star", obj([
            "placeId": place.id, "placeName": place.name, "on": on,
            "features": store.features(place), "place": placeArgs(place),
        ]))
    }

    func resetTaste() {
        guard signedIn else { return }
        profileFacts = []
        store?.clearCloudPicks()
        send("taste:reset", [:])
    }

    /// Ask the server to rank a pool of places for you. Waits at most `timeout`
    /// seconds; the phone's ranking covers anything not answered in time.
    func rank(_ places: [Place], timeout: Double = 3) async {
        guard signedIn, let store, !places.isEmpty else { return }
        let ids = places.map(\.id).sorted()
        let key = ids.hashValue ^ store.state.taste.votes.count
        guard !rankedPools.contains(key) else { return }
        let candidates: [[String: Any]] = places.prefix(250).map { p in
            obj([
                "placeId": p.id, "name": p.name, "features": store.features(p),
                "metres": store.metres(to: p), "canBeFirst": store.status(of: p).status == .new,
            ])
        }
        let args = obj(["candidates": candidates, "city": store.exploreLocation.label, "limit": Double(min(places.count, 120))])
        let work = Task { () -> Any? in try? await api.action("recommend:forYou", args, timeout: 12) }
        let timer = Task { try? await Task.sleep(for: .seconds(timeout)); work.cancel() }
        let value = await work.value
        timer.cancel()
        guard let dict = value as? [String: Any], let picks = dict["picks"] as? [[String: Any]] else { return }
        var out: [String: CloudPick] = [:]
        for p in picks {
            guard let id = p["placeId"] as? String, let score = p["score"] as? Double else { continue }
            out[id] = CloudPick(score: score, reason: p["reason"] as? String ?? "")
        }
        rankedPools.insert(key)
        profileFacts = dict["profileFacts"] as? [String] ?? profileFacts
        usedSupermemory = dict["usedSupermemory"] as? Bool ?? false
        store.mergeCloudPicks(out)
    }

    // MARK: Helpers

    private func send(_ path: String, _ args: [String: Any]) {
        Task {
            do { try await api.mutation(path, args) } catch { lastError = error.localizedDescription }
        }
    }

    private func uploadPhoto(_ file: String?, kind: String, placeId: String?) async throws -> String? {
        guard let file, let image = PhotoStore.load(file), let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        let id = try await api.upload(data, contentType: "image/jpeg")
        try await api.mutation("files:registerUpload", obj(["storageId": id, "kind": kind, "fileName": file, "placeId": placeId]))
        return id
    }

    private func placeArgs(_ p: Place) -> [String: Any] {
        obj([
            "placeId": p.id, "name": p.name, "category": p.category, "cats": p.cats ?? store?.tasteCategories(p),
            "lat": p.coords.lat, "lng": p.coords.lng, "area": p.area, "address": p.address, "blurb": p.blurb,
            "hours": p.hours, "rating": p.rating, "reviews": p.reviews.map(Double.init), "website": p.website,
            "tags": p.tags, "source": p.source ?? (p.isOSM ? "osm" : "seed"),
            "photoPath": p.photo.isEmpty ? nil : p.photo,
        ])
    }
}

/// A JSON object without the nils (Convex wants optional fields left out, not null).
func obj(_ pairs: [String: Any?]) -> [String: Any] {
    var out: [String: Any] = [:]
    for (key, value) in pairs {
        guard let value else { continue }
        out[key] = value
    }
    return out
}

/// What `history:forPlace` returns.
struct PlaceHistory: Equatable {
    struct Item: Equatable, Identifiable {
        var id: String { name + "\(at.timeIntervalSince1970)" }
        var name: String
        var personID: String?
        var seconds: Int
        var summary: String?
        var vibe: String?
        var at: Date
    }
    var days: [Int]
    var total: Int
    var explorers: Int
    var recent: [Item]

    /// Explorers per day mapped to the five graph shades.
    var levels: [Int] { days.map { $0 == 0 ? 0 : min(4, $0) } }
}

/// What `history:contributors` returns.
struct PlaceContributors: Equatable {
    struct Person: Equatable, Identifiable {
        var id: String { (personID ?? name) + "\(lastAt.timeIntervalSince1970)" }
        var name: String
        var personID: String?
        var count: Int
        var seconds: Int
        var summary: String?
        var lastAt: Date
    }
    var total: Int
    var people: [Person]
}
