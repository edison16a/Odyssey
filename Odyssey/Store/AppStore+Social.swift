//
//  AppStore+Social.swift
//  Odyssey
//
//  Friends, posts, likes, stories and quest invites. The signed in user is
//  shaped like any other person so avatars, profiles and posts can treat
//  you and your friends the same way. Ported from services/social.js and
//  services/quests.js.
//

import Foundation

extension AppStore {
    /// You, shaped like an entry in the people list.
    var me: Person {
        let s = state
        return Person(id: "me", name: s.user.name, handle: s.user.handle, avatar: s.user.avatar, frame: s.equipped.frame,
                      rank: seed.rankIndex(for: s.wallet.xp), xp: s.wallet.xp, explored: s.stats.explored,
                      contributions: s.stats.contributions, friend: false, city: s.user.city, bio: s.user.bio,
                      effect: s.equipped.effect, icon: s.equipped.explorer, banner: s.equipped.banner)
    }

    func person(_ id: String) -> Person? { id == "me" ? me : seed.person(id) }

    func isFriend(_ id: String) -> Bool { state.friends.contains(id) }

    var friends: [Person] { state.friends.compactMap { seed.person($0) } }

    func addFriend(_ id: String) {
        update { s in
            if !s.friends.contains(id) { s.friends.append(id) }
            s.requests.removeAll { $0 == id }
            s.stats.friends += 1
        }
        Cloud.shared.recordFriend(id, status: "friends")
        completeFirstStep(.friend)
    }

    func declineRequest(_ id: String) {
        update { s in s.requests.removeAll { $0 == id } }
    }

    /// Friend posts plus your own, newest first.
    var feed: [Post] { memo("feed") { buildFeed() } }

    private func buildFeed() -> [Post] {
        let mine = state.myPosts.map { post -> Post in
            var p = post
            p.by = "me"
            if let created = p.createdAt { p.minutesAgo = max(0, Int(Date().timeIntervalSince(created) / 60)) }
            return p
        }
        let theirs = seed.posts.filter { isFriend($0.by) }
        return (mine + theirs).sorted { $0.minutesAgo < $1.minutesAgo }
    }

    func post(_ id: String) -> Post? {
        feed.first { $0.id == id } ?? seed.posts.first { $0.id == id }
    }

    func posts(by id: String) -> [Post] {
        id == "me" ? feed.filter { $0.by == "me" } : seed.posts.filter { $0.by == id }
    }

    @discardableResult
    func addPost(placeId: String, kind: String, caption: String, first: Bool, photoFile: String?, selfieFile: String?, seconds: Int? = nil) -> Post {
        let post = Post(id: "mine-\(Int(Date().timeIntervalSince1970 * 1000))", by: "me", placeId: placeId, kind: kind,
                        minutesAgo: 0, selfie: nil, caption: caption, seconds: seconds, first: first, likes: 0, comments: 0,
                        milestone: nil, day: nil, photoFile: photoFile, selfieFile: selfieFile, createdAt: Date())
        update { s in s.myPosts.insert(post, at: 0) }
        return post
    }

    @discardableResult
    func toggleLike(_ postId: String) -> Bool {
        update { s in s.likes[postId] = !(s.likes[postId] ?? false) }
        let on = state.likes[postId] ?? false
        Cloud.shared.recordLike(postId, on: on)
        return on
    }

    func liked(_ postId: String) -> Bool { state.likes[postId] ?? false }

    /// Friends with a story, in the order the row shows them.
    var storyPeople: [String] {
        seed.storyOrder.filter { isFriend($0) && !posts(by: $0).isEmpty }
    }

    func markSeen(_ id: String) {
        update { s in s.storiesSeen[id] = true }
    }

    func seen(_ id: String) -> Bool { state.storiesSeen[id] ?? false }

    var unreadNotifications: Int {
        seed.notifications.filter { !state.readNotifications.contains($0.id) }.count
    }

    // MARK: Quests

    func questInvites(_ questId: String) -> [String: String] { state.questInvites[questId] ?? [:] }

    func questPartners(_ questId: String) -> [String] {
        questInvites(questId).filter { $0.value == "joined" }.map(\.key).sorted()
    }

    /// Invite friends; each one joins after a short, staggered delay, like a real invite coming back.
    func invite(_ questId: String, friends ids: [String], onJoin: ((String) -> Void)? = nil) {
        update { s in
            for id in ids where s.questInvites[questId]?[id] == nil {
                s.questInvites[questId, default: [:]][id] = "invited"
            }
        }
        for (i, id) in ids.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2 + Double(i) * 0.9) { [weak self] in
                self?.update { s in s.questInvites[questId, default: [:]][id] = "joined" }
                onJoin?(id)
            }
        }
    }

    /// A quest is ready when it needs no friend, or a friend has joined.
    func questReady(_ quest: Quest) -> Bool {
        !quest.needsFriend || !questPartners(quest.id).isEmpty
    }

    func questRarity(_ quest: Quest) -> QuestRarity {
        seed.questRarity[quest.rarity] ?? QuestRarity(label: quest.rarity.capitalized, color: "#17a35a", odds: "")
    }

    /// Open quests near you, rarest first.
    var openQuests: [Quest] {
        let order = ["mythical": 0, "epic": 1, "rare": 2, "common": 3]
        let nearby = Set(nearbyPlaces.map(\.id))
        return seed.quests
            .filter { state.questsDone[$0.id] == nil && nearby.contains($0.placeId) }
            .sorted { (order[$0.rarity] ?? 9) < (order[$1.rarity] ?? 9) }
    }
}
