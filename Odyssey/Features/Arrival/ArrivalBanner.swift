//
//  ArrivalBanner.swift
//  Odyssey
//
//  The card that slides down when you reach a place: its photo and name,
//  the friends who explored it before you (or a nudge to be first), and a
//  Check in button that opens the photo check-in.
//

import Foundation
import SwiftUI

struct ArrivalBanner: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var place: Place
    var close: () -> Void

    var body: some View {
        let friends = store.friendsWhoVisited(place)
        let isNew = store.status(of: place).status == .new
        HStack(spacing: 12) {
            PlacePhoto(place: place)
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(isNew ? "Nobody has claimed this yet" : "You made it")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isNew ? Palette.rare : Palette.accentInk)
                Text(place.name)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                friendsLine(friends, isNew: isNew)
            }
            Spacer(minLength: 4)
            Button("Check in") {
                close()
                router.present(.checkIn(placeID: place.id))
            }
            .buttonStyle(.pill(.primary, height: 38))
        }
        .padding(12)
        .padding(.trailing, 4)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
        .overlay(alignment: .topTrailing) {
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 22, height: 22)
                    .background(Palette.surface2, in: Circle())
            }
            .offset(x: 6, y: -6)
            .accessibilityLabel("Not now")
        }
        .onTapGesture {
            close()
            router.push(.place(place.id))
        }
    }

    @ViewBuilder
    private func friendsLine(_ friends: [Person], isNew: Bool) -> some View {
        if let first = friends.first {
            HStack(spacing: 6) {
                AvatarStack(people: Array(friends.prefix(3)), size: 20)
                Text(friends.count == 1 ? "\(first.firstName) explored here"
                                        : "\(first.firstName) and \(friends.count - 1) more friends explored here")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
        } else {
            Text(isNew ? "Take a photo to be its first explorer" : "None of your friends have been yet")
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
        }
    }
}
