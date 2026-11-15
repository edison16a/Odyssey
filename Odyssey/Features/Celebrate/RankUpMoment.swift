//
//  RankUpMoment.swift
//  Odyssey
//
//  The rank up screen. It fills the screen in the new tier's color: the
//  old emblem shrinks away in a flash, the new one lands with a spring
//  inside a ring of light, slow rays turn behind it and confetti falls.
//  Then the name, the climb from the old rank, what the new rank unlocks
//  and a share button rise in.
//

import Foundation
import SwiftUI

struct RankUpMoment: View {
    var before: RankInfo
    var after: RankInfo
    var close: () -> Void

    /// 0 old emblem, 1 flash, 2 new emblem, 3 details.
    @State private var stage = 0
    @State private var ring = false

    private var tint: Color { Color(hex: after.current.color) }

    var body: some View {
        ZStack {
            tint.ignoresSafeArea()
            Color.black.opacity(0.28).ignoresSafeArea()
            RankRays(color: .white).opacity(stage >= 2 ? 0.12 : 0).ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer(minLength: 20)
                emblem.frame(height: 240)
                details.padding(.top, 8)
                Spacer(minLength: 20)
                buttons
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            if stage >= 2 { ConfettiView(count: 90).ignoresSafeArea() }
            Color.white.opacity(stage == 1 ? 0.55 : 0).ignoresSafeArea().allowsHitTesting(false)
        }
        .foregroundStyle(.white)
        .task { await play() }
    }

    private var emblem: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(ring ? 0 : 0.6), lineWidth: 3)
                .frame(width: 150, height: 150)
                .scaleEffect(ring ? 2.1 : 0.7)
            Circle()
                .fill(.white.opacity(0.14))
                .frame(width: 196, height: 196)
                .scaleEffect(stage >= 2 ? 1 : 0.4)
            Circle()
                .fill(.white)
                .frame(width: 164, height: 164)
                .shadow(color: .black.opacity(0.25), radius: 24, y: 14)
                .scaleEffect(stage >= 2 ? 1 : 0.3)
                .opacity(stage >= 2 ? 1 : 0)
            RankEmblem(tier: before.tier, size: 120, inverse: true)
                .scaleEffect(stage == 0 ? 1 : 0.2)
                .opacity(stage == 0 ? 1 : 0)
            RankEmblem(tier: after.tier, size: 132)
                .scaleEffect(stage >= 2 ? 1 : 0.2)
                .rotationEffect(.degrees(stage >= 2 ? 0 : -25))
                .opacity(stage >= 2 ? 1 : 0)
        }
    }

    private var details: some View {
        VStack(spacing: 6) {
            Text("Rank up").font(.system(size: 12, weight: .heavy)).tracking(2).textCase(.uppercase).opacity(0.85)
            Text(after.current.name).font(.system(size: 44, weight: .heavy, design: .rounded)).tracking(-1)
            HStack(spacing: 8) {
                RankEmblem(tier: before.tier, size: 20, inverse: true)
                Text("\(before.current.name) to \(after.current.name)").font(.system(size: 14, weight: .semibold))
                RankEmblem(tier: after.tier, size: 20, inverse: true)
            }
            .opacity(0.9)
            VStack(alignment: .leading, spacing: 12) {
                Text("Unlocked").font(.system(size: 11, weight: .bold)).tracking(1).textCase(.uppercase).opacity(0.7)
                perk("sparkles", after.current.perk)
                perk("person.crop.circle", "Your new \(after.current.name) emblem on your profile and posts")
                if let next = after.next { perk("arrow.up.right", "\(next.xp - after.xp) XP to \(next.name)") }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.top, 18)
        }
        .multilineTextAlignment(.center)
        .opacity(stage >= 3 ? 1 : 0)
        .offset(y: stage >= 3 ? 0 : 18)
    }

    private func perk(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).font(.system(size: 14, weight: .bold)).frame(width: 20)
            Text(text).font(.system(size: 15, weight: .semibold)).multilineTextAlignment(.leading)
        }
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            ShareLink(item: "I just ranked up to \(after.current.name) on Odyssey. Go Explore. Get Rewarded.") {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.pill(.glass, fill: true))
            Button("Continue", action: close).buttonStyle(.pill(.light, fill: true))
        }
        .opacity(stage >= 3 ? 1 : 0)
    }

    private func play() async {
        try? await Task.sleep(for: .seconds(0.7))
        withAnimation(.easeIn(duration: 0.18)) { stage = 1 }
        Haptics.success()
        try? await Task.sleep(for: .seconds(0.18))
        withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) { stage = 2 }
        withAnimation(.easeOut(duration: 1.1)) { ring = true }
        try? await Task.sleep(for: .seconds(0.6))
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.6)) { stage = 3 }
    }
}

/// Soft light rays turning slowly behind a reveal.
struct RankRays: View {
    @Environment(\.animationsPaused) private var animationsPaused
    var color: Color
    var count = 14

    var body: some View {
        TimelineView(OdysseyMotion.schedule(paused: animationsPaused)) { timeline in
            Canvas { context, size in
                let c = CGPoint(x: size.width / 2, y: size.height * 0.36)
                let reach = max(size.width, size.height)
                let turn = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 120) / 120 * 2 * .pi
                for i in 0..<count {
                    let a = Double(i) / Double(count) * 2 * .pi + turn
                    var ray = Path()
                    ray.move(to: c)
                    ray.addLine(to: CGPoint(x: c.x + reach * cos(a - 0.07), y: c.y + reach * sin(a - 0.07)))
                    ray.addLine(to: CGPoint(x: c.x + reach * cos(a + 0.07), y: c.y + reach * sin(a + 0.07)))
                    ray.closeSubpath()
                    context.fill(ray, with: .color(color))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
