//
//  HomeHoldReveal.swift
//  Odyssey
//
//  Today's Adventure, sealed. Press and hold: a ring fills around the
//  sparkle, the card shakes harder and harder while sparks are pulled in
//  toward the middle, and the phone ticks faster. Hold to the end and it
//  bursts: a flash, sparks flung out, then the place. Let go early and it
//  settles back down.
//

import Foundation
import SwiftUI

struct HomeHoldReveal: View {
    var place: Place
    var onReveal: () -> Void

    /// How long to hold before it opens.
    private static let holdSeconds = 1.3

    @State private var holdStart: Date?
    @State private var burstStart: Date?
    @State private var ticker: Task<Void, Never>?
    @State private var idle = false

    var body: some View {
        TimelineView(.animation(paused: holdStart == nil && burstStart == nil)) { timeline in
            let now = timeline.date
            let p = progress(at: now)
            let burst = burstStart.map { now.timeIntervalSince($0) } ?? -1
            card(progress: p, burst: burst, now: now)
                .offset(x: shake(p, now: now, axis: 0), y: shake(p, now: now, axis: 1))
                .rotationEffect(.degrees(shake(p, now: now, axis: 2) * 0.25))
                .scaleEffect(burst >= 0 ? 1 + 0.04 * min(1, burst / 0.2) : 1 - 0.02 * p)
        }
        .frame(height: 316)
        .frame(maxWidth: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .onLongPressGesture(minimumDuration: Self.holdSeconds, maximumDistance: 60) {
            burst()
        } onPressingChanged: { pressing in
            guard burstStart == nil else { return }
            if pressing { begin() } else { cancel() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today's Adventure. Press and hold to reveal")
        .accessibilityAction { burst() }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { idle = true }
        }
        .onDisappear { ticker?.cancel() }
    }

    // MARK: Drawing

    private func card(progress p: Double, burst: Double, now: Date) -> some View {
        ZStack {
            PlacePhoto(place: place)
                .blur(radius: 28 - 10 * p)
                .scaleEffect(1.2)
                .overlay(Color.black.opacity(0.55 - 0.15 * p))
            HoldRevealParticles(progress: p, burst: burst, now: now)
            VStack(spacing: 14) {
                ZStack {
                    Circle().strokeBorder(.white.opacity(0.25), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: p)
                        .stroke(Palette.gold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: Palette.gold.opacity(0.8), radius: 6 * p)
                    Image(systemName: "sparkles")
                        .font(.system(size: 26 + 8 * p, weight: .semibold))
                        .rotationEffect(.degrees(p * 25))
                }
                .frame(width: 64, height: 64)
                .background(.white.opacity(0.14 + 0.2 * p), in: Circle())
                .scaleEffect((idle && p == 0 ? 1.06 : 1) + 0.25 * p)
                VStack(spacing: 6) {
                    Text("Today's Adventure").font(.system(size: 24, weight: .heavy)).tracking(-0.5)
                    Text("A new place picked for your taste, every day.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.75))
                }
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill").font(.system(size: 13, weight: .bold))
                    Text(p > 0 ? "Keep holding…" : "Hold to reveal")
                        .font(.system(size: 15, weight: .bold))
                        .contentTransition(.opacity)
                }
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 22)
                .frame(height: 44)
                .background {
                    // The pill fills with gold as you hold.
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white)
                            Capsule().fill(Palette.gold).frame(width: geo.size.width * p)
                        }
                    }
                }
                .clipShape(Capsule())
                .padding(.top, 4)
            }
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(20)
            .opacity(burst >= 0 ? max(0, 1 - burst / 0.15) : 1)
            // The flash as it opens.
            Color.white.opacity(burst >= 0 ? max(0, 0.9 - burst * 2.2) : 0.12 * p * p)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .shadow(color: (p > 0 ? Palette.gold : .black).opacity(0.12 + 0.35 * p), radius: 16 + 14 * p, y: 8)
    }

    /// Shake that grows with the hold: small and slow at first, sharp near the end.
    private func shake(_ p: Double, now: Date, axis: Int) -> Double {
        guard p > 0, burstStart == nil else { return 0 }
        let t = now.timeIntervalSinceReferenceDate
        let amp = 7 * pow(p, 1.6)
        let speed = 30 + 40 * p
        switch axis {
        case 0: return amp * sin(t * speed)
        case 1: return amp * 0.6 * cos(t * speed * 1.3)
        default: return amp * sin(t * speed * 0.8)
        }
    }

    private func progress(at now: Date) -> Double {
        if burstStart != nil { return 1 }
        guard let holdStart else { return 0 }
        return min(1, now.timeIntervalSince(holdStart) / Self.holdSeconds)
    }

    // MARK: Hold

    private func begin() {
        holdStart = Date()
        Haptics.soft()
        ticker?.cancel()
        // Ticks that speed up the longer you hold.
        ticker = Task { @MainActor in
            var gap = 0.22
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(gap))
                guard !Task.isCancelled, holdStart != nil else { return }
                Haptics.tap()
                gap = max(0.05, gap * 0.8)
            }
        }
    }

    private func cancel() {
        ticker?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { holdStart = nil }
    }

    private func burst() {
        guard burstStart == nil else { return }
        ticker?.cancel()
        burstStart = Date()
        Haptics.heavy()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { Haptics.success() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { onReveal() }
    }
}

/// Gold and white sparks: drawn in toward the middle while you hold, flung out at the burst.
struct HoldRevealParticles: View {
    var progress: Double
    var burst: Double
    var now: Date

    private static let count = 36

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2 - 40)
            let t = now.timeIntervalSinceReferenceDate
            var glow = ctx
            glow.addFilter(.shadow(color: Palette.gold, radius: 5))
            for i in 0..<Self.count {
                let seed = Double((i * 7919) % 1000) / 1000
                let angle = Double(i) / Double(Self.count) * 2 * .pi + seed * 0.6
                let reach = 120 + 110 * seed
                var distance: Double
                var opacity: Double
                var radius = 1.5 + 2.5 * seed
                if burst >= 0 {
                    let p = min(1, burst / 0.6)
                    let eased = 1 - pow(1 - p, 3)
                    distance = 20 + (reach * 1.9) * eased
                    opacity = 1 - p
                    radius *= 1.6 - 0.8 * p
                } else {
                    guard progress > 0 else { continue }
                    // Each spark loops inward; faster the longer you hold.
                    let cycle = (t * (0.8 + 1.8 * progress) + seed).truncatingRemainder(dividingBy: 1)
                    distance = reach * (1 - cycle) + 18
                    opacity = min(1, progress * 2) * sin(cycle * .pi)
                }
                let point = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)
                let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                glow.opacity = max(0, opacity)
                glow.fill(Path(ellipseIn: rect), with: .color(i % 3 == 0 ? .white : Palette.gold))
            }
        }
        .allowsHitTesting(false)
    }
}
