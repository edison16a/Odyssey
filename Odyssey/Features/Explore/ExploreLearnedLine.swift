//
//  ExploreLearnedLine.swift
//  Odyssey
//
//  The quiet line under the deck: what Odyssey has learned you like, or a
//  note that your taste travelled with you, and a View more link into the
//  full picture of what it knows.
//

import Foundation
import SwiftUI

struct ExploreLearnedLine: View {
    @Environment(AppStore.self) private var store
    var onMore: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            icon
            Text(text).lineLimit(2)
            Button(action: onMore) {
                HStack(spacing: 2) {
                    Text("View more")
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .heavy))
                }
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Palette.surface2, in: Capsule())
            }
            .buttonStyle(PressStyle())
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Palette.accentInk)
        .multilineTextAlignment(.center)
        .padding(.horizontal, Space.s4)
        .padding(.top, 10)
    }

    private var traveling: Bool {
        store.exploreCenter.distance(to: store.home.center) > 25_000
    }

    @ViewBuilder private var icon: some View {
        if traveling {
            Image(systemName: "airplane").font(.system(size: 11, weight: .bold))
        } else {
            OdysseyMark(size: 12)
        }
    }

    private var text: String {
        if traveling {
            let city = store.exploreLocation.label.split(separator: ",").first.map(String.init) ?? "here"
            return "Your taste came with you to \(city)"
        }
        let likes = store.tasteSummary().likes
        if likes.isEmpty { return "Swipe a few and Odyssey learns what you love" }
        return "Odyssey has learned you like " + likes.prefix(2).joined(separator: " and ").lowercased()
    }
}
