//
//  ExploreCoachMarks.swift
//  Odyssey
//
//  The first time on the Explore feed, taught by doing. A hand shows the
//  swipe; once you swipe, it shows the double tap; once you save a place,
//  it says what that did and gets out of the way. Nothing here blocks the
//  feed, so the gestures are tried on real places.
//

import Foundation
import SwiftUI

struct ExploreCoachMarks: View {
    /// Bumped by the feed each time the explorer lands on another place.
    var moves: Int
    /// Bumped on every fresh save.
    var saves: Int
    var onDone: () -> Void

    private enum Phase { case swipe, save, saved }

    @State private var phase: Phase = .swipe
    @State private var shown = false

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Group {
                switch phase {
                case .swipe: SwipeHand()
                case .save: TapHand()
                case .saved:
                    Image(systemName: "heart.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color(hex: "#ff4d6d"))
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
            }
            .frame(height: 110)
            HStack(spacing: 8) {
                if phase != .saved {
                    Text(phase == .swipe ? "1 of 2" : "2 of 2")
                        .font(.system(size: 11, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 7)
                        .frame(height: 20)
                        .background(.white, in: Capsule())
                }
                Text(line)
                    .font(.system(size: 15, weight: .semibold))
                    .contentTransition(.opacity)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(.black.opacity(0.62), in: Capsule())
            .background(.ultraThinMaterial, in: Capsule())
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .opacity(shown ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) { shown = true }
        }
        .onChange(of: moves) {
            guard phase == .swipe else { return }
            Haptics.soft()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .save }
        }
        .onChange(of: saves) {
            guard phase != .saved else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { phase = .saved }
            Task {
                try? await Task.sleep(for: .seconds(2.4))
                withAnimation(.easeOut(duration: 0.3)) { shown = false }
                try? await Task.sleep(for: .milliseconds(300))
                onDone()
            }
        }
    }

    private var line: String {
        switch phase {
        case .swipe: return "Swipe up for the next place"
        case .save: return "Double tap to save one you like"
        case .saved: return "Saved! Odyssey will find more like it"
        }
    }
}

/// A hand that drags upward, over and over.
private struct SwipeHand: View {
    @State private var up = false

    var body: some View {
        Image(systemName: "hand.point.up.left.fill")
            .font(.system(size: 44))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
            .offset(x: 10, y: up ? -38 : 38)
            .opacity(up ? 0 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) { up = true }
            }
    }
}

/// A hand that taps twice, with a ripple under the fingertip.
private struct TapHand: View {
    var body: some View {
        PhaseAnimator([0, 1, 0, 1, 0, 0, 0]) { phase in
            ZStack {
                Circle()
                    .stroke(.white.opacity(phase == 1 ? 0.9 : 0), lineWidth: 3)
                    .frame(width: 54, height: 54)
                    .scaleEffect(phase == 1 ? 1 : 0.5)
                    .offset(x: -12, y: -14)
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
                    .scaleEffect(phase == 1 ? 0.86 : 1, anchor: .topLeading)
                    .offset(x: 10, y: 8)
            }
        } animation: { _ in
            .easeInOut(duration: 0.16)
        }
    }
}
