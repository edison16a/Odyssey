//
//  ExploreFeedPage.swift
//  Odyssey
//
//  One screen of the Explore feed: the place's photo edge to edge, its
//  name, how far it is and why Odyssey picked it, what it has (wifi, a
//  bathroom...), any Whop deal, and the action rail down the right side.
//  Double tap anywhere to save it with a heart burst.
//

import Foundation
import SwiftUI

struct ExploreFeedPage: View {
    @Environment(AppStore.self) private var store
    var place: Place
    var onLike: () -> Void
    var onToggleLike: () -> Void
    var onNotForMe: () -> Void
    var onDirections: () -> Void
    var onDetails: () -> Void

    @State private var bursts: [HeartBurst] = []

    var body: some View {
        let metres = store.metres(to: place)
        ZStack(alignment: .bottomLeading) {
            photo
            LinearGradient(stops: [.init(color: .clear, location: 0.38),
                                   .init(color: .black.opacity(0.55), location: 0.7),
                                   .init(color: .black.opacity(0.88), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(count: 2, coordinateSpace: .local) { point in
                    let burst = HeartBurst(point: point, tilt: Double.random(in: -18...18))
                    bursts.append(burst)
                    onLike()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                        bursts.removeAll { $0.id == burst.id }
                    }
                }
            info(metres)
                .allowsHitTesting(false)
            ForEach(bursts) { burst in
                HeartBurstView(tilt: burst.tilt)
                    .position(burst.point)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottomTrailing) { rail }
        .clipped()
    }

    /// The photo, over a dark tinted fallback for places without one.
    private var photo: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#2a3242"), Color(hex: "#11141b")], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: Icon.symbol(store.placeKind(place).icon))
                .font(.system(size: 90, weight: .semibold))
                .foregroundStyle(.white.opacity(0.08))
            PhotoView(path: place.photo, placeholder: .clear)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .allowsHitTesting(false)
    }

    private var bestDeal: Deal? {
        (store.deals[place.id] ?? []).max { $0.percent < $1.percent }
    }

    private func info(_ metres: Double) -> some View {
        let kind = store.placeKind(place)
        let amenities = ExploreAmenity.of(place, store: store)
        return VStack(alignment: .leading, spacing: 8) {
            if let deal = bestDeal { dealPill(deal) }
            Text(place.name)
                .font(.system(size: 30, weight: .heavy))
                .tracking(-0.7)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            HStack(spacing: 6) {
                Image(systemName: Icon.symbol(kind.icon)).font(.system(size: 12, weight: .bold))
                Text("\(kind.label) · \(Format.distance(metres)) · \(Format.walkTime(metres))")
                    .lineLimit(1)
            }
            .font(.system(size: 13, weight: .semibold))
            .opacity(0.92)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                OdysseyMark(size: 11)
                Text(store.why(place, metres: metres)).lineLimit(2)
            }
            .font(.system(size: 13, weight: .medium))
            .opacity(0.88)
            if !amenities.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(amenities) { a in
                        HStack(spacing: 4) {
                            Image(systemName: a.icon).font(.system(size: 10, weight: .bold))
                            Text(a.label).font(.system(size: 11, weight: .bold))
                        }
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(.white.opacity(0.18), in: Capsule())
                    }
                }
                .padding(.top, 2)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
        .padding(.leading, Space.s4)
        .padding(.trailing, 92)
        .padding(.bottom, 22)
    }

    private func dealPill(_ deal: Deal) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "tag.fill").font(.system(size: 11, weight: .bold))
            Text(deal.percent > 0 ? "\(deal.percent)% off · via Whop" : "\(deal.title) · via Whop")
                .lineLimit(1)
        }
        .font(.system(size: 12, weight: .heavy))
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(Palette.gold, in: Capsule())
    }

    private var rail: some View {
        let liked = store.voteOf(place) == 1
        let disliked = store.voteOf(place) == -1
        return VStack(spacing: 16) {
            RailButton(icon: liked ? "heart.fill" : "heart", label: liked ? "Saved" : "Save",
                       tint: liked ? Color(hex: "#ff3b5c") : .white, bounce: liked, action: onToggleLike)
                .accessibilityLabel(liked ? "Unsave" : "Save")
            RailButton(icon: disliked ? "hand.thumbsdown.fill" : "hand.thumbsdown", label: "Not for me",
                       tint: .white, bounce: disliked, action: onNotForMe)
            RailButton(icon: "location.north.fill", label: "Go", tint: .white, bounce: false, action: onDirections)
                .accessibilityLabel("Directions")
            RailButton(icon: "info.circle.fill", label: "Details", tint: .white, bounce: false, action: onDetails)
        }
        .padding(.trailing, 10)
        .padding(.bottom, 22)
    }
}

/// One round button on the right with its label underneath.
private struct RailButton: View {
    var icon: String
    var label: String
    var tint: Color
    var bounce: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: bounce)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(.black.opacity(0.28)))
                    .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(width: 70)
            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
        }
        .buttonStyle(PressStyle(scale: 0.88))
    }
}

struct HeartBurst: Identifiable {
    let id = UUID()
    var point: CGPoint
    var tilt: Double
}

/// The big heart that pops where you double tapped, then floats up and fades.
struct HeartBurstView: View {
    var tilt: Double
    var size: CGFloat = 110
    @State private var phase = 0

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(Color(hex: "#ff6b8a"))
                    .frame(width: 10, height: 10)
                    .offset(y: phase == 0 ? 0 : -size * 0.75)
                    .rotationEffect(.degrees(Double(i) * 60))
                    .opacity(phase == 1 ? 1 : 0)
            }
            Image(systemName: "heart.fill")
                .font(.system(size: size))
                .foregroundStyle(LinearGradient(colors: [Color(hex: "#ff7a95"), Color(hex: "#ff2d55")],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(color: Color(hex: "#ff2d55").opacity(0.5), radius: 18)
        }
        .rotationEffect(.degrees(tilt))
        .scaleEffect(phase == 0 ? 0.2 : (phase == 1 ? 1 : 1.3))
        .opacity(phase == 2 ? 0 : 1)
        .offset(y: phase == 2 ? -70 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { phase = 1 }
            withAnimation(.easeIn(duration: 0.35).delay(0.45)) { phase = 2 }
        }
    }
}
