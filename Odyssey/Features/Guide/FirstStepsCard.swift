//
//  FirstStepsCard.swift
//  Odyssey
//
//  The card at the top of Home for a new explorer: four first steps, the
//  one to do next, and a welcome bonus when all four are done. Tapping it
//  does not explain the step, it takes you there and lights up the button.
//

import Foundation
import SwiftUI

struct FirstStepsCard: View {
    @Environment(AppStore.self) private var store
    @Environment(Guide.self) private var guide
    @Environment(RewardPopCenter.self) private var rewardPop
    @State private var shine = false

    var body: some View {
        let next = store.nextFirstStep
        let done = store.firstStepsDone
        let total = FirstStep.allCases.count
        Button { act(next) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Text(next == nil ? "FIRST STEPS DONE" : "FIRST STEPS · \(done) OF \(total)")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    HStack(spacing: 4) {
                        CoinIcon(size: 14)
                        Text("+\(AppStore.welcomeBonus)").font(.system(size: 12, weight: .heavy)).monospacedDigit()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(.white.opacity(0.14), in: Capsule())
                }
                HStack(spacing: 12) {
                    GlobieView(mood: next == nil ? .ecstatic : .happy, size: 46)
                        .frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(next?.title ?? "You did it!")
                            .font(.system(size: 17, weight: .heavy))
                            .tracking(-0.3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(next?.detail ?? "Your welcome bonus is ready.")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 4)
                    if next == nil {
                        Text("Claim")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 16)
                            .frame(height: 38)
                            .background(Palette.gold, in: Capsule())
                            .scaleEffect(shine ? 1.06 : 1)
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 38, height: 38)
                            .background(.white, in: Circle())
                            .offset(x: shine ? 3 : 0)
                    }
                }
                HStack(spacing: 5) {
                    ForEach(FirstStep.allCases) { step in
                        Capsule()
                            .fill(store.firstStepDone(step) ? Palette.success : .white.opacity(step == next ? 0.5 : 0.18))
                            .frame(height: 5)
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: done)
            }
            .foregroundStyle(.white)
            .padding(14)
            .background(Palette.ink, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
        .buttonStyle(PressStyle(scale: 0.98))
        .contextMenu {
            Button("Hide first steps", systemImage: "eye.slash") {
                withAnimation(.easeOut(duration: 0.25)) { store.hideFirstSteps() }
            }
        }
        .accessibilityLabel(next.map { "First steps, \(done) of \(total) done. Next: \($0.title)" } ?? "First steps done. Claim your welcome bonus")
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { shine = true }
        }
    }

    /// Take the explorer to the step and point at what to press.
    private func act(_ step: FirstStep?) {
        Haptics.tap()
        guard let step else { return claim() }
        switch step {
        case .tour: guide.startWelcome(store: store)
        case .save: guide.startExplore()
        case .checkIn: guide.startCheckIn(store: store)
        case .friend: guide.startFriend()
        }
    }

    private func claim() {
        var coins = 0
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { coins = store.claimFirstSteps() }
        guard coins > 0 else { return }
        rewardPop.show(RewardPopModel(
            icon: "trophy", color: "#f2b21b", eyebrow: "First steps complete",
            title: "You are an explorer now",
            sub: "One check-in a day keeps your streak alive.",
            stats: [.init(glyph: "coin", label: "Welcome bonus", value: "+\(coins)", color: "#f2b21b")],
            done: "Let's go"))
    }
}
