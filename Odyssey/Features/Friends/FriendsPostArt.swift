//
//  FriendsPostArt.swift
//  Odyssey
//
//  Milestone posts ("Now ranked #1 in Berkeley", a new rank, a long streak)
//  show a bold colored card with slowly turning rays instead of a photo,
//  so big moments stand out in the feed and the story row.
//  Ported from milestone-card.js.
//

import Foundation
import SwiftUI

struct FriendsMilestoneArt: View {
    @Environment(AppStore.self) private var store
    var post: Post
    var milestone: Milestone
    var tile = false

    var body: some View {
        let color = Color(hex: milestone.color)
        ZStack {
            color
            if milestone.photo == true, let place = store.place(post.placeId) {
                PlacePhoto(place: place).opacity(0.28).blendMode(.luminosity)
            }
            FriendsRays()
            VStack(spacing: tile ? 2 : 6) {
                if !tile { eyebrow }
                hero
                Text(milestone.line)
                    .font(.system(size: tile ? 11 : 24, weight: .heavy))
                    .tracking(tile ? 0 : -0.5)
                    .multilineTextAlignment(.center)
                if !tile {
                    Text(milestone.sub).font(.system(size: 13)).opacity(0.85)
                    who.padding(.top, 6)
                }
            }
            .foregroundStyle(.white)
            .padding(tile ? 8 : 18)
        }
        .overlay(alignment: .bottomLeading) {
            if !tile {
                OdysseyWordmark(size: 13)
                    .opacity(0.85)
                    .padding(14)
            }
        }
        .clipped()
    }

    private var eyebrow: some View {
        HStack(spacing: 5) {
            Image(systemName: "trophy.fill").font(.system(size: 10, weight: .bold))
            Text(milestone.eyebrow).font(.system(size: 11, weight: .heavy)).tracking(0.9).textCase(.uppercase)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(.black.opacity(0.22), in: Capsule())
    }

    @ViewBuilder private var hero: some View {
        switch milestone.type {
        case "tier":
            RankEmblem(tier: milestone.tier ?? 0, size: tile ? 46 : 110, inverse: true)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 8)
        case "streak":
            Image(systemName: "flame.fill")
                .font(.system(size: tile ? 34 : 64))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 8)
        default:
            Text(milestone.big ?? "")
                .font(.system(size: tile ? 40 : 110, weight: .black))
                .tracking(tile ? -2 : -6)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .shadow(color: .black.opacity(0.25), radius: 15, y: 10)
        }
    }

    @ViewBuilder private var who: some View {
        if let person = store.person(post.by) {
            HStack(spacing: 7) {
                AvatarView(person: person, size: 26, frame: "none")
                Text("@" + person.handle).font(.system(size: 13, weight: .semibold))
            }
        }
    }
}

/// Faint white wedges turning slowly behind a milestone.
private struct FriendsRays: View {
    @Environment(\.animationsPaused) private var animationsPaused
    var body: some View {
        TimelineView(OdysseyMotion.schedule(paused: animationsPaused)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = max(size.width, size.height)
                let turn = (t / 30).truncatingRemainder(dividingBy: 1) * 360
                for k in 0..<12 {
                    let start = Double(k) * 30 + turn
                    var wedge = Path()
                    wedge.move(to: center)
                    wedge.addArc(center: center, radius: radius, startAngle: .degrees(start),
                                 endAngle: .degrees(start + 10), clockwise: false)
                    wedge.closeSubpath()
                    context.fill(wedge, with: .color(.white.opacity(0.1)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
