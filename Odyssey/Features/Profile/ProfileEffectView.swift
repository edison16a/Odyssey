//
//  ProfileEffectView.swift
//  Odyssey
//
//  Profile effects: animated art that wraps the whole edge of a profile,
//  the way the mockup's effects sit over the entire card. Vines hug the
//  real corners, energy races the real edge, petals and embers drift down
//  the sides. It never takes touches, so the profile underneath stays
//  fully usable.
//

import Foundation
import SwiftUI

struct ProfileEffectView: View {
    @Environment(\.animationsPaused) private var animationsPaused
    var id: String
    var cornerRadius: CGFloat = 32

    var body: some View {
        Group {
            if id == "none" || id.isEmpty {
                Color.clear
            } else {
                TimelineView(OdysseyMotion.schedule(paused: animationsPaused)) { timeline in
                    Canvas { context, size in
                        let scene = ProfileEffectScene(size: size, radius: Double(cornerRadius), t: timeline.date.timeIntervalSinceReferenceDate, seed: id)
                        ProfileEffectArt.draw(id, context, scene)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Everything an effect needs to know about the space it decorates.
struct ProfileEffectScene {
    var size: CGSize
    var radius: Double
    var t: Double
    var seed: String

    var w: Double { size.width }
    var h: Double { size.height }

    /// The rounded edge, inset a few points.
    func edge(_ inset: Double) -> Path {
        let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
        return Path(roundedRect: rect, cornerRadius: max(0, radius - inset), style: .continuous)
    }

    /// A repeatable random sequence, so the effect looks the same every frame.
    func random() -> () -> Double { StableHash.generator("fx-" + seed) }

    /// A point a fraction of the way round the edge.
    func point(on path: Path, _ fraction: Double) -> CGPoint {
        let f = fraction - floor(fraction)
        return path.trimmedPath(from: f, to: min(1, f + 0.0008)).currentPoint ?? CGPoint(x: w / 2, y: 0)
    }

    func cycle(_ duration: Double, _ begin: Double = 0) -> Double {
        ProfileFrameKit.cycle(t, duration, begin)
    }

    func wave(_ duration: Double, _ begin: Double = 0) -> Double {
        (1 - cos(2 * .pi * cycle(duration, begin))) / 2
    }
}

/// A small card wearing an effect, for the shop grid, the edit picker and unboxing.
struct ProfileEffectCard: View {
    var id: String
    var person: Person
    var width: CGFloat = 84

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.18, style: .continuous).fill(Palette.surface)
            VStack(spacing: width * 0.05) {
                AvatarView(person: person, size: width * 0.36, frame: "none")
                Capsule().fill(Palette.lineStrong).frame(width: width * 0.42, height: width * 0.05)
                Capsule().fill(Palette.line).frame(width: width * 0.3, height: width * 0.04)
            }
            ProfileEffectView(id: id, cornerRadius: width * 0.18)
        }
        .frame(width: width, height: width * 1.2)
        .clipShape(RoundedRectangle(cornerRadius: width * 0.18, style: .continuous))
    }
}
