//
//  TasteProfileParts.swift
//  Odyssey
//
//  The pieces of the taste page: the colored hero with your explorer type,
//  section cards, taste bars, pills, the time of day strip and the list of
//  thumbs.
//

import Foundation
import SwiftUI

struct TasteHero: View {
    @Environment(AppStore.self) private var store
    var profile: TasteProfile
    /// Onboarding shows the banner before there is anything to count.
    var showStats = true
    /// Replaces the "Mostly drawn to…" line when set.
    var line: String? = nil
    @State private var shown = false

    var body: some View {
        let color = profile.persona.color
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: profile.persona.icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 56, height: 56)
                    .background(.white, in: Circle())
                    .scaleEffect(shown ? 1 : 0.4)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your explorer type").font(.system(size: 12, weight: .bold)).opacity(0.8)
                    Text(profile.persona.name).font(.system(size: 28, weight: .heavy, design: .rounded)).tracking(-0.6)
                }
            }
            Text(line ?? subline).font(.system(size: 15, weight: .medium)).opacity(0.92)
            if showStats {
                HStack(spacing: 8) {
                    stat("\(profile.thumbs.count)", "thumbs")
                    stat("\(store.state.stats.explored)", "explored")
                    stat(Format.number(store.kmWalked), "km walked")
                }
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Image(systemName: profile.persona.icon)
                .font(.system(size: 120, weight: .black))
                .foregroundStyle(.white.opacity(0.1))
                .rotationEffect(.degrees(-14))
                .offset(x: 18, y: -10)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) { shown = true } }
    }

    private var subline: String {
        let top = profile.likes.prefix(2).map { $0.label.lowercased() }
        if top.isEmpty { return "Swipe through Explore and Odyssey starts to see what you love." }
        return "Mostly drawn to " + top.joined(separator: " and ") + "."
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.system(size: 18, weight: .bold)).monospacedDigit()
            Text(label).font(.system(size: 11, weight: .semibold)).opacity(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct TasteSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
    }
}

struct TasteBars: View {
    var weights: [TasteProfile.Weight]
    var empty: String
    @State private var grown = false

    private static let colors = ["#2b59ff", "#17a35a", "#8a5cff", "#f2b21b", "#e8553d", "#14a3b8", "#d6457f", "#ff7a1a"]

    var body: some View {
        if weights.isEmpty {
            Text(empty).font(.system(size: 13)).foregroundStyle(Palette.ink2)
        } else {
            VStack(spacing: 10) {
                ForEach(Array(weights.enumerated()), id: \.element.id) { i, w in
                    HStack(spacing: 10) {
                        Text(w.label).font(.system(size: 13, weight: .semibold)).frame(width: 118, alignment: .leading).lineLimit(1)
                        GeometryReader { geo in
                            Capsule().fill(Palette.surface3)
                                .overlay(alignment: .leading) {
                                    Capsule().fill(Color(hex: Self.colors[i % Self.colors.count]))
                                        .frame(width: grown ? max(10, geo.size.width * min(1, w.value / 4)) : 10)
                                }
                        }
                        .frame(height: 10)
                    }
                }
            }
            .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.15)) { grown = true } }
        }
    }
}

struct TastePill: View {
    var text: String
    var icon: String
    var tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(text).font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(.white, in: Capsule())
    }
}

struct TasteDayParts: View {
    var parts: [Double]
    var line: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(line).font(.system(size: 13)).foregroundStyle(Palette.ink2)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(zip(["Morning", "Afternoon", "Evening", "Night"], ["sunrise.fill", "sun.max.fill", "sunset.fill", "moon.fill"]).enumerated()), id: \.offset) { i, item in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(i == (parts.indices.max { parts[$0] < parts[$1] } ?? 0) ? Palette.accent : Palette.surface3)
                            .frame(height: 12 + 60 * (i < parts.count ? parts[i] : 0))
                        Image(systemName: item.1).font(.system(size: 13)).foregroundStyle(Palette.ink2)
                        Text(item.0).font(.system(size: 10, weight: .semibold)).foregroundStyle(Palette.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

struct TasteThumbs: View {
    var thumbs: [TasteProfile.Thumb]
    @State private var all = false

    var body: some View {
        if thumbs.isEmpty {
            Text("No thumbs yet. Swipe right or left in Explore.").font(.system(size: 13)).foregroundStyle(Palette.ink2)
        } else {
            VStack(spacing: 8) {
                ForEach(thumbs.prefix(all ? 60 : 6)) { thumb in
                    HStack(spacing: 10) {
                        Image(systemName: thumb.up ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(thumb.up ? .white : Palette.ink)
                            .frame(width: 28, height: 28)
                            .background(thumb.up ? Palette.accent : Palette.surface3, in: Circle())
                        Text(thumb.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                        Spacer()
                        Text(thumb.date, format: .dateTime.month(.abbreviated).day()).font(.system(size: 11)).foregroundStyle(Palette.muted)
                    }
                }
                if thumbs.count > 6 {
                    Button(all ? "Show fewer" : "Show all \(thumbs.count)") { withAnimation { all.toggle() } }
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.accentInk)
                }
            }
        }
    }
}
