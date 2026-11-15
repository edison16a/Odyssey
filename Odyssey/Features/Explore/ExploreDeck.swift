//
//  ExploreDeck.swift
//  Odyssey
//
//  The Explore deck, which never runs out. Swipe a card right (or tap the
//  thumb) if it looks good, left (or the cross) if not; both teach the
//  taste model, and the feed keeps dealing the next best picks behind the
//  top card. Places you liked collect in a list you can open any time.
//  Ported from discover-deck.js.
//

import Foundation
import SwiftUI

struct ExploreDeckView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var feed: ExploreFeed
    @Binding var liked: [Place]

    @State private var drag: CGSize = .zero
    /// The card on its way off screen, drawn from its own offset so the next one can settle.
    @State private var flungID: String?
    @State private var flungOffset: CGSize = .zero
    @State private var flungTilt: Double = 0
    @State private var flungFade: Double = 1

    private var flying: Bool { flungID != nil }

    /// How far a card must travel before it counts as a choice.
    private let throwDistance: CGFloat = 110

    private var cards: [Place] { feed.cards }
    private var index: Int { feed.index }

    var body: some View {
        VStack(spacing: 0) {
            stack
            buttons
        }
    }

    /// Only the top three cards are drawn; the rest wait in the feed.
    private var stack: some View {
        ZStack {
            if index < cards.count {
                let visible = Array(cards[index..<min(cards.count, index + 3)].enumerated())
                ForEach(visible.reversed(), id: \.element.id) { depth, place in
                    card(place, depth: depth)
                }
            } else {
                ExploreLoadingCard()
            }
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder private func card(_ place: Place, depth: Int) -> some View {
        let top = depth == 0
        let flung = place.id == flungID
        ExploreDeckCard(place: place,
                        like: top && !flung ? min(1, max(0, drag.width / throwDistance)) : 0,
                        nope: top && !flung ? min(1, max(0, -drag.width / throwDistance)) : 0)
            .scaleEffect(1 - CGFloat(depth) * 0.04)
            .offset(y: CGFloat(depth) * 10)
            .offset(flung ? flungOffset : (top ? drag : .zero))
            .rotationEffect(.degrees(flung ? flungTilt : (top ? Double(drag.width / 14) : 0)))
            .opacity(flung ? flungFade : 1)
            .allowsHitTesting(top && !flung)
            .onTapGesture { router.push(.place(place.id)) }
            .gesture(top ? dragGesture : nil)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: index)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard !flying else { return }
                drag = CGSize(width: value.translation.width, height: value.translation.height * 0.3)
            }
            .onEnded { value in
                guard !flying else { return }
                let dx = value.translation.width
                if abs(dx) > throwDistance {
                    decide(dx > 0)
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { drag = .zero }
                }
            }
    }

    private var buttons: some View {
        HStack(spacing: 22) {
            Button { decide(false) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 62, height: 62)
                    .background(Circle().fill(.white).shadow(color: Palette.ink.opacity(0.08), radius: 6, y: 4))
                    .overlay(Circle().strokeBorder(Palette.lineStrong, lineWidth: 1.5))
            }
            .buttonStyle(PressStyle(scale: 0.9))
            .accessibilityLabel("Not for me")

            Button { if index < cards.count { go(cards[index]) } } label: {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 46, height: 46)
                    .background(Palette.surface2, in: Circle())
            }
            .buttonStyle(PressStyle(scale: 0.9))
            .accessibilityLabel("Directions")

            Button { decide(true) } label: {
                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 62)
                    .background(Circle().fill(Palette.accent).shadow(color: Palette.accent.opacity(0.35), radius: 10, y: 8))
            }
            .buttonStyle(PressStyle(scale: 0.9))
            .accessibilityLabel("Looks good")
        }
        .padding(.top, 10)
    }

    /// Record the choice, fly the card off and move on.
    private func decide(_ good: Bool) {
        guard index < cards.count, !flying else { return }
        let place = cards[index]
        let want = good ? 1 : -1
        if store.voteOf(place) != want { store.vote(place, want) }
        if good { liked.append(place) }
        Haptics.tap()
        flungOffset = drag
        flungTilt = Double(drag.width / 14)
        flungFade = 1
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) {
            flungID = place.id
            drag = .zero
        }
        withAnimation(.easeOut(duration: 0.32)) {
            flungOffset = CGSize(width: good ? 520 : -520, height: -30)
            flungTilt = good ? 24 : -24
            flungFade = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { feed.index += 1 }
            flungID = nil
            Task { await feed.topUp(store: store) }
        }
    }

    private func go(_ place: Place) {
        LiveActivityService.shared.start(place: place, store: store)
        NearbyService.directions(to: place)
    }
}
