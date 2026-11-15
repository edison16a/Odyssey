//
//  QuestList.swift
//  Odyssey
//
//  Quests near you. The two mega quests come first, then a live Mythical
//  quest gets a gold banner, and every other quest is a row tagged with
//  its rarity, multiplier and whether it needs a friend. Tapping one opens the quest sheet.
//  Ported from features/quests/quest-list.js.
//

import Foundation
import SwiftUI

/// The quest section on the home panel.
struct QuestListSection: View {
    @Environment(AppStore.self) private var store
    @State private var open: Quest?
    @State private var mega: MegaQuest?

    var body: some View {
        let quests = store.openQuests
        let mythic = quests.first { $0.rarity == "mythical" }
        let rest = quests.filter { $0.id != mythic?.id }
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Quests near you", link: "\(quests.count) open")
            MegaQuestRow { mega = $0 }
            if let mythic {
                QuestMythicBanner(quest: mythic) { open = mythic }
                    .padding(.bottom, 12)
            }
            VStack(spacing: 0) {
                if rest.isEmpty {
                    Text("All quests done. New ones drop tomorrow.")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                } else {
                    ForEach(Array(rest.enumerated()), id: \.element.id) { index, quest in
                        if index > 0 { Divider().overlay(Palette.line) }
                        QuestRow(quest: quest) { open = quest }
                    }
                }
            }
            .card(padding: 12)
        }
        .sheet(item: $open) { quest in
            QuestSheet(questID: quest.id)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        // A second sheet on the same view is unreliable, so it hangs off a background, like the home tab's.
        .background {
            Color.clear.sheet(item: $mega) { quest in
                MegaQuestSheet(quest: quest)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
        }
    }
}

/// The full list, pushed from widgets and links.
struct QuestsView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Quests", back: { router.pop() })
            ScrollView(showsIndicators: false) {
                QuestListSection()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
        }
        .background(Palette.surface)
    }
}

struct QuestRow: View {
    @Environment(AppStore.self) private var store
    var quest: Quest
    var onTap: () -> Void

    var body: some View {
        let rarity = store.questRarity(quest)
        let color = Color(hex: rarity.color)
        Button(action: onTap) {
            HStack(spacing: 12) {
                Group {
                    if let place = store.place(quest.placeId) { PlacePhoto(place: place) } else { Palette.surface3 }
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).strokeBorder(color, lineWidth: 2))
                VStack(alignment: .leading, spacing: 4) {
                    Text(quest.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                    HStack(spacing: 5) {
                        QuestRarityBadge(label: rarity.label, color: color)
                        if quest.multiplier > 1 { QuestMultiplierBadge(multiplier: quest.multiplier) }
                        if quest.needsFriend { Tag(text: "Friend", icon: "users") }
                        Text(quest.ends).font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        CoinIcon(size: 14)
                        Text(Format.number(quest.coins * quest.multiplier)).font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.ink)
                    }
                    Text("+\(quest.xp * quest.multiplier) XP").font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

struct QuestRarityBadge: View {
    var label: String
    var color: Color

    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 10, weight: .heavy))
            .tracking(0.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(color, in: Capsule())
    }
}

struct QuestMultiplierBadge: View {
    var multiplier: Int

    var body: some View {
        Text("\(multiplier)x")
            .font(.system(size: 10.5, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(Palette.ink, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// Mythical drop: a dark gold card with a sweeping shine.
struct QuestMythicBanner: View {
    @Environment(AppStore.self) private var store
    var quest: Quest
    var onTap: () -> Void
    @State private var shine = false

    private let gold = Color(hex: "#ffd76a")

    var body: some View {
        let partners = store.questPartners(quest.id).compactMap { store.person($0)?.firstName }
        Button(action: onTap) {
            HStack(spacing: 12) {
                Group {
                    if let place = store.place(quest.placeId) { PlacePhoto(place: place) } else { Palette.ink2 }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(gold, lineWidth: 2))
                VStack(alignment: .leading, spacing: 2) {
                    Label("Mythical quest dropped", systemImage: "diamond.fill")
                        .font(.system(size: 10.5, weight: .black)).tracking(1.2).textCase(.uppercase).foregroundStyle(gold)
                    Text(quest.title).font(.system(size: 15, weight: .bold)).multilineTextAlignment(.leading).padding(.bottom, 4)
                    HStack(spacing: 8) {
                        Label(partners.isEmpty ? "Bring a friend" : "With " + partners.joined(separator: ", "), systemImage: "person.2")
                        Text(quest.ends)
                    }
                    .font(.system(size: 11))
                    .opacity(0.85)
                }
                Spacer(minLength: 0)
                Text("\(quest.multiplier)x").font(.system(size: 30, weight: .black)).foregroundStyle(gold).shadow(color: gold.opacity(0.6), radius: 9)
            }
            .foregroundStyle(.white)
            .padding(14)
            .background {
                ZStack {
                    Color(hex: "#1a1306")
                    GeometryReader { geo in
                        LinearGradient(colors: [.clear, gold.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width * 0.4)
                            .offset(x: shine ? geo.size.width * 1.2 : -geo.size.width * 0.5)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(Color(hex: "#d39b00"), lineWidth: 2))
            .shadow(color: Color(hex: "#d39b00").opacity(0.3), radius: 15, y: 10)
        }
        .buttonStyle(PressStyle())
        .onAppear {
            withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) { shine = true }
        }
    }
}
