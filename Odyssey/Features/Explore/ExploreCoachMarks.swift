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
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                hand
                VStack(alignment: .leading, spacing: 18) {
                    row("arrow.up", "Swipe up to pass")
                    row("heart.fill", "Double tap or \u{2665} to save — your gem grows", tint: Color(hex: "#ff5f7e"))
                    row("line.3.horizontal.decrease", "Filter for wifi, bathrooms and more")
                }
                .padding(.horizontal, Space.s6)
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : 16)
                Text("Tap anywhere to start")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 18)
                    .frame(height: 40)
                    .background(.white, in: Capsule())
                    .padding(.top, 6)
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
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false)) { swipe = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var hand: some View {
        ZStack {
            Capsule()
                .fill(LinearGradient(colors: [.white.opacity(0), .white.opacity(0.35)], startPoint: .top, endPoint: .bottom))
                .frame(width: 10, height: 90)
                .offset(y: swipe ? -10 : 40)
                .opacity(swipe ? 0 : 0.9)
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 58))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
                .offset(x: 14, y: swipe ? -50 : 50)
                .opacity(swipe ? 0.15 : 1)
        }
        .frame(height: 170)
    }

    private func row(_ icon: String, _ text: String, tint: Color = .white) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.14), in: Circle())
            Text(text)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
