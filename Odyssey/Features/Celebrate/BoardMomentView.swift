//
//  BoardMomentView.swift
//  Odyssey
//
//  The leaderboard moment, shown after a check-in carries you into the top
//  100 or the top 10 of a board. A laurel wreath draws itself in around
//  your position while the number counts down from where you were, gold
//  sparks rise behind it, and the badge, frame and banner you just earned
//  land underneath.
//

import Foundation
import SwiftUI

struct BoardMomentView: View {
    @Environment(AppStore.self) private var store
    var moment: BoardMoment
    var close: () -> Void
    var openBoard: () -> Void

    @State private var shown: Int
    @State private var appeared = false
    @State private var rewards = false

    init(moment: BoardMoment, close: @escaping () -> Void, openBoard: @escaping () -> Void) {
        self.moment = moment
        self.close = close
        self.openBoard = openBoard
        _shown = State(initialValue: moment.previous)
    }

    private var gold: Bool { moment.top == 10 }
    private var main: Color { gold ? Color(hex: "#f2b21b") : Color(hex: "#c9ced6") }

    var body: some View {
        ZStack {
            Color(hex: gold ? "#141019" : "#0f1730").ignoresSafeArea()
            BoardSparks(color: main).ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer(minLength: 16)
                wreath
                Text("You're in the Top \(moment.top)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded)).tracking(-0.6)
                    .padding(.top, 6)
                Text("of \(moment.scopeLabel)")
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(main)
                Text("Up from number \(Format.number(Double(moment.previous))). Your laurel now shows on your profile.")
                    .font(.system(size: 14)).opacity(0.7).multilineTextAlignment(.center).padding(.top, 8)
                rewardRow.padding(.top, 22)
                Spacer(minLength: 16)
                buttons
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .opacity(appeared ? 1 : 0)
            if rewards { ConfettiView(count: 60).ignoresSafeArea() }
        }
        .foregroundStyle(.white)
        .task { await play() }
    }

    private var wreath: some View {
        ZStack {
            Circle().fill(main.opacity(0.12)).frame(width: 230, height: 230).blur(radius: 20)
            LaurelWreath(color: main, duration: 1.5, delay: 0.25).frame(width: 250, height: 250)
            VStack(spacing: 0) {
                Text("#").font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundStyle(main)
                Text("\(shown)")
                    .font(.system(size: 84, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(width: 150)
            }
            Image(systemName: "crown.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(main)
                .offset(y: -132)
                .opacity(gold && rewards ? 1 : 0)
                .scaleEffect(rewards ? 1 : 0.3)
        }
        .frame(height: 280)
    }

    private var rewardRow: some View {
        HStack(spacing: 10) {
            reward(title: gold ? "Top 10 badge" : "Top 100 badge") {
                Image(systemName: gold ? "crown.fill" : "trophy.fill")
                    .font(.system(size: 22, weight: .bold)).foregroundStyle(gold ? Palette.ink : .white)
                    .frame(width: 48, height: 48).background(main, in: Circle())
            }
            reward(title: gold ? "Golden Laurel" : "Silver Laurel") {
                AvatarView(person: store.me, size: 40, frame: gold ? "laurel-gold" : "laurel-silver").frame(width: 56, height: 56)
            }
            reward(title: gold ? "Top 10 banner" : "Top 100 banner") {
                ProfileBannerView(id: gold ? "board-top-10" : "board-top-100", showLabel: false, animated: false)
                    .frame(width: 64, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .opacity(rewards ? 1 : 0)
        .offset(y: rewards ? 0 : 16)
    }

    private func reward<Art: View>(title: String, @ViewBuilder art: () -> Art) -> some View {
        VStack(spacing: 8) {
            art().frame(height: 58)
            Text(title).font(.system(size: 11, weight: .bold)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            ShareLink(item: "I'm number \(moment.position) in \(moment.scopeLabel) on Odyssey. Go Explore. Get Rewarded.") {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.pill(.glass, fill: true))
            HStack(spacing: 10) {
                Button("See the board", action: openBoard).buttonStyle(.pill(.glass, fill: true))
                Button("Continue", action: close).buttonStyle(.pill(.light, fill: true))
            }
        }
        .opacity(rewards ? 1 : 0)
    }

    /// Fade in, count down to the new position while the wreath grows, then show the rewards.
    private func play() async {
        withAnimation(.easeOut(duration: 0.35)) { appeared = true }
        try? await Task.sleep(for: .seconds(0.45))
        let steps = 22
        for i in 1...steps {
            let f = 1 - pow(1 - Double(i) / Double(steps), 2.4)
            let value = Int((Double(moment.previous) + Double(moment.position - moment.previous) * f).rounded())
            withAnimation(.snappy(duration: 0.12)) { shown = value }
            if i % 4 == 0 { Haptics.tap() }
            try? await Task.sleep(for: .seconds(0.055))
        }
        shown = moment.position
        Haptics.success()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { rewards = true }
    }
}

/// Small sparks drifting up, like embers, in the moment's metal color.
private struct BoardSparks: View {
    @Environment(\.animationsPaused) private var animationsPaused
    var color: Color
    private static let seeds: [(x: Double, speed: Double, size: Double, phase: Double)] = (0..<44).map { i in
        let r = StableHash.generator("spark\(i)")
        return (r(), 0.05 + r() * 0.09, 1.2 + r() * 2.4, r())
    }

    var body: some View {
        TimelineView(OdysseyMotion.schedule(paused: animationsPaused)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for s in BoardSparks.seeds {
                    let y = 1 - (s.phase + t * s.speed).truncatingRemainder(dividingBy: 1)
                    let x = s.x + sin(t * 0.8 + s.phase * 6) * 0.02
                    var spark = context
                    spark.opacity = min(1, y * 2) * 0.8
                    spark.fill(Path(ellipseIn: CGRect(x: x * size.width, y: y * size.height, width: s.size, height: s.size)),
                               with: .color(color))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
