//
//  StreakView.swift
//  Odyssey
//
//  The streak screen. Globie up top in whatever mood your streak puts it
//  in, the count, this week, the next milestones and your streak freezes.
//  One check-in anywhere keeps the streak alive for the day.
//  Ported from features/streak/streak.js.
//

import Foundation
import SwiftUI

struct StreakView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toast

    private let moods: [(GlobieMood, String)] = [
        (.happy, "Explored today"), (.sleepy, "Waiting on you"), (.ecstatic, "Milestone"), (.sad, "Streak lost"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Streak", back: { router.pop() }) {
                ShareLink(item: "\(store.state.streak.days) day exploring streak on Odyssey") {
                    Image(systemName: Icon.symbol("share"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 40, height: 40)
                        .background(Palette.surface2, in: Circle())
                }
            }
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    VStack(alignment: .leading, spacing: 0) {
                        if !store.streakClaimedToday {
                            Button { router.present(.checkIn(placeID: nil)) } label: {
                                Label("Check in to keep it", systemImage: "camera")
                            }
                            .buttonStyle(.pill(.accent, fill: true))
                            .padding(.bottom, 16)
                        }
                        stats.padding(.bottom, 8)
                        SectionHeader(title: "Globie's forms", link: "10 to unlock").padding(.top, 12)
                        forms.padding(.bottom, 20)
                        SectionHeader(title: "Moods")
                        moodsGrid.padding(.bottom, 16)
                        row(icon: "snow", title: "Streak freeze", sub: "Covers one missed day automatically") { router.push(.shop(nil)) }
                        row(icon: "widget", title: "Put Globie on your home screen", sub: "Widgets for your streak, coins and today's adventure") { router.push(.widgets) }
                    }
                    .padding(.horizontal, 16)
                    Color.clear.frame(height: 32)
                }
            }
        }
        .background(Palette.surface)
    }

    private var heroColor: Color {
        switch store.globieMood {
        case .happy: return Color(hex: "#eef3ff")
        case .sleepy: return Palette.surface2
        case .sad: return Color(hex: "#f3f3f5")
        case .ecstatic: return Palette.goldSoft
        }
    }

    private var hero: some View {
        let done = store.streakClaimedToday
        return VStack(spacing: 0) {
            GlobieView(mood: store.globieMood, form: store.streakTier.id, size: 132)
            Text("\(store.state.streak.days)")
                .font(.system(size: 64, weight: .heavy))
                .tracking(-2.5)
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .padding(.top, 6)
            Text("day exploring streak").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink).padding(.top, 4)
            Text(done ? "Today counted. See you tomorrow." : "Check in anywhere today and Globie wakes up.")
                .mutedStyle(13)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
                .padding(.top, 6)
            StreakWeekRow(week: store.streakWeek).padding(.top, 18)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 26)
        .padding(.bottom, 22)
        .padding(.horizontal, 16)
        .background(heroColor, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 16)
    }

    private var stats: some View {
        let s = store.state
        let next = StreakTiers.milestones.first { $0 > s.streak.days }
        let freezes = s.boosts["streak-freeze"] ?? 0
        return HStack(spacing: 8) {
            stat("\(max(s.streak.best, s.streak.days))", "Best streak")
            stat("\(next.map { $0 - s.streak.days } ?? 0)", next.map { "Days to \($0)" } ?? "All milestones")
            stat("\(freezes)", freezes == 1 ? "Freeze" : "Freezes")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 22, weight: .heavy)).tracking(-0.4).monospacedDigit().foregroundStyle(Palette.ink)
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    private var forms: some View {
        let days = store.state.streak.days
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StreakTiers.all.filter { $0.days > 0 }) { tier in
                    let hit = days >= tier.days
                    Button {
                        toast.show(hit ? "\(tier.name) is yours" : "\(tier.name) unlocks at \(tier.days) days", icon: "flame")
                    } label: {
                        VStack(spacing: 2) {
                            GlobieView(mood: .happy, form: tier.id, size: 44, animated: hit)
                                .grayscale(hit ? 0 : 1)
                                .opacity(hit ? 1 : 0.45)
                                .frame(height: 46)
                                .overlay(alignment: .bottomTrailing) {
                                    if !hit {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 18, height: 18)
                                            .background(Palette.ink, in: Circle())
                                            .offset(x: 2, y: -2)
                                    }
                                }
                            Text("\(tier.days)").font(.system(size: 15, weight: .heavy)).foregroundStyle(Palette.ink)
                            Text(tier.shortName).font(.system(size: 10, weight: .semibold)).foregroundStyle(Palette.muted).lineLimit(1)
                        }
                        .frame(width: 72)
                        .padding(.top, 8)
                        .padding(.bottom, 10)
                        .background(hit ? tier.color.opacity(0.14) : Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
    }

    private var moodsGrid: some View {
        HStack(spacing: 8) {
            ForEach(moods.indices, id: \.self) { index in
                VStack(spacing: 4) {
                    GlobieView(mood: moods[index].0, form: "classic", size: 52)
                    Text(moods[index].1).font(.system(size: 10, weight: .semibold)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 4)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            }
        }
    }

    private func row(icon: String, title: String, sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: Icon.symbol(icon))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 40, height: 40)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                    Text(sub).font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.faint)
            }
            .padding(12)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(PressStyle())
        .padding(.bottom, 8)
    }
}
