//
//  MegaQuests.swift
//  Odyssey
//
//  Mega quests: travel sized goals worth huge rewards. Visiting another
//  country or another state can't be faked from home, so they pay ten or
//  five times a normal quest. The country one plays the arrival scene; the
//  state one ends in a reward pop. Ported from features/quests/mega-quests.js
//  and mega.css.
//

import Foundation
import SwiftUI

struct MegaQuest: Identifiable, Hashable {
    var id: String
    var title: String
    var sub: String
    var coins: Int
    var mult: Int
    var glyph: String
    var color: String

    static let all = [
        MegaQuest(id: "mega-country", title: "Visit another country", sub: "Land somewhere new and explore one street",
                  coins: 5000, mult: 10, glyph: "globe", color: "#d39b00"),
        MegaQuest(id: "mega-state", title: "Visit another state", sub: "Cross a state line and check in",
                  coins: 1500, mult: 5, glyph: "route", color: "#2b59ff"),
    ]

    static let nextState = (name: "Arizona", drive: "11h drive")

    var isCountry: Bool { id == "mega-country" }

    @MainActor func done(_ store: AppStore) -> Bool {
        isCountry ? !store.state.travelCountries.isEmpty : !store.state.travelStates.isEmpty
    }
}

/// The two big travel cards above the quest list.
struct MegaQuestRow: View {
    @Environment(AppStore.self) private var store
    var onOpen: (MegaQuest) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(MegaQuest.all) { quest in
                MegaQuestCard(quest: quest, done: quest.done(store)) { onOpen(quest) }
            }
        }
        .padding(.bottom, 12)
    }
}

struct MegaQuestCard: View {
    var quest: MegaQuest
    var done: Bool
    var action: () -> Void
    @State private var breathe = false

    var body: some View {
        let color = Color(hex: quest.color)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    MegaQuestTag(color: color, text: "Mega")
                    Spacer()
                    Text("\(quest.mult)x").font(.system(size: 20, weight: .black)).foregroundStyle(color)
                }
                Image(systemName: Icon.symbol(quest.glyph)).font(.system(size: 26, weight: .semibold)).padding(.vertical, 4)
                Text(quest.title).font(.system(size: 15, weight: .heavy)).lineLimit(2).multilineTextAlignment(.leading)
                if done {
                    Label("Completed", systemImage: "checkmark").font(.system(size: 13))
                } else {
                    HStack(spacing: 4) {
                        CoinIcon(size: 14)
                        Text(Format.number(quest.coins)).font(.system(size: 13, weight: .semibold))
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .topTrailing) {
                Circle().fill(color).frame(width: 110, height: 110).blur(radius: 28)
                    .opacity(breathe ? 0.85 : 0.55).scaleEffect(breathe ? 1.15 : 1)
                    .offset(x: 30, y: -30)
            }
            .background(Color(hex: "#0e1226"))
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(color, lineWidth: 2))
            .opacity(done ? 0.6 : 1)
        }
        .buttonStyle(PressStyle())
        .loops($breathe, .easeInOut(duration: 1.5))
    }
}

struct MegaQuestTag: View {
    var color: Color
    var text: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "globe.americas").font(.system(size: 9, weight: .bold))
            Text(text.uppercased()).font(.system(size: 10, weight: .black)).tracking(0.6)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color, in: Capsule())
    }
}

/// The mega quest sheet: what it takes, the reward and the one big button.
struct MegaQuestSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(RewardPopCenter.self) private var pop
    @Environment(\.dismiss) private var dismiss
    var quest: MegaQuest

    var body: some View {
        let color = Color(hex: quest.color)
        let done = quest.done(store)
        VStack(spacing: 10) {
            Image(systemName: Icon.symbol(quest.glyph))
                .font(.system(size: 36, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 84, height: 84)
                .background(color, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 15, y: 12)
            MegaQuestTag(color: color, text: "Mega quest, \(quest.mult)x points")
            Text(quest.title).font(.system(size: 22, weight: .bold)).tracking(-0.4).foregroundStyle(Palette.ink)
            Text(quest.sub + ". Odyssey confirms it from your location, no photo needed.")
                .font(.system(size: 15)).foregroundStyle(Palette.muted)
            HStack(spacing: 10) {
                CoinIcon(size: 20)
                Text(Format.number(quest.coins)).font(.system(size: 22, weight: .heavy))
                Text("+\(quest.isCountry ? 250 : 100) XP").font(.system(size: 13)).foregroundStyle(Palette.muted)
            }
            Text(quest.isCountry
                 ? "Visited so far: " + store.travelCountries.compactMap { store.seed.countries[$0]?.name }.joined(separator: ", ")
                 : "Closest new state: \(MegaQuest.nextState.name), \(MegaQuest.nextState.drive)")
                .font(.system(size: 13)).foregroundStyle(Palette.muted)
            Button(action: go) {
                Label(done ? "Completed" : (quest.isCountry ? "Fly to Paris" : "Road trip to \(MegaQuest.nextState.name)"),
                      systemImage: done ? "checkmark" : "airplane")
            }
            .buttonStyle(SeasonGoButtonStyle(color: color))
            .disabled(done)
            .padding(.top, 6)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
        .padding(.top, 30)
        .padding(.bottom, 8)
    }

    private func go() {
        dismiss()
        if quest.isCountry {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { router.present(.countryScene) }
            return
        }
        let state = MegaQuest.nextState.name
        store.update { s in s.travelStates.append(state) }
        store.earn(quest.coins)
        store.addXp(100, boostable: false)
        pop.show(RewardPopModel(
            icon: "route", color: quest.color, eyebrow: "Mega quest complete", title: "Welcome to \(state)",
            sub: "State number \(store.seed.travel.states.count + 1) on your explored map.",
            stats: [.init(glyph: "coin", label: "Mega reward", value: "+" + Format.number(quest.coins)),
                    .init(glyph: "bolt", label: "XP", value: "+100")],
            shareLabel: "Share your road trip", shareText: "Road trip to \(state) on Odyssey: pathy.app/arrive/az"))
    }
}
