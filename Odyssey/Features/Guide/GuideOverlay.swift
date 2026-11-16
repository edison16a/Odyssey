//
//  GuideOverlay.swift
//  Odyssey
//
//  The spotlight itself: a dim sheet over the app with a hole cut around
//  one control, a soft ring that pulses on it, and Globie's bubble with one
//  short line. Info steps move on with a tap anywhere; action steps let the
//  tap through the hole, so the explorer presses the real button.
//

import Foundation
import SwiftUI

struct GuideOverlay: View {
    @Environment(Guide.self) private var guide
    @Environment(AppRouter.self) private var router
    @Environment(AppStore.self) private var store
    @State private var pulse = false
    /// Bumped when the dim area is tapped on an action step, to shake the ring.
    @State private var nudges = 0

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            if let step = guide.step, showing(step), let raw = guide.frame(of: step.spot), raw.width > 1 {
                let hole = raw.offsetBy(dx: -origin.x, dy: -origin.y).insetBy(dx: -pad(step.spot), dy: -pad(step.spot))
                let radius = radius(step.spot, hole)
                ZStack(alignment: .topLeading) {
                    SpotlightShape(hole: hole, radius: radius)
                        .fill(Color.black.opacity(0.66), style: FillStyle(eoFill: true))
                        .contentShape(SpotlightShape(hole: step.advance == .tapSpot ? hole : .zero, radius: radius), eoFill: true)
                        .onTapGesture {
                            if step.advance == .next { guide.next() } else { Haptics.soft(); nudges += 1 }
                        }
                        .accessibilityHidden(true)
                    ring(hole, radius: radius)
                    bubble(step, hole: hole, size: geo.size)
                }
                .transition(.opacity)
                .onAppear {
                    pulse = false
                    withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
                }
            }
        }
        .ignoresSafeArea()
        .onChange(of: router.tab) { passIfDone() }
        .onChange(of: router.paths) { passIfDone() }
        .onChange(of: store.dailyRevealed) { passIfDone() }
    }

    /// Spotlights wait until their tab is showing with nothing on top of it.
    private func showing(_ step: GuideStep) -> Bool {
        router.cover == nil && router.tab == step.tab && router.path(step.tab).isEmpty
    }

    /// An action step is passed when the app is where its button leads.
    private func passIfDone() {
        guard let step = guide.step, step.advance == .tapSpot else { return }
        switch step.spot {
        case .hero: if store.dailyRevealed { guide.next() }
        case .exploreTab: if router.tab == .explore { guide.next() }
        case .friends: if !router.path(.home).isEmpty { guide.next() }
        default: break
        }
    }

    private func pad(_ spot: GuideSpot) -> CGFloat {
        switch spot {
        case .hero: return 6
        case .stats: return 8
        case .exploreTab: return 2
        case .friends: return 8
        }
    }

    private func radius(_ spot: GuideSpot, _ hole: CGRect) -> CGFloat {
        switch spot {
        case .hero: return Radius.lg + 6
        case .exploreTab: return 18
        default: return min(hole.height, hole.width) / 2
        }
    }

    private func ring(_ hole: CGRect, radius: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(.white, lineWidth: 2.5)
            RoundedRectangle(cornerRadius: radius + 6, style: .continuous)
                .strokeBorder(.white.opacity(pulse ? 0 : 0.55), lineWidth: 2)
                .padding(pulse ? -12 : -2)
        }
        .frame(width: hole.width, height: hole.height)
        .keyframeAnimator(initialValue: 0.0, trigger: nudges) { content, x in
            content.offset(x: x)
        } keyframes: { _ in
            SpringKeyframe(-7, duration: 0.08)
            SpringKeyframe(7, duration: 0.1)
            SpringKeyframe(-4, duration: 0.1)
            SpringKeyframe(0, duration: 0.14)
        }
        .position(x: hole.midX, y: hole.midY)
        .allowsHitTesting(false)
    }

    /// Globie's bubble sits on whichever side of the hole has more room.
    private func bubble(_ step: GuideStep, hole: CGRect, size: CGSize) -> some View {
        let below = hole.midY < size.height * 0.5
        let card = GuideBubble(step: step, index: guide.index, count: guide.steps.count, pointsUp: below,
                               pointerX: hole.midX,
                               next: { guide.next() },
                               skip: { Haptics.tap(); guide.stop() })
        return VStack(spacing: 0) {
            if below {
                Color.clear.frame(height: max(0, hole.maxY + 10))
                card
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                card
                Color.clear.frame(height: max(0, size.height - hole.minY + 10))
            }
        }
        .frame(width: size.width, height: size.height)
        .id(guide.index)
        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: below ? .top : .bottom)))
    }
}

/// The dim sheet: the whole screen with a rounded hole in it.
private struct SpotlightShape: Shape {
    var hole: CGRect
    var radius: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(hole.minX, hole.minY), AnimatablePair(hole.width, hole.height)) }
        set { hole = CGRect(x: newValue.first.first, y: newValue.first.second, width: newValue.second.first, height: newValue.second.second) }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        if hole.width > 0, hole.height > 0 {
            path.addRoundedRect(in: hole, cornerSize: CGSize(width: radius, height: radius), style: .continuous)
        }
        return path
    }
}

/// White card with Globie, one title, one line and the way forward.
private struct GuideBubble: View {
    var step: GuideStep
    var index: Int
    var count: Int
    /// The little pointer is on the top edge when the bubble sits under the hole.
    var pointsUp: Bool
    var pointerX: CGFloat
    var next: () -> Void
    var skip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                GlobieView(mood: step.mood, size: 46)
                    .frame(width: 50, height: 50)
                VStack(alignment: .leading, spacing: 3) {
                    Text(step.title)
                        .font(.system(size: 17, weight: .heavy))
                        .tracking(-0.3)
                        .foregroundStyle(Palette.ink)
                    Text(step.text)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                if count > 1 {
                    HStack(spacing: 5) {
                        ForEach(0..<count, id: \.self) { i in
                            Capsule()
                                .fill(i == index ? Palette.ink : Palette.surface3)
                                .frame(width: i == index ? 16 : 6, height: 6)
                        }
                    }
                }
                Spacer(minLength: 0)
                // A lone "Got it" needs no second way out.
                if count > 1 || step.advance == .tapSpot {
                    Button("Skip", action: skip)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                        .padding(.horizontal, 8)
                        .frame(height: 38)
                        .contentShape(Rectangle())
                }
                if step.advance == .next {
                    Button(step.button, action: next)
                        .buttonStyle(.pill(.primary, height: 38))
                } else {
                    HStack(spacing: 5) {
                        Image(systemName: "hand.tap.fill")
                        Text(step.action)
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.accent)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(Palette.accentSoft, in: Capsule())
                }
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .background {
            // The pointer: a small diamond half hidden behind the card's edge.
            GeometryReader { geo in
                let x = min(max(pointerX - geo.frame(in: .global).minX, 30), geo.size.width - 30)
                Rectangle()
                    .fill(.white)
                    .frame(width: 16, height: 16)
                    .rotationEffect(.degrees(45))
                    .position(x: x, y: pointsUp ? 1 : geo.size.height - 1)
            }
        }
        .shadow(color: .black.opacity(0.25), radius: 24, y: 10)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
    }
}
