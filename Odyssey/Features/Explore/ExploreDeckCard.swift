//
//  ExploreDeckCard.swift
//  Odyssey
//
//  The pieces of the Explore deck: one photo card with the reason it was
//  picked, a star to keep it on your map, the recommendation bonus and its
//  swipe stamps; the list of places you liked; and the shimmer shown while
//  places load. Ported from discover-deck.js.
//

import Foundation
import SwiftUI

/// One photo card with the name, kind, walk and the reason it was picked.
struct ExploreDeckCard: View {
    @Environment(AppStore.self) private var store
    @Environment(ToastCenter.self) private var toast
    var place: Place
    var like: CGFloat
    var nope: CGFloat

    var body: some View {
        let metres = store.metres(to: place)
        ZStack(alignment: .bottomLeading) {
            PlacePhoto(place: place)
            LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                if !store.checkedInToday(place) { bonus }
                Text(place.name)
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.5)
                    .lineLimit(2)
                Text("\(store.placeKind(place).label), \(Format.walkTime(metres))")
                    .font(.system(size: 13))
                    .opacity(0.85)
                HStack(spacing: 5) {
                    OdysseyMark(size: 11)
                    Text(store.why(place, metres: metres)).lineLimit(2)
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.18), in: Capsule())
                .padding(.top, 6)
            }
            .foregroundStyle(.white)
            .padding(18)
        }
        .overlay(alignment: .top) { stamps }
        .overlay(alignment: .topTrailing) {
            if like == 0 && nope == 0 { starButton.padding(14) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Palette.ink))
        .shadow(color: Palette.ink.opacity(0.16), radius: 15, y: 12)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    /// Checking in at a recommended place pays extra; the card says so.
    private var bonus: some View {
        HStack(spacing: 5) {
            CoinIcon(size: 13)
            Text("Recommended: check in for +\(Rewards.recommended.coins) coins")
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Palette.gold, in: Capsule())
        .padding(.bottom, 4)
    }

    private var starButton: some View {
        let on = store.isStarred(place)
        return Button {
            let starred = store.toggleStar(place)
            Haptics.tap()
            toast.show(starred ? "Saved to your map" : "Removed from your map", icon: starred ? "star.fill" : "star")
        } label: {
            Image(systemName: on ? "star.fill" : "star")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(on ? Palette.gold : .white)
                .frame(width: 42, height: 42)
                .background(.black.opacity(0.35), in: Circle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(PressStyle(scale: 0.88))
        .accessibilityLabel(on ? "Unstar" : "Star")
    }

    private var stamps: some View {
        HStack {
            stamp("Good", icon: "hand.thumbsup.fill", color: Palette.accent).opacity(like)
            Spacer()
            stamp("Not for me", icon: "hand.thumbsdown.fill", color: Palette.ink).opacity(nope)
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
    }

    private func stamp(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold))
            Text(text).font(.system(size: 15, weight: .heavy))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(color, in: Capsule())
    }
}

/// The places you liked in Explore, each with a star and a Go button.
struct ExploreLikedSheet: View {
    @Environment(AppStore.self) private var store
    var liked: [Place]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your picks").titleStyle(22)
            if liked.isEmpty {
                Text("Swipe right on a place and it lands here, ready to go.").mutedStyle(15)
            }
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(liked.reversed()) { place in row(place) }
                }
            }
        }
        .padding(.horizontal, Space.s5)
        .padding(.top, 28)
    }

    private func row(_ place: Place) -> some View {
        HStack(spacing: 12) {
            PlacePhoto(place: place)
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink).lineLimit(1)
                Text(Format.walkTime(store.metres(to: place))).font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { store.toggleStar(place); Haptics.tap() } label: {
                Image(systemName: store.isStarred(place) ? "star.fill" : "star")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(store.isStarred(place) ? Palette.gold : Palette.muted)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(PressStyle())
            Button {
                LiveActivityService.shared.start(place: place, store: store)
                NearbyService.directions(to: place)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "location.north.fill").font(.system(size: 12, weight: .bold))
                    Text("Go").font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Palette.ink, in: Capsule())
            }
            .buttonStyle(PressStyle())
        }
        .padding(8)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }
}

/// The shimmering placeholder while places load.
struct ExploreLoadingCard: View {
    @State private var bright = false

    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(bright ? Palette.surface3 : Palette.surface2)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { bright = true }
            }
    }
}
