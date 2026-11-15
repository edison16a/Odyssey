//
//  HomeRevealFaces.swift
//  Odyssey
//
//  The two faces of the daily reveal card. The front is the blue sealed
//  side with the hold ring and the Odyssey mark; the back is the headline,
//  the place's photo and its details. Ported from daily-reveal.js,
//  daily-reveal.css, reveal-hold.css and reveal-back.css.
//

import Foundation
import SwiftUI

/// Turns around the vertical axis and swaps faces at the halfway point.
struct HomeRevealFlip<Front: View, Back: View>: View, Animatable {
    var angle: Double
    var front: Front
    var back: Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        ZStack {
            front.opacity(angle < 90 ? 1 : 0)
            back
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(angle < 90 ? 0 : 1)
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
    }
}

/// The sealed side: blue (purple during a rare burst), glowing as it charges.
struct HomeRevealFront: View {
    var charge: Double
    var holding: Bool
    var burst: Bool
    var stamped: Bool
    var time: Double

    private static let sparkles: [(x: CGFloat, y: CGFloat, delay: Double)] = [
        (0.18, 0.30, 0), (0.78, 0.24, 0.5), (0.30, 0.76, 1), (0.70, 0.70, 1.5), (0.50, 0.14, 2),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<HomeRevealFront.sparkles.count, id: \.self) { i in sparkle(i, size: geo.size) }
                VStack(spacing: 14) {
                    dial
                    Text("Where to today?").font(.system(size: 26, weight: .heavy)).foregroundStyle(.white)
                    Text("Press and hold to reveal")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(holding ? Palette.accent : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(holding ? Color.white : Color.white.opacity(0.18 + 0.14 * GlobieArt.wave(time, 1.6)), in: Capsule())
                }
                stamp
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(burst ? Palette.rare : Palette.accent)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 34, style: .continuous).fill(.white.opacity(0.12)).padding(-6))
        .shadow(color: .white.opacity(charge * 0.55), radius: CGFloat(charge * 35))
        .shadow(color: .black.opacity(0.5), radius: 30, y: 30)
    }

    private var dial: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.2), lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(charge))
                .stroke(.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            OdysseyMark(size: 60)
                .offset(y: CGFloat(-4 * GlobieArt.wave(time, 1.6)))
        }
        .frame(width: 128, height: 128)
        .frame(width: 140, height: 140)
    }

    /// float-up: fade in, rise 44pt, fade out over 2.4 s.
    private func sparkle(_ i: Int, size: CGSize) -> some View {
        let s = HomeRevealFront.sparkles[i]
        let k = GlobieArt.cycle(time, 2.4, s.delay)
        let opacity = k < 0.2 ? k / 0.2 : 1 - (k - 0.2) / 0.8
        return Circle()
            .fill(.white)
            .frame(width: 6, height: 6)
            .opacity(opacity)
            .position(x: size.width * s.x, y: size.height * s.y + CGFloat(8 - 44 * k))
    }

    private var stamp: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill").font(.system(size: 18, weight: .bold))
            Text("RARE FIND").font(.system(size: 24, weight: .black)).tracking(1)
        }
        .foregroundStyle(Palette.rare)
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .rotationEffect(.degrees(-8))
        .scaleEffect(stamped ? 1 : 3)
        .opacity(stamped ? 1 : 0)
        .allowsHitTesting(false)
    }
}

/// The revealed side: the headline first, then the photo and its details.
struct HomeRevealBack: View {
    @Environment(AppStore.self) private var store
    var place: Place
    var reason: String
    var rare: Bool

    var body: some View {
        let meters = store.metres(to: place)
        let kind = store.placeKind(place)
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                if rare {
                    Tag(text: "Rare find, nobody has been", icon: "star-fill", tone: .rare)
                } else {
                    Tag(text: "Today's pick", icon: "compass", tone: .accent)
                }
                (Text(rare ? "Be the first to discover " : "Go explore ")
                    + Text(place.name).foregroundColor(rare ? Palette.rare : Palette.accent))
                    .font(.system(size: 27, weight: .heavy)).tracking(-0.8).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(reason).font(.system(size: 13)).foregroundStyle(Palette.muted)
            }
            PlacePhoto(place: place)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .overlay(alignment: .topLeading) { category(kind) }
            VStack(alignment: .leading, spacing: 6) {
                info("mappin", place.address ?? "")
                info("figure.walk", Format.distance(meters) + ", " + Format.walkTime(meters))
                info("clock", place.hours ?? "")
                Divider().overlay(Palette.line).padding(.top, 4)
                HStack(spacing: 8) {
                    CoinIcon(size: 15)
                    Text("\(Rewards.checkIn.coins + (rare ? Rewards.first.coins : 0))").font(.system(size: 13, weight: .semibold))
                    Text("+\(Rewards.checkIn.xp) XP").font(.system(size: 13, weight: .bold))
                    Spacer()
                    if rare {
                        Label("Your name on it", systemImage: "star.fill")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.rare)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            if rare { RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Palette.rare, lineWidth: 3) }
        }
        .shadow(color: rare ? Palette.rare.opacity(0.55) : .clear, radius: 30)
        .shadow(color: .black.opacity(0.5), radius: 30, y: 30)
    }

    private func category(_ kind: (label: String, icon: String)) -> some View {
        HStack(spacing: 4) {
            Image(systemName: Icon.symbol(kind.icon)).font(.system(size: 10, weight: .bold))
            Text(kind.label).font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(.white.opacity(0.92), in: Capsule())
        .padding(10)
    }

    private func info(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 13)).foregroundStyle(Palette.muted).frame(width: 16)
            Text(text).font(.system(size: 13)).foregroundStyle(Palette.ink).lineLimit(1)
        }
    }
}
