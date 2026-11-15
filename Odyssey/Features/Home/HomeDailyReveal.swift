//
//  HomeDailyReveal.swift
//  Odyssey
//
//  The daily reveal. Today's Adventure stays sealed until you press and
//  hold it: a ring fills, the card trembles harder and glows brighter, and
//  at full charge it flips. When the pick is somewhere nobody on Odyssey has
//  explored yet, a rare find sequence plays first (purple flood, spinning
//  rays, a stamp) so the moment feels earned.
//  Ported from features/rewards/daily-reveal.js, reveal-hold.css and
//  daily-reveal.css.
//

import Foundation
import SwiftUI
import UIKit

struct HomeDailyReveal: View {
    @Environment(\.animationsPaused) private var animationsPaused
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var pick: HomeRevealPick?
    @State private var charge = 0.0
    @State private var holding = false
    @State private var burst = false
    @State private var burstStart: Date?
    @State private var stamped = false
    @State private var angle = 0.0
    @State private var revealed = false
    @State private var actionsShown = false
    @State private var confetti: [HomeRevealConfetti.Burst] = []
    @State private var timer: Timer?
    @State private var buzzed = 0

    var body: some View {
        ZStack {
            Color(hex: "#0b0b0c").ignoresSafeArea()
            if let pick {
                VStack(spacing: 0) {
                    head
                    cardArea(pick)
                    actions(pick).padding(.top, 22)
                }
                .padding(.horizontal, 26)
                .padding(.top, 40)
                .padding(.bottom, 24)
            }
            VStack {
                HStack {
                    Spacer()
                    IconButton(icon: "close", kind: .dark, label: "Close") { dismiss() }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            ForEach(confetti) { item in HomeRevealConfetti(burst: item).ignoresSafeArea() }
        }
        .onAppear(perform: setUp)
        .onDisappear { timer?.invalidate() }
    }

    private func setUp() {
        let current = store.dailyPick()
        pick = HomeRevealPick(place: current.place, reason: current.reason, rare: current.rare)
        if store.dailyRevealed {
            angle = 180
            revealed = true
            actionsShown = true
        }
    }

    private var head: some View {
        VStack(spacing: 2) {
            Text("Today's Adventure").font(.system(size: 11, weight: .heavy)).tracking(1.3).textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.6))
            Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(size: 24, weight: .heavy)).tracking(-0.5).foregroundStyle(.white)
        }
        .padding(.bottom, 22)
    }

    private func cardArea(_ pick: HomeRevealPick) -> some View {
        TimelineView(OdysseyMotion.schedule(paused: animationsPaused || (revealed && !burst))) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                HomeRevealRays(spin: t)
                    .opacity(burst ? 1 : 0)
                    .scaleEffect(burst ? 1 : 0.3)
                    .animation(.easeOut(duration: 0.9), value: burst)
                HomeRevealFlip(angle: angle,
                               front: HomeRevealFront(charge: charge, holding: holding, burst: burst, stamped: stamped, time: t),
                               back: HomeRevealBack(place: pick.place, reason: pick.reason, rare: pick.rare))
                    .modifier(HomeRevealMotion(time: t, charge: charge, holding: holding, revealed: revealed, burstStart: burstStart))
                    .contentShape(Rectangle())
                    .gesture(holdGesture)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in if !holding && !revealed && burstStart == nil { press() } }
            .onEnded { _ in holding = false }
    }

    /// Fill while held, drain when let go, half again as fast as it fills.
    private func press() {
        holding = true
        Haptics.soft()
        timer?.invalidate()
        buzzed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { t in
            MainActor.assumeIsolated {
                let step = (1.0 / 60) / 1.4 // 1.4 s to fill, like the mockup
                charge = max(0, min(1, charge + (holding ? step : -step * 1.5)))
                let step10 = Int(charge * 10)
                if holding && step10 > buzzed {
                    buzzed = step10
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: CGFloat(0.3 + charge * 0.7))
                }
                if charge >= 1 {
                    t.invalidate()
                    finish()
                } else if !holding && charge <= 0 {
                    t.invalidate()
                }
            }
        }
    }

    private func finish() {
        guard let pick else { return }
        holding = false
        store.revealDaily()
        Haptics.heavy()
        if pick.rare {
            withAnimation(.easeOut(duration: 0.3)) { burst = true }
            burstStart = Date()
            confetti.append(HomeRevealConfetti.Burst(originY: 0.45, count: 40, colors: ["#8a5cff", "#c4b5fd", "#f2b21b", "#ffffff"]))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { stamped = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { flip(rare: true) }
        } else {
            flip(rare: false)
        }
    }

    private func flip(rare: Bool) {
        Haptics.success()
        revealed = true
        withAnimation(.spring(response: 0.9, dampingFraction: 0.62)) { angle = 180 }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9).delay(0.6)) { actionsShown = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            let colors = rare ? ["#8a5cff", "#f2b21b", "#ffffff", "#2b59ff"]
                : ["#2b59ff", "#f2b21b", "#ff6a2b", "#17a35a", "#8a5cff", "#ffffff"]
            confetti.append(HomeRevealConfetti.Burst(originY: 0.35, count: 80, colors: colors))
        }
    }

    private func actions(_ pick: HomeRevealPick) -> some View {
        VStack(spacing: 8) {
            Button {
                LiveActivityService.shared.start(place: pick.place, store: store)
                NearbyService.directions(to: pick.place)
            } label: {
                Label(pick.rare ? "Go be first" : "Let's go", systemImage: "location.north.fill")
            }
            .buttonStyle(.pill(.light, fill: true))
            HStack(spacing: 8) {
                Button("View place") {
                    dismiss()
                    let id = pick.place.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { router.push(.place(id)) }
                }
                .buttonStyle(.pill(.glass, fill: true))
                ShareLink(item: "Today's adventure on Odyssey: \(pick.place.name) pathy.app/p/\(pick.place.id)") {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.pill(.glass, fill: true))
            }
        }
        .opacity(actionsShown ? 1 : 0)
        .offset(y: actionsShown ? 0 : 14)
        .allowsHitTesting(actionsShown)
    }
}

/// Today's pick, held for the life of the screen so a check-in cannot swap it.
struct HomeRevealPick {
    var place: Place
    var reason: String
    var rare: Bool
}
