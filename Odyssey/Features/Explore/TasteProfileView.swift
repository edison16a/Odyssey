//
//  TasteProfileView.swift
//  Odyssey
//
//  "What Odyssey knows about you", opened from View more under the Explore
//  deck. Your explorer type up top, then what you love and what you skip,
//  the places you really go, when you explore, the ground you have covered
//  and every thumb you gave. Nothing here leaves the phone, and one button
//  wipes what was learned.
//

import Foundation
import SwiftUI

struct TasteProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toast
    @State private var confirmReset = false

    var body: some View {
        let profile = TasteProfile(store: store)
        VStack(spacing: 0) {
            NavHeader(title: "What Odyssey knows", back: { router.pop() })
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TasteHero(profile: profile)
                    TasteSection(title: "What you love") { TasteBars(weights: profile.likes, empty: "Thumb up a few places and your favourites show up here.") }
                    if !profile.dislikes.isEmpty {
                        TasteSection(title: "Not really your thing") {
                            FlowLayout(spacing: 8) {
                                ForEach(profile.dislikes) { w in TastePill(text: w.label, icon: "hand.thumbsdown.fill", tint: Palette.muted) }
                            }
                        }
                    }
                    if !profile.visitedKinds.isEmpty {
                        TasteSection(title: "Where you actually go") {
                            FlowLayout(spacing: 8) {
                                ForEach(profile.visitedKinds, id: \.label) { kind in
                                    TastePill(text: "\(kind.label) \(kind.count)", icon: Icon.symbol(kind.icon), tint: Palette.accentInk)
                                }
                            }
                        }
                    }
                    if !profile.interests.isEmpty {
                        TasteSection(title: "Interests you picked") {
                            FlowLayout(spacing: 8) {
                                ForEach(profile.interests, id: \.self) { TastePill(text: $0, icon: "heart.fill", tint: Color(hex: "#e8553d")) }
                            }
                        }
                    }
                    if let line = profile.dayLine {
                        TasteSection(title: "When you explore") { TasteDayParts(parts: profile.dayParts, line: line) }
                    }
                    TasteSection(title: "Ground you have covered") { TasteGround() }
                    TasteSection(title: "Your thumbs") { TasteThumbs(thumbs: profile.thumbs) }
                    resetButton
                }
                .padding(.horizontal, Space.s4)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .background(Palette.surface)
        .confirmationDialog("Start your taste from scratch?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset what Odyssey learned", role: .destructive) {
                store.resetTaste()
                toast.show("Fresh start. Swipe a few to teach Odyssey again.", icon: "arrow.counterclockwise")
            }
        } message: {
            Text("Your thumbs and taste weights are cleared. Places you explored and your rewards stay.")
        }
    }

    private var resetButton: some View {
        Button { confirmReset = true } label: {
            Label("Reset what Odyssey learned", systemImage: "arrow.counterclockwise")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(Color(hex: "#d4343b"))
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressStyle())
        .padding(.top, 6)
    }
}

/// Walked area, first finds and starred places.
struct TasteGround: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(spacing: 8) {
            tile(String(format: "%.2f", store.footprintArea), "km² walked", "figure.walk", Palette.accent)
            tile("\(store.state.firsts.count)", "first finds", "star.fill", Palette.rare)
            tile("\(store.starredPlaces.count)", "starred", "star.circle.fill", Palette.gold)
        }
    }

    private func tile(_ value: String, _ label: String, _ icon: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(tint)
            Text(value).font(.system(size: 18, weight: .bold)).monospacedDigit().foregroundStyle(Palette.ink)
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.muted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
