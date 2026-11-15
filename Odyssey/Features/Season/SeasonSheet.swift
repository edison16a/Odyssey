//
//  SeasonSheet.swift
//  Odyssey
//
//  A seasonal quest. Pick the spot, check in when you are there, and the
//  first one you finish unboxes the event's exclusive title. Every other
//  finish shows the reward pop. Ported from features/season/season-sheet.js.
//

import Foundation
import SwiftUI

struct SeasonSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(RewardPopCenter.self) private var pop
    @Environment(\.dismiss) private var dismiss
    var questID: String
    /// Called when finishing unlocks the event title, to play the unboxing.
    var onUnlock: (ShopItem) -> Void
    @State private var checking = false

    var body: some View {
        if let quest = store.extras.seasonQuest(questID) {
            let done = store.seasonDone(quest.id)
            let color = Color(hex: quest.color)
            let season = store.extras.season
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Color(hex: "#0d1b33")
                    SeasonFlurry(count: 14)
                    Image(systemName: Icon.symbol(quest.glyph))
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 76, height: 76)
                        .background(color, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: color, radius: 18)
                }
                .frame(height: 130)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                Label(season.name, systemImage: "snowflake")
                    .font(.system(size: 10.5, weight: .heavy)).tracking(1).textCase(.uppercase)
                    .foregroundStyle(color)
                Text(quest.title).font(.system(size: 22, weight: .bold)).tracking(-0.4).foregroundStyle(Palette.ink)
                HStack(spacing: 10) {
                    Image(systemName: "mappin").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                        .frame(width: 36, height: 36).background(Palette.surface3, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(quest.spot).font(.system(size: 15, weight: .bold))
                        Text("\(SeasonSheet.km(quest.km)) km away").font(.system(size: 13)).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    CoinIcon(size: 14)
                    Text(Format.number(quest.coins)).font(.system(size: 14, weight: .bold))
                }
                .padding(12)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                HStack(spacing: 4) {
                    Text("Finish any one \(season.name) quest to unlock").font(.system(size: 13)).foregroundStyle(Palette.muted)
                    ProfileTitleText(id: season.reward.title, text: titleName(season.reward.title), size: 13)
                }
                Text("plus \(season.reward.coins) bonus coins.").font(.system(size: 13)).foregroundStyle(Palette.muted)
                Button { checkIn(quest) } label: {
                    HStack(spacing: 8) {
                        if checking { ProgressView().tint(.white) }
                        else { Image(systemName: done ? "checkmark" : "location") }
                        Text(done ? "Completed" : checking ? "Checking your location" : "I'm here, check in")
                    }
                }
                .buttonStyle(SeasonGoButtonStyle(color: color))
                .disabled(done || checking)
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 8)
        }
    }

    private func checkIn(_ quest: SeasonQuest) {
        checking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            let unlocked = store.completeSeason(quest)
            checking = false
            dismiss()
            if unlocked, let title = store.seed.titles.first(where: { $0.id == store.extras.season.reward.title }) {
                let item = ShopItem(.title, title)
                // The unboxing cover hangs off the same view as this sheet, so wait until it has closed.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onUnlock(item) }
            } else {
                pop.show(RewardPopModel(icon: quest.glyph, color: quest.color, eyebrow: store.extras.season.name,
                                        title: "Quest complete", sub: quest.title,
                                        stats: [.init(glyph: "coin", label: "Seasonal reward", value: "+\(quest.coins)")]))
            }
        }
    }

    private func titleName(_ id: String) -> String {
        store.seed.titles.first { $0.id == id }?.name ?? id
    }

    /// "4.1" or "290", the way the mockup prints distances.
    static func km(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}

/// The full width pill in the quest's own color.
struct SeasonGoButtonStyle: ButtonStyle {
    var color: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(color, in: Capsule())
            .opacity(isEnabled ? 1 : 0.35)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
