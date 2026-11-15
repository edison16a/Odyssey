//
//  ExploreCoachMarks.swift
//  Odyssey
//
//  The first-time tour over the Explore feed: a hand that swipes up and
//  three short lines on how the feed works. Tap anywhere to start.
//

import Foundation
import SwiftUI

struct ExploreCoachMarks: View {
    var onDone: () -> Void
    @State private var swipe = false
    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: Space.s8) {
                Spacer()
                hand
                VStack(alignment: .leading, spacing: Space.s4) {
                    row("arrow.up", "Swipe up for the next place")
                    row("heart", "Double tap or tap the heart to save")
                    row("line.3.horizontal.decrease", "Filter for wifi, bathrooms and more")
                }
                .padding(.horizontal, Space.s8)
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : 12)
                Text("Tap anywhere to start")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap()
            onDone()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.15)) { shown = true }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) { swipe = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var hand: some View {
        Image(systemName: "hand.point.up.left.fill")
            .font(.system(size: 44))
            .foregroundStyle(.white)
            .offset(x: 10, y: swipe ? -36 : 36)
            .opacity(swipe ? 0 : 1)
            .frame(height: 120)
    }

    private func row(_ icon: String, _ text: String) -> some View {
        HStack(spacing: Space.s3) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.14), in: Circle())
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
    }
}
