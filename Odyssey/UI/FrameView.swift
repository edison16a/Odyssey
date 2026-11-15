//
//  FrameView.swift
//  Odyssey
//
//  Avatar frames from the shop, the Odyssey take on profile decorations.
//  Each is drawn in a box 1.36 times the face so flames, leaves or wings
//  can reach past the avatar's edge, exactly like the mockup's SVG. The
//  drawing for every frame lives in Features/Profile/ProfileFrames*.swift;
//  this view picks the right one and keeps it moving.
//

import Foundation
import SwiftUI

struct FrameView: View {
    @Environment(\.animationsPaused) private var animationsPaused
    var id: String
    var size: CGFloat
    var tier: Int = 0

    /// Frames that hold still, so they skip the animation clock.
    private static let still: Set<String> = ["mono", "accent", "none", ""]

    var body: some View {
        let box = size * 1.36
        Group {
            if id.hasPrefix("globie-") {
                GlobieFrame(tier: StreakTiers.tier(id: String(id.dropFirst(7))), size: size)
            } else if FrameView.still.contains(id) {
                FrameCanvas(id: id, tier: tier, time: 0)
            } else {
                // Small avatars in rows hold still; big profile avatars animate.
                TimelineView(OdysseyMotion.schedule(paused: animationsPaused || size < 56)) { timeline in
                    FrameCanvas(id: id, tier: tier, time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .frame(width: box, height: box)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// One frame drawn at one moment, scaled from the 136 point design box.
private struct FrameCanvas: View {
    var id: String
    var tier: Int
    var time: Double

    var body: some View {
        Canvas { context, size in
            let scale = size.width / 136
            context.scaleBy(x: scale, y: scale)
            if ProfileFramesClassic.draw(id, context, t: time) { return }
            if ProfileFramesNature.draw(id, context, t: time, tier: tier) { return }
            if ProfileFramesLegend.draw(id, context, t: time, tier: tier) { return }
            if ProfileFramesBoard.draw(id, context, t: time) { return }
            // Unknown ids still get a plain accent ring rather than nothing.
            ProfileFrameKit.ring(context, 53, Palette.accent, 4.5)
        }
    }
}

/// The frame a streak milestone unlocks: a glowing ring in the tier's color
/// with that Globie form's motif around it.
struct GlobieFrame: View {
    @Environment(\.animationsPaused) private var animationsPaused
    var tier: StreakTier
    var size: CGFloat

    var body: some View {
        TimelineView(OdysseyMotion.schedule(paused: animationsPaused || size < 56)) { timeline in
            Canvas { context, canvas in
                let scale = canvas.width / 136
                context.scaleBy(x: scale, y: scale)
                ProfileFramesStreak.draw(tier, context, t: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
        .frame(width: size * 1.36, height: size * 1.36)
        .allowsHitTesting(false)
    }
}
