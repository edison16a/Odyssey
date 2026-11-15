//
//  ExploreGemHUD.swift
//  Odyssey
//
//  Your taste gem, pinned top left of the Explore feed. Every save sends a
//  "+1" flying into it; the gem pops, grows a little, and says how close
//  the next level is. Tap it for the full taste profile.
//

import Foundation
import SwiftUI

struct ExploreGemHUD: View {
    var gem: TasteGem
    /// Bumped on every save to pop the gem.
    var pops: Int
    /// Shown briefly after a save, e.g. "Level 3 · 2 saves to next".
    var note: String?
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                TasteGemView(gem: gem, size: 42)
                    .keyframeAnimator(initialValue: 1.0, trigger: pops) { content, scale in
                        content.scaleEffect(scale)
                    } keyframes: { _ in
                        SpringKeyframe(1.45, duration: 0.16, spring: .snappy)
                        SpringKeyframe(1.0, duration: 0.5, spring: .bouncy)
                    }
                VStack(alignment: .leading, spacing: 1) {
                    Text(note == nil ? gem.persona : "+1 save")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.white)
                        .contentTransition(.opacity)
                    Text(note ?? "Level \(gem.level) gem")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(note == nil ? .white.opacity(0.75) : Palette.gold)
                        .contentTransition(.numericText())
                }
                .lineLimit(1)
                .padding(.trailing, 6)
            }
            .padding(.leading, 2)
            .padding(.trailing, 8)
            .frame(height: 48)
            .background(Capsule().fill(.black.opacity(0.34)))
            .overlay(Capsule().strokeBorder(note == nil ? .white.opacity(0.18) : Palette.gold.opacity(0.8), lineWidth: 1.2))
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: note)
        }
        .buttonStyle(PressStyle(scale: 0.95))
        .accessibilityLabel("Your taste gem, level \(gem.level). Open taste profile")
    }
}

/// The "+1" that flies from the save button into the gem.
struct GemSparkle: View {
    var from: CGPoint
    var to: CGPoint
    @State private var arrived = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles").font(.system(size: 13, weight: .bold))
            Text("+1").font(.system(size: 15, weight: .heavy))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Capsule().fill(LinearGradient(colors: [Color(hex: "#ff5f7e"), Palette.accent],
                                                  startPoint: .leading, endPoint: .trailing)))
        .shadow(color: Palette.accent.opacity(0.5), radius: 10)
        .scaleEffect(arrived ? 0.45 : 1.15)
        .opacity(arrived ? 0.3 : 1)
        .position(arrived ? to : from)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.timingCurve(0.5, 0, 0.8, 0.6, duration: 0.6)) { arrived = true }
        }
    }
}
