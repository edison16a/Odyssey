//
//  ProfileExplorerPicker.swift
//  Odyssey
//
//  Pick the historical explorer your profile wears. Your match comes from
//  the interests you chose; higher tier icons unlock as your rank grows.
//  The match is a playful label, not a claim about you.
//

import Foundation
import SwiftUI

struct ProfileExplorerPicker: View {
    @Environment(AppStore.self) private var store
    @Environment(ToastCenter.self) private var toast
    @Environment(\.dismiss) private var dismiss

    /// The explorer whose trait lines up with your interests.
    private var match: String {
        let interests = store.state.interests
        if interests["books"] == true { return "xuanzang" }
        if interests["outdoors"] == true { return "tenzing-norgay" }
        if interests["culture"] == true { return "ida-pfeiffer" }
        if interests["nightlife"] == true { return "nellie-bly" }
        return "ibn-battuta"
    }

    var body: some View {
        let tier = store.rank().tier
        VStack(spacing: 0) {
            NavHeader(title: "Explorer Icons") {
                IconButton(icon: "close", kind: .clear, label: "Close") { dismiss() }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pick the explorer that feels like you. Your match is based on the places you love. New icons unlock as your rank grows.")
                        .font(.system(size: 13)).foregroundStyle(Palette.muted)
                    ForEach(store.seed.explorers) { explorer in
                        row(explorer, locked: explorer.tier > tier)
                    }
                    Text("Facts are short summaries of well documented history.")
                        .font(.system(size: 11)).foregroundStyle(Palette.faint)
                        .padding(.bottom, 30)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Palette.surface)
        // The app's toasts sit under the sheet, so "Equipped" is drawn here too.
        .overlay { ToastOverlay() }
    }

    private func row(_ explorer: Explorer, locked: Bool) -> some View {
        let on = store.state.equipped.explorer == explorer.id
        return Button {
            store.update { s in s.equipped.explorer = explorer.id }
            toast.show("Equipped " + explorer.name, icon: "check")
            Haptics.tap()
        } label: {
            ProfileExplorerCard(explorer: explorer, eyebrow: explorer.id == match ? "Your match" : explorer.trait, full: true)
                .saturation(locked ? 0 : 1)
                .opacity(locked ? 0.45 : 1)
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: 4) {
                        if locked {
                            Image(systemName: "lock.fill")
                            Text(store.seed.ranks[min(explorer.tier, store.seed.ranks.count - 1)].name)
                        } else if on {
                            Image(systemName: "checkmark")
                            Text("Equipped")
                        } else {
                            Text("Equip")
                        }
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(on ? .white : ProfileExplorerCard.ink)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(on ? ProfileExplorerCard.ink : .white.opacity(0.8), in: Capsule())
                    .padding(10)
                }
                .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(on ? Palette.accent : .clear, lineWidth: 2))
        }
        .buttonStyle(PressStyle(scale: 0.98))
        .disabled(locked)
    }
}
