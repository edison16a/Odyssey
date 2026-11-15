//
//  BountyWizardDone.swift
//  Odyssey
//
//  The posted screen at the end of the bounty flow, and the chip row the
//  steps use for amounts, areas and durations.
//

import Foundation
import SwiftUI

struct BountyWizardDone: View {
    @Environment(AppStore.self) private var store
    var bounty: Bounty
    var view: () -> Void
    @State private var shown = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark").font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
                .frame(width: 72, height: 72).background(Palette.success, in: Circle())
                .scaleEffect(shown ? 1 : 0.4)
            Text("Your bounty is live").font(.system(size: 24, weight: .bold)).tracking(-0.7)
            Text("\(Format.money(bounty.pool)) on \(BountyText.whereText(bounty, store: store)). We let 1,284 explorers nearby know.")
                .font(.system(size: 13)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
            BountyCard(bounty: store.bounty(bounty.id) ?? bounty, action: view)
        }
        .padding(.top, 30)
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { shown = true } }
    }
}

/// Wrapping row of chips for amounts, areas and durations.
struct BountyWizardChips: View {
    var items: [(String, String)]
    var selected: String
    var pick: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.0) { item in
                    Chip(label: item.1, isOn: item.0 == selected) { pick(item.0) }
                }
            }
        }
    }
}
