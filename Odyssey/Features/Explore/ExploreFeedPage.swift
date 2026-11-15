//
//  ExploreFeedPage.swift
//  Odyssey
//
//  One screen of the Explore feed: the place's photo edge to edge, its
//  name, how far it is and why Odyssey picked it, what it has (wifi, a
//  bathroom...), any Whop deal, and a small action rail on the right.
//  Double tap anywhere to save it. With several photos, tap the right or
//  left third to step through them, like stories.
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
    /// Where the Explore top bar ends, so the photo progress bars sit just under it.
    var topInset: CGFloat = 0

    @State private var hearts: [HeartBurst] = []
    /// Which photo of the gallery is showing.
    @State private var shown = 0
    @State private var width: CGFloat = 0

    /// Room kept clear on the right of the text for the rail.
    private static let railWidth: CGFloat = 64

    /// Only photos of this very place; a category stock photo is left out.
    private var gallery: [String] { place.realGallery }

    var body: some View {
        let metres = store.exploreMetres(to: place)
        ZStack(alignment: .bottomLeading) {
            photo
            LinearGradient(stops: [.init(color: .clear, location: 0.5),
                                   .init(color: .black.opacity(0.45), location: 0.78),
                                   .init(color: .black.opacity(0.7), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(count: 2, coordinateSpace: .local) { point in
                    let heart = HeartBurst(point: point)
                    hearts.append(heart)
                    onLike()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        hearts.removeAll { $0.id == heart.id }
                    }
                }
                .onTapGesture(count: 1, coordinateSpace: .local) { point in flip(at: point) }
            if gallery.count > 1 {
                progress
                    .padding(.top, topInset + Space.s2)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)
            }
            info(metres)
                .allowsHitTesting(false)
            ForEach(hearts) { heart in
                HeartBurstView()
                    .position(heart.point)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottomTrailing) { rail }
        .clipped()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onChange(of: place.id) { shown = 0 }
    }

    /// Tap the left third for the previous photo, the right third for the next.
    private func flip(at point: CGPoint) {
        let count = gallery.count
        guard count > 1, width > 0 else { return }
        let step: Int
        if point.x < width / 3 { step = -1 } else if point.x > width * 2 / 3 { step = 1 } else { return }
        let next = shown + step
        guard next >= 0, next < count else { Haptics.tap(); return }
        shown = next
    }

    /// Thin story style bars, one per photo, the current one and those before it filled.
    private var progress: some View {
        HStack(spacing: 4) {
            ForEach(gallery.indices, id: \.self) { i in
                Capsule()
                    .fill(.white.opacity(i <= shown ? 0.95 : 0.35))
                    .frame(height: 2.5)
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        .padding(.horizontal, Space.s4)
        .animation(.easeOut(duration: 0.15), value: shown)
    }

    /// The photo, over a plain dark fallback for places without a real one.
    private var photo: some View {
        let list = gallery
        return ZStack {
            Palette.ink
            Image(systemName: Icon.symbol(store.placeKind(place).icon))
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.white.opacity(0.08))
            if !list.isEmpty {
                PhotoView(path: list[min(shown, list.count - 1)], placeholder: .clear)
            }
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
        let shown = Array(amenities.prefix(3))
        return VStack(alignment: .leading, spacing: 6) {
            if let deal = bestDeal { dealTag(deal).padding(.bottom, 2) }
            Text(place.name)
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text("\(kind.label) · \(Format.distance(metres)) · \(Format.walkTime(metres))")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
            HStack(spacing: 5) {
                OdysseyMark(size: 11)
                Text(store.why(place, metres: metres)).lineLimit(1)
            }
            .font(.system(size: 13))
            .foregroundStyle(.white.opacity(0.85))
            if !shown.isEmpty {
                HStack(spacing: 6) {
                    ForEach(shown) { a in
                        HStack(spacing: 4) {
                            Image(systemName: a.icon).font(.system(size: 9, weight: .semibold))
                            Text(a.label).font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(.white.opacity(0.16), in: Capsule())
                        .fixedSize()
                    }
                    if amenities.count > shown.count {
                        Text("+\(amenities.count - shown.count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.top, 4)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
        .padding(.leading, Space.s4)
        .padding(.trailing, Self.railWidth + Space.s2)
        .padding(.bottom, Space.s5)
    }

    private func dealTag(_ deal: Deal) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "tag.fill").font(.system(size: 9, weight: .bold))
            Text(deal.percent > 0 ? "\(deal.percent)% off · via Whop" : "\(deal.title) · via Whop")
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(Palette.gold, in: Capsule())
    }

    private var rail: some View {
        let liked = store.voteOf(place) == 1
        let disliked = store.voteOf(place) == -1
        return VStack(spacing: Space.s3) {
            RailButton(icon: liked ? "heart.fill" : "heart", tint: liked ? Palette.danger : .white,
                       filled: liked, label: liked ? "Unsave" : "Save", action: onToggleLike)
            RailButton(icon: disliked ? "hand.thumbsdown.fill" : "hand.thumbsdown", tint: .white,
                       filled: false, label: "Not for me", action: onNotForMe)
            RailButton(icon: "location.north.fill", tint: .white,
                       filled: false, label: "Directions", action: onDirections)
            RailButton(icon: "info", tint: .white,
                       filled: false, label: "Details", action: onDetails)
        }
        .frame(width: Self.railWidth)
        .padding(.bottom, Space.s5)
    }
}

/// One small round button on the right. A saved heart sits on a white disc
/// so the red reads clearly; everything else is a quiet dark circle.
private struct RailButton: View {
    var icon: String
    var tint: Color
    var filled: Bool
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .background(filled ? Color.white : ExploreChrome.fill, in: Circle())
                .animation(.easeOut(duration: 0.18), value: filled)
        }
        .buttonStyle(PressStyle(scale: 0.9))
        .accessibilityLabel(label)
    }
}

struct HeartBurst: Identifiable {
    let id = UUID()
    var point: CGPoint
}

/// A white heart that pops where you double tapped, then fades.
struct HeartBurstView: View {
    var size: CGFloat = 84
    @State private var phase = 0

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: size))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.2), radius: 10, y: 2)
            .scaleEffect(phase == 0 ? 0.5 : 1)
            .opacity(phase == 1 ? 0.95 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) { phase = 1 }
                withAnimation(.easeOut(duration: 0.3).delay(0.4)) { phase = 2 }
            }
    }
}
