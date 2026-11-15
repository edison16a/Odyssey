//
//  RewardPop.swift
//  Odyssey
//
//  The congrats pop: a centered card with a burst, the headline, a few
//  stat lines ("+5 coins", "Top 4% in Berkeley") and a share button, shown
//  after small wins so every action feels like it counted. The two reward
//  moments from the mockup (a new friend, a posted story) live here too.
//  Ported from features/rewards/reward-pop.js and moments.js.
//

import Foundation
import Observation
import SwiftUI

struct RewardPopModel: Identifiable {
    struct Stat: Hashable {
        var glyph: String
        var label: String
        var value: String
        var color: String?
    }

    let id = UUID()
    var icon: String = "star"
    var person: Person? = nil
    var color: String = "#2b59ff"
    var eyebrow: String? = nil
    var title: String = "Nice work"
    var sub: String? = nil
    var stats: [Stat] = []
    /// When set, a share button offers this text.
    var shareLabel: String? = nil
    var shareText: String? = nil
    var done: String = "Awesome"
}

@Observable
final class RewardPopCenter {
    var current: RewardPopModel?

    func show(_ model: RewardPopModel) {
        Haptics.success()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { current = model }
    }

    func dismiss() {
        withAnimation(.easeOut(duration: 0.24)) { current = nil }
    }

    /// A new friend: +5 coins and a nudge to explore together.
    func friendAdded(_ id: String, store: AppStore) {
        guard let friend = store.person(id) else { return }
        store.earn(5)
        show(RewardPopModel(
            person: friend, color: "#17a35a", eyebrow: "New exploring partner",
            title: "You and \(friend.firstName) are friends",
            sub: "Check in somewhere together and you both earn 2x coins.",
            stats: [.init(glyph: "coin", label: "Friend bonus", value: "+5"),
                    .init(glyph: "users", label: "Friends", value: "\(store.state.stats.friends)", color: "#17a35a")],
            shareLabel: "Invite more friends",
            shareText: "Explore with me on Odyssey: pathy.app/pair/\(store.state.user.handle)"))
    }

    /// A story is live in your friends' row.
    func storyPosted(_ place: Place, store: AppStore) {
        let best = store.bestStanding
        show(RewardPopModel(
            icon: "send", color: "#8a5cff", eyebrow: "Your adventure is live",
            title: "Posted to your adventure",
            sub: "\(place.name) is now first in your friends' row.",
            stats: [.init(glyph: "trophy", label: "\(best.scope.label) standing", value: "Top \(Format.pctText(best.pct))%", color: "#f2b21b")],
            shareLabel: "Share to other apps",
            shareText: "My adventure at \(place.name) on Odyssey: pathy.app/s/\(place.id)"))
    }
}

/// Draws the current pop above everything, with a dimmed backdrop.
struct RewardPopOverlay: View {
    @Environment(RewardPopCenter.self) private var center

    var body: some View {
        ZStack {
            if let pop = center.current {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { center.dismiss() }
                    .transition(.opacity)
                RewardPopCard(pop: pop, close: { center.dismiss() })
                    .padding(.horizontal, 28)
                    .transition(.scale(scale: 0.86).combined(with: .opacity))
                    .id(pop.id)
            }
        }
    }
}

private struct RewardPopCard: View {
    var pop: RewardPopModel
    var close: () -> Void
    @State private var spin = false

    var body: some View {
        let tint = Color(hex: pop.color)
        VStack(spacing: 10) {
            ZStack {
                ForEach(0..<12, id: \.self) { i in
                    Capsule().fill(tint.opacity(0.18)).frame(width: 6, height: 34)
                        .offset(y: -56).rotationEffect(.degrees(Double(i) * 30 + (spin ? 30 : 0)))
                }
                Circle().fill(tint).frame(width: 84, height: 84)
                if let person = pop.person {
                    AvatarView(person: person, size: 84, frame: "none")
                } else {
                    Image(systemName: Icon.symbol(pop.icon)).font(.system(size: 32, weight: .semibold)).foregroundStyle(.white)
                }
            }
            .frame(height: 140)
            if let eyebrow = pop.eyebrow { Text(eyebrow).labelStyle(tint) }
            Text(pop.title).font(.system(size: 22, weight: .bold)).tracking(-0.4).multilineTextAlignment(.center)
            if let sub = pop.sub { Text(sub).mutedStyle(14).multilineTextAlignment(.center) }
            if !pop.stats.isEmpty {
                VStack(spacing: 0) {
                    ForEach(pop.stats, id: \.self) { stat in
                        HStack(spacing: 10) {
                            if stat.glyph == "coin" { CoinIcon(size: 18) } else {
                                Image(systemName: Icon.symbol(stat.glyph)).font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color(hex: stat.color ?? pop.color))
                            }
                            Text(stat.label).font(.system(size: 14))
                            Spacer()
                            Text(stat.value).font(.system(size: 14, weight: .bold)).monospacedDigit()
                        }
                        .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, 14)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            }
            VStack(spacing: 8) {
                if let label = pop.shareLabel, let text = pop.shareText {
                    ShareLink(item: text) { Label(label, systemImage: "square.and.arrow.up") }
                        .buttonStyle(.pill(.primary, fill: true))
                        .simultaneousGesture(TapGesture().onEnded { close() })
                }
                Button(pop.done, action: close).buttonStyle(.pill(.soft, fill: true))
            }
            .padding(.top, 6)
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .overlay { ConfettiView(count: 36).allowsHitTesting(false) }
        .onAppear { withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) { spin = true } }
    }
}

extension Format {
    /// "4" for 4.0 and "0.5" for 0.5, like the mockup's percentages.
    nonisolated static func pctText(_ pct: Double) -> String {
        pct == pct.rounded() ? String(Int(pct)) : String(format: "%.1f", pct)
    }
}
