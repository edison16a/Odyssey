//
//  StreakPowerUp.swift
//  Odyssey
//
//  The streak power up. The first check-in of the day opens this full
//  screen moment before Adventure Complete: energy gathers into Globie, a
//  charge ring fills, then it bursts and the day count flips up. On a
//  milestone Globie transforms into its next form in a flash, and only
//  after "Awesome" does a second step show what it unlocked.
//  Ported from features/streak/power-up.js.
//

import Foundation
import SwiftUI

struct StreakPowerUpView: View {
    @Environment(AppStore.self) private var store
    var days: Int
    var milestone: StreakTier?
    /// Previews show the moment without equipping anything.
    var canEquip = true
    var onFinish: () -> Void

    private enum Phase { case idle, charging, burst, done }
    @State private var phase: Phase = .idle
    @State private var shownDays = 0
    @State private var chargeStart = Date()
    @State private var burstStart = Date.distantFuture
    @State private var shake = false
    @State private var showUnlock = false
    /// Once the burst has played out, the particle and shockwave clocks stop.
    @State private var settled = false

    private var now: StreakTier { StreakTiers.tier(for: days) }
    private var before: StreakTier { StreakTiers.tier(for: max(0, days - 1)) }
    private var next: StreakTier? { StreakTiers.next(after: days) }
    private var progress: Double {
        guard let next else { return 1 }
        return Double(days - now.days) / Double(max(1, next.days - now.days))
    }
    private var burst: Bool { phase == .burst || phase == .done }

    var body: some View {
        ZStack {
            now.background.ignoresSafeArea()
            VStack(spacing: 0) {
                stage.padding(.top, milestone == nil ? 70 : 34)
                count.padding(.top, milestone == nil ? 18 : 8)
                text
                Spacer()
                actions
            }
            if burst { ConfettiView(count: milestone == nil ? 60 : 140).ignoresSafeArea() }
            if showUnlock, let milestone {
                StreakPowerUnlock(tier: milestone, canEquip: canEquip, onFinish: onFinish)
                    .transition(.opacity)
            }
        }
        .foregroundStyle(.white)
        .task { await run() }
    }

    /// The timeline: charge for 1.5 seconds, burst, then settle.
    private func run() async {
        shownDays = max(0, days - 1)
        try? await Task.sleep(for: .milliseconds(60))
        chargeStart = Date()
        withAnimation(.timingCurve(0.5, 0, 0.3, 1, duration: 1.4)) { phase = .charging }
        shake = true
        Haptics.soft()
        try? await Task.sleep(for: .milliseconds(1500))
        burstStart = Date()
        Haptics.heavy()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            phase = .burst
            shownDays = days
        }
        try? await Task.sleep(for: .milliseconds(700))
        withAnimation(.easeOut(duration: 0.5)) { phase = .done }
        Haptics.success()
        // The last particle lands about 1.3 seconds after the burst.
        try? await Task.sleep(for: .milliseconds(800))
        settled = true
    }

    private var stage: some View {
        ZStack {
            Circle()
                .fill(now.color)
                .frame(width: 360, height: 360)
                .blur(radius: 70)
                .opacity(burst ? 0.42 : 0.18)
                .animation(.easeOut(duration: 0.6), value: burst)
            StreakPowerParticles(tier: now, chargeStart: chargeStart, burstStart: burstStart, charging: phase != .idle, finished: settled)
                .frame(width: 420, height: 420)
            Circle().stroke(.white.opacity(0.1), lineWidth: 5).frame(width: 208, height: 208)
                .opacity(burst ? 0 : 1)
            Circle()
                .trim(from: 0, to: phase == .idle ? 0 : 1)
                .stroke(now.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 208, height: 208)
                .rotationEffect(.degrees(-90))
                .shadow(color: now.color, radius: 6)
                .scaleEffect(burst ? 1.3 : 1)
                .opacity(burst ? 0 : 1)
            GlobieView(mood: .happy, form: before.id, size: 168)
                .scaleEffect(burst ? 1.4 : 0.82)
                .opacity(burst ? 0 : 0.85)
                .offset(x: phase == .charging && shake ? 1.5 : 0, y: phase == .charging && shake ? -1 : 0)
                .animation(phase == .charging ? .linear(duration: 0.06).repeatForever(autoreverses: true) : .easeOut(duration: 0.25), value: shake)
            GlobieView(mood: milestone == nil ? .happy : .ecstatic, form: now.id, size: 168)
                .scaleEffect(burst ? 1.12 : 0.6)
                .opacity(burst ? 1 : 0)
            StreakShockwave(start: burstStart, color: now.color, finished: settled)
        }
        .frame(width: 220, height: 220)
    }

    private var count: some View {
        Text("\(shownDays)")
            .font(.system(size: 76, weight: .heavy))
            .tracking(-3.5)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(shownDays)))
            .frame(height: 76)
    }

    private var text: some View {
        VStack(spacing: 16) {
            Text(milestone?.name ?? "Streak powered up!")
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.9)
                .multilineTextAlignment(.center)
            if milestone == nil, next != nil {
                ProgressBar(value: progress, color: now.color, track: .white.opacity(0.14), height: 6)
                    .frame(maxWidth: 200)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 10)
        .opacity(phase == .done ? 1 : 0)
        .offset(y: phase == .done ? 0 : 14)
    }

    private var actions: some View {
        Button(milestone == nil ? "Continue" : "Awesome") {
            if milestone == nil {
                onFinish()
            } else {
                withAnimation(.easeOut(duration: 0.4)) { showUnlock = true }
            }
        }
        .buttonStyle(.pill(.light, fill: true))
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .opacity(phase == .done ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(0.3), value: phase == .done)
        .allowsHitTesting(phase == .done)
    }

}

/// The white flash and the ring that grows out from Globie once, right at the burst.
private struct StreakShockwave: View {
    @Environment(\.animationsPaused) private var animationsPaused
    var start: Date
    var color: Color
    var finished = false

    var body: some View {
        TimelineView(OdysseyMotion.schedule(paused: animationsPaused || finished)) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            let wave = min(1, max(0, t / 0.9))
            let flash = min(1, max(0, t / 0.6))
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 300, height: 300)
                    .scaleEffect(0.4 + 0.9 * flash)
                    .opacity(t < 0 || t > 0.6 ? 0 : 0.9 * (1 - flash))
                Circle()
                    .stroke(color, lineWidth: 3)
                    .frame(width: 220, height: 220)
                    .scaleEffect(0.8 + 1.6 * wave)
                    .opacity(t < 0 || t > 0.9 ? 0 : 1 - wave)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Standalone cover that plays the power up for a streak value without changing anything.
struct PowerUpPreview: View {
    @Environment(AppRouter.self) private var router
    var days: Int

    var body: some View {
        StreakPowerUpView(days: days,
                          milestone: StreakTiers.all.first { $0.days == days && $0.days > 0 },
                          canEquip: false) { router.dismissCover() }
    }
}
