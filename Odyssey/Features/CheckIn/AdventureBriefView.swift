//
//  AdventureBriefView.swift
//  Odyssey
//
//  The page "Start Today's Adventure" opens before the camera: the place up
//  top, the adventure laid out step by step (head there, arrive, film, collect)
//  and every reward it pays, line by line. The button at the bottom opens the
//  camera once you're there, or walking directions until you are.
//

import Foundation
import SwiftUI

struct AdventureBriefView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var placeID: String

    @State private var appeared = false

    var body: some View {
        if let place = store.place(placeID) {
            let rewards = store.checkInRewards(for: place)
            ZStack(alignment: .bottom) {
                Palette.surface.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        hero(place, rewards: rewards)
                        VStack(alignment: .leading, spacing: 24) {
                            totals(rewards)
                            steps(place, rewards: rewards)
                            breakdown(rewards, place: place)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 140)
                    }
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea(edges: .top)
                actions(place, rewards: rewards)
            }
            .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.1)) { appeared = true } }
        } else {
            Color.clear.onAppear { router.dismissCover() }
        }
    }

    // MARK: Hero

    private func hero(_ place: Place, rewards: CheckInRewards) -> some View {
        ZStack(alignment: .bottomLeading) {
            PlacePhoto(place: place)
                .frame(height: 340)
                .frame(maxWidth: .infinity)
                .clipped()
            LinearGradient(stops: [.init(color: .black.opacity(0.45), location: 0), .init(color: .clear, location: 0.35),
                                   .init(color: .black.opacity(0.85), location: 1)],
                           startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Tag(text: "Today's Adventure", icon: "sparkle", tone: .dark)
                    if rewards.first { Tag(text: "Be first", icon: "star-fill", tone: .rare) }
                }
                Text(place.name).font(.system(size: 32, weight: .heavy)).tracking(-0.8).lineLimit(2)
                Text(store.why(place)).font(.system(size: 14)).foregroundStyle(.white.opacity(0.85)).lineLimit(2)
            }
            .foregroundStyle(.white)
            .padding(20)
        }
        .overlay(alignment: .topLeading) {
            IconButton(icon: "close", kind: .white, label: "Close") { router.dismissCover() }
                .padding(.leading, 16)
                .padding(.top, 60)
        }
    }

    // MARK: Totals

    private func totals(_ rewards: CheckInRewards) -> some View {
        HStack(spacing: 10) {
            total(icon: AnyView(CoinIcon(size: 26)), value: "+\(rewards.coins)", label: "coins", tint: Palette.gold)
            total(icon: AnyView(Image(systemName: "bolt.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(Palette.rare)),
                  value: "+\(rewards.totalXp)", label: "XP", tint: Palette.rare)
            if !store.streakClaimedToday {
                total(icon: AnyView(Image(systemName: "flame.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(Palette.flame)),
                      value: "\(store.state.streak.days + 1)", label: "day streak", tint: Palette.flame)
            }
        }
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
    }

    private func total(icon: AnyView, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            icon.frame(height: 28)
            Text(value).font(.system(size: 24, weight: .heavy)).monospacedDigit().foregroundStyle(Palette.ink)
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    // MARK: Steps

    private struct Step: Identifiable {
        var id: Int
        var icon: String
        var title: String
        var detail: String
        var reward: String?
        var done: Bool
    }

    private func stepList(_ place: Place, rewards: CheckInRewards) -> [Step] {
        let metres = store.metres(to: place)
        let here = rewards.inReach
        let firstLine = rewards.first ? " Nobody on Odyssey has been yet." : ""
        return [
            Step(id: 1, icon: "figure.walk", title: "Head there",
                 detail: here ? "You're already here." : "\(Format.distance(metres)) away, about \(Format.walkTime(metres)).",
                 reward: nil, done: here),
            Step(id: 2, icon: "mappin.and.ellipse", title: "Arrive",
                 detail: (here ? "You're within \(Int(Rewards.checkInRadius)) m, so the rewards are unlocked."
                              : "Get within \(Int(Rewards.checkInRadius)) m to unlock the rewards.") + firstLine,
                 reward: rewards.xp > 0 ? "+\(rewards.xp) XP" : nil, done: here),
            Step(id: 3, icon: "video.fill", title: "Film a walkthrough",
                 detail: "Show what it's like inside, up to \(Rewards.maxClipSeconds) seconds.",
                 reward: rewards.videoXp > 0 ? "+\(rewards.videoXp) XP" : nil, done: false),
            Step(id: 4, icon: "gift.fill", title: "Collect your rewards",
                 detail: store.streakClaimedToday ? "Coins and XP land right away." : "Coins, XP, and your streak keeps going.",
                 reward: "+\(rewards.coins) coins", done: false),
        ]
    }

    private func steps(_ place: Place, rewards: CheckInRewards) -> some View {
        let list = stepList(place, rewards: rewards)
        let current = list.first { !$0.done }?.id ?? 4
        return VStack(alignment: .leading, spacing: 14) {
            Text("Your adventure").font(.system(size: 20, weight: .heavy)).foregroundStyle(Palette.ink)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(list) { step in
                    stepRow(step, current: step.id == current, last: step.id == list.last?.id)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 14)
                        .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.12 * Double(step.id)), value: appeared)
                }
            }
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(Palette.line))
        }
    }

    private func stepRow(_ step: Step, current: Bool, last: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(step.done ? Palette.success : (current ? Palette.accent : Palette.surface2))
                    if step.done {
                        Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                    } else {
                        Image(systemName: step.icon).font(.system(size: 15, weight: .bold))
                            .foregroundStyle(current ? .white : Palette.muted)
                    }
                }
                .frame(width: 38, height: 38)
                .overlay(Circle().strokeBorder(Palette.accent.opacity(current ? 0.3 : 0), lineWidth: 6).padding(-5))
                if !last {
                    Rectangle()
                        .fill(step.done ? Palette.success : Palette.line)
                        .frame(width: 3)
                        .frame(minHeight: 28, maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Step \(step.id)").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.muted)
                    Spacer()
                    if let reward = step.reward {
                        Text(reward)
                            .font(.system(size: 12, weight: .heavy)).monospacedDigit()
                            .foregroundStyle(reward.contains("XP") ? Palette.rare : Color(hex: "#a16207"))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background((reward.contains("XP") ? Palette.rare : Palette.gold).opacity(0.12), in: Capsule())
                    }
                }
                Text(step.title).font(.system(size: 17, weight: .heavy)).foregroundStyle(step.done ? Palette.muted : Palette.ink)
                Text(step.detail).font(.system(size: 14)).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, last ? 0 : 18)
        }
    }

    // MARK: Breakdown

    private func breakdown(_ rewards: CheckInRewards, place: Place) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Everything you'll earn").font(.system(size: 20, weight: .heavy)).foregroundStyle(Palette.ink)
            VStack(spacing: 0) {
                ForEach(rewards.lines) { line in
                    row(icon: icon(for: line.kind), tint: Palette.gold, label: line.label, value: "+\(line.coins)", coin: true)
                    Divider().overlay(Palette.line)
                }
                if rewards.xp > 0 { row(icon: "bolt.fill", tint: Palette.rare, label: "Check-in XP", value: "+\(rewards.xp) XP") }
                if rewards.videoXp > 0 {
                    Divider().overlay(Palette.line)
                    row(icon: "video.fill", tint: Palette.rare, label: "Walkthrough video XP", value: "+\(rewards.videoXp) XP")
                }
                if !store.streakClaimedToday {
                    Divider().overlay(Palette.line)
                    row(icon: "flame.fill", tint: Palette.flame, label: "Streak", value: "\(store.state.streak.days + 1) days")
                }
                HStack {
                    Text("Total").font(.system(size: 15, weight: .heavy))
                    Spacer()
                    CoinIcon(size: 18)
                    Text("+\(rewards.coins)").font(.system(size: 17, weight: .heavy)).monospacedDigit()
                    Text("+\(rewards.totalXp) XP").font(.system(size: 15, weight: .heavy)).foregroundStyle(Palette.rare)
                }
                .foregroundStyle(Palette.ink)
                .padding(.top, 14)
            }
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(Palette.line))
            rankLine(rewards, place: place)
            if !rewards.fresh {
                note("You already explored here today. Rewards pay once a day.", icon: "clock")
            }
        }
    }

    @ViewBuilder private func rankLine(_ rewards: CheckInRewards, place: Place) -> some View {
        let rank = store.rank()
        if let next = rank.next, rank.toNext > 0 {
            let jumps = rewards.totalXp >= rank.toNext || (store.state.demoMode && place.id == "yc")
            note(jumps ? "This adventure ranks you up to \(next.name)."
                       : "\(rank.toNext - rewards.totalXp) XP after this to \(next.name).",
                 icon: "shield.lefthalf.filled", highlight: jumps)
        }
    }

    private func note(_ text: String, icon: String, highlight: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold))
            Text(text).font(.system(size: 14, weight: .semibold))
            Spacer(minLength: 0)
        }
        .foregroundStyle(highlight ? Palette.accentInk : Palette.muted)
        .padding(14)
        .background(highlight ? Palette.accentSoft : Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    private func row(icon: String, tint: Color, label: String, value: String, coin: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12), in: Circle())
            Text(label).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(2)
            Spacer(minLength: 8)
            if coin { CoinIcon(size: 16) }
            Text(value).font(.system(size: 15, weight: .heavy)).monospacedDigit()
                .foregroundStyle(coin ? Palette.ink : tint)
        }
        .padding(.vertical, 10)
    }

    private func icon(for kind: RewardLine.Kind) -> String {
        switch kind {
        case .checkIn: "mappin.circle.fill"
        case .first: "star.fill"
        case .quest: "flag.fill"
        case .recommended: "sparkles"
        case .videoQuest: "video.fill"
        case .task: "checklist"
        }
    }

    // MARK: Actions

    private func actions(_ place: Place, rewards: CheckInRewards) -> some View {
        VStack(spacing: 8) {
            if rewards.inReach {
                primary("I'm here, start filming", icon: "video.fill") { start(place) }
            } else {
                primary("Get walking directions", icon: "figure.walk") { NearbyService.directions(to: place) }
                Button { start(place) } label: {
                    Text("Start filming anyway").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity).frame(height: 36)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func primary(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 15, weight: .bold))
                Text(title).font(.system(size: 17, weight: .heavy))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Palette.accent, in: Capsule())
            .shadow(color: Palette.accent.opacity(0.35), radius: 12, y: 4)
        }
        .buttonStyle(PressStyle(scale: 0.97))
    }

    private func start(_ place: Place) {
        router.present(.checkIn(placeID: place.id))
    }
}
