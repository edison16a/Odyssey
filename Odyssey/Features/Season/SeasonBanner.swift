//
//  SeasonBanner.swift
//  Odyssey
//
//  The Winter Wonderland section: a night scene with snow and the last
//  leaves drifting down, string lights along the top, the event goal and a
//  row of seasonal quest cards. Ported from features/season/season-banner.js
//  and season.css.
//

import Foundation
import SwiftUI

struct SeasonBanner: View {
    @Environment(AppStore.self) private var store
    var onOpen: (SeasonQuest) -> Void

    var body: some View {
        let season = store.extras.season
        let won = store.state.seasonDone.count >= season.goal
        ZStack(alignment: .top) {
            Color(hex: "#0d1b33")
            SeasonFlurry(count: 26)
            SeasonLights().frame(height: 24)
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Label("Seasonal event, " + season.ends, systemImage: "snowflake")
                        .font(.system(size: 10.5, weight: .heavy)).tracking(1).textCase(.uppercase)
                        .foregroundStyle(Color(hex: "#bae6fd"))
                    Text(season.name).font(.system(size: 26, weight: .black)).tracking(-0.8)
                        .padding(.top, 2).padding(.bottom, 4)
                    HStack(spacing: 4) {
                        Text(won ? "Unlocked" : "Finish any 1 for the exclusive title").font(.system(size: 13))
                        ProfileTitleText(id: season.reward.title, text: titleName(season.reward.title), size: 15)
                    }
                    .opacity(0.9)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(season.quests) { quest in
                            SeasonQuestCard(quest: quest, done: store.seasonDone(quest.id)) { onOpen(quest) }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 26)
            .padding(.bottom, 14)
            .foregroundStyle(.white)
        }
        .overlay(alignment: .bottom) {
            Ellipse().fill(Color(hex: "#e8f4ff").opacity(0.12)).frame(height: 52).offset(y: 26)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous).strokeBorder(Color(hex: "#bae6fd").opacity(0.25), lineWidth: 1))
    }

    private func titleName(_ id: String) -> String {
        store.seed.titles.first { $0.id == id }?.name ?? id
    }
}

/// One seasonal quest: a glowing tile in its color, the title and its coins.
struct SeasonQuestCard: View {
    var quest: SeasonQuest
    var done: Bool
    var action: () -> Void

    var body: some View {
        let color = Color(hex: quest.color)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: Icon.symbol(done ? "check" : quest.glyph))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: color, radius: 9)
                Text(quest.title).font(.system(size: 13, weight: .bold)).lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: 34, alignment: .topLeading)
                if done {
                    Text("Done").font(.system(size: 11))
                } else {
                    HStack(spacing: 4) {
                        CoinIcon(size: 12)
                        Text(Format.number(quest.coins)).font(.system(size: 11, weight: .semibold))
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(12)
            .frame(width: 128, alignment: .leading)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(done ? Color(hex: "#6ee7a8") : Color(hex: "#bae6fd").opacity(0.3), lineWidth: done ? 2 : 1))
        }
        .buttonStyle(PressStyle())
    }
}

/// Snowflakes with a leaf every seventh, falling with staggered, fixed timing.
struct SeasonFlurry: View {
    @Environment(\.animationsPaused) private var animationsPaused
    var count: Int

    var body: some View {
        TimelineView(OdysseyMotion.schedule(paused: animationsPaused)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<count {
                    let leaf = i % 7 == 3
                    let left = Double((i * 37) % 100) / 100
                    let duration = Double(5 + (i * 13) % 6)
                    let delay = -Double((i * 7) % 10)
                    let flake: Double = leaf ? 9 : 3 + Double(i % 3) * 1.5
                    let k = GlobieArt.cycle(t, duration, delay)
                    // w-fall: down 120 and right 14 by half way, down 260 and left 6 at the end, one full turn.
                    let dx: Double = k < 0.5 ? 14 * (k / 0.5) : 14 - 20 * ((k - 0.5) / 0.5)
                    let dy: Double = k < 0.5 ? 120 * (k / 0.5) : 120 + 140 * ((k - 0.5) / 0.5)
                    var piece = context
                    piece.translateBy(x: CGFloat(left * Double(size.width) + dx), y: CGFloat(-12 + dy))
                    piece.rotate(by: .degrees(360 * k))
                    let rect = CGRect(x: -flake / 2, y: -flake / 2, width: flake, height: flake)
                    if leaf {
                        piece.opacity = 0.9
                        piece.fill(SeasonFlurry.leafPath(rect), with: .color(Color(hex: "#f59e0b")))
                    } else {
                        piece.opacity = 0.85
                        piece.fill(Path(ellipseIn: rect), with: .color(.white))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// border-radius: 0 60% 0 60%, a simple leaf.
    static func leafPath(_ r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.maxX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY), control: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// Fourteen bulbs on a sagging wire, twinkling out of step.
struct SeasonLights: View {
    @Environment(\.animationsPaused) private var animationsPaused
    private let colors = ["#ff6a6a", "#ffd76a", "#6ee7a8", "#7aa2ff"]

    var body: some View {
        TimelineView(OdysseyMotion.schedule(paused: animationsPaused)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let sx = Double(size.width) / 340
                let sy = Double(size.height) / 30
                var wire = Path()
                wire.move(to: CGPoint(x: 0, y: 4 * sy))
                wire.addQuadCurve(to: CGPoint(x: 170 * sx, y: 6 * sy), control: CGPoint(x: 85 * sx, y: 28 * sy))
                wire.addQuadCurve(to: CGPoint(x: 340 * sx, y: 4 * sy), control: CGPoint(x: 255 * sx, y: -16 * sy))
                context.stroke(wire, with: .color(Color(hex: "#2a3a2a")), lineWidth: 1.5)
                for i in 0..<14 {
                    let x = 12 + Double(i) * 23
                    let y = 6 + sin(x / 340 * Double.pi * 2) * -8 + 8
                    let period = 1.2 + Double(i % 3) * 0.4
                    var bulb = context
                    bulb.opacity = 1 - 0.7 * GlobieArt.wave(t, period, -Double(i) * 0.15)
                    let r = 3.2
                    bulb.fill(Path(ellipseIn: CGRect(x: x * sx - r, y: y * sy - r, width: r * 2, height: r * 2)),
                              with: .color(Color(hex: colors[i % 4])))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
