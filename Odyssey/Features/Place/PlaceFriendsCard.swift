//
//  PlaceFriendsCard.swift
//  Odyssey
//
//  Which of your friends explored a place before you, and whether you have
//  walked past it yourself. Walking by fills in the map; checking in with a
//  photo is what makes the place yours, and this card says which step is
//  left.
//

import Foundation
import SwiftUI

struct PlaceFriendsCard: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var place: Place

    var body: some View {
        let friends = explorers
        let mine = store.status(of: place).status == .mine
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Friends who explored here").font(.system(size: 13, weight: .bold))
                Spacer()
                Text(walkedLabel(mine: mine))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(mine ? Palette.success : Palette.accentInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((mine ? Palette.success : Palette.accent).opacity(0.12), in: Capsule())
            }
            if friends.isEmpty {
                Text("None of your friends have been yet. Check in and you will be the one they see.")
                    .font(.system(size: 13)).foregroundStyle(Palette.ink2)
            } else {
                ForEach(friends.prefix(4)) { friend in
                    Button { router.push(.person(friend.id)) } label: {
                        HStack(spacing: 10) {
                            AvatarView(person: friend, size: 32, frame: "none")
                            Circle().fill(store.friendColor(friend.id)).frame(width: 9, height: 9)
                            Text(friend.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
                            Spacer()
                            if store.firstExplorer(place)?.by == friend.id {
                                Text("First here").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.rare)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                if friends.count > 4 {
                    Text("and \(friends.count - 4) more").font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
    }

    /// Friends with this place on their map, then anyone else the place lists.
    private var explorers: [Person] {
        var people = store.friends.filter { friend in store.exploredPlaces(of: friend.id).contains { $0.id == place.id } }
        for friend in store.friendsWhoVisited(place) where !people.contains(where: { $0.id == friend.id }) {
            people.append(friend)
        }
        return people
    }

    private func walkedLabel(mine: Bool) -> String {
        if mine { return "Claimed" }
        return store.walkedPast(place) ? "Walked past" : "Not walked yet"
    }
}
