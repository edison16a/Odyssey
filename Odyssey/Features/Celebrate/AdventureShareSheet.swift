//
//  AdventureShareSheet.swift
//  Odyssey
//
//  The 9:16 story card for a check-in. You preview it, can hide the streak
//  line, then send it to another app through the share sheet. Only the
//  place's photo and public fields go on the card, never your live location.
//  Ported from features/celebrate/story-card.js.
//

import Foundation
import SwiftUI
import UIKit

struct AdventureShareSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(RewardPopCenter.self) private var pop
    var place: Place
    var first: Bool

    @State private var showStreak = true
    @State private var rendered: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                IconButton(icon: "close", kind: .dark, label: "Close") { dismiss() }
                Text("Share your adventure").font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity)
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            card
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 20)
            Button {
                showStreak.toggle()
            } label: {
                Label("Show streak", systemImage: "flame.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .foregroundStyle(showStreak ? Palette.ink : .white)
                    .background(showStreak ? Color.white : Color.white.opacity(0.12), in: Capsule())
            }
            .buttonStyle(PressStyle())
            .padding(.top, 12)
            Group {
                if let rendered {
                    ShareLink(item: Image(uiImage: rendered), preview: SharePreview("My Odyssey adventure", image: Image(uiImage: rendered))) {
                        Label("Share to another app", systemImage: "square.and.arrow.up")
                    }
                    .simultaneousGesture(TapGesture().onEnded { pop.storyPosted(place, store: store) })
                } else {
                    Button {} label: { Label("Share to another app", systemImage: "square.and.arrow.up") }
                        .disabled(true)
                }
            }
            .buttonStyle(.pill(.light, fill: true))
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .foregroundStyle(.white)
        .background(Color.black.ignoresSafeArea())
        .overlay { RewardPopOverlay() }
        .onAppear(perform: render)
        .onChange(of: showStreak) { _, _ in render() }
    }

    private var card: some View {
        AdventureStoryCard(place: place, city: city, first: first,
                           streakDays: showStreak ? store.state.streak.days : nil, me: store.me)
            .aspectRatio(9 / 16, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .shadow(color: .black.opacity(0.6), radius: 30, y: 20)
    }

    private var city: String {
        if place.isOSM { return store.exploreLocation.label.components(separatedBy: ", ").last ?? "" }
        return store.seed.areas[place.areaID]?.city ?? ""
    }

    /// Draw the card at story size for sharing.
    private func render() {
        let view = AdventureStoryCard(place: place, city: city, first: first,
                                      streakDays: showStreak ? store.state.streak.days : nil, me: store.me)
            .frame(width: 360, height: 640)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        rendered = renderer.uiImage
    }
}

/// The card itself: the place photo full bleed, the wordmark and the line.
struct AdventureStoryCard: View {
    var place: Place
    var city: String
    var first: Bool
    var streakDays: Int?
    var me: Person

    var body: some View {
        GeometryReader { geo in
            ZStack {
                PhotoView(path: place.photo)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                LinearGradient(stops: [.init(color: .black.opacity(0.35), location: 0), .init(color: .clear, location: 0.25),
                                       .init(color: .clear, location: 0.5), .init(color: .black.opacity(0.8), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        OdysseyWordmark(size: 17)
                        Spacer()
                    }
                    Spacer()
                    foot
                }
                .padding(16)
            }
        }
        .background(Color(hex: "#222222"))
    }

    private var foot: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(city.isEmpty ? place.name : "\(place.name), \(city)", systemImage: "location.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.white.opacity(0.92), in: Capsule())
            Text(first ? "First explorer at \(place.name)" : "Adventure complete at \(place.name)")
                .font(.system(size: 21, weight: .heavy))
                .tracking(-0.4)
                .foregroundStyle(.white)
            if let streakDays {
                Tag(text: "\(streakDays) day streak", icon: "flame", tone: .dark)
            }
            HStack(spacing: 8) {
                AvatarView(person: me, size: 28)
                Text("@\(me.handle)").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            }
        }
    }
}
