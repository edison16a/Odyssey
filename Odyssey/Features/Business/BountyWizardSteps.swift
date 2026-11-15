//
//  BountyWizardSteps.swift
//  Odyssey
//
//  The screens of the post a bounty flow, as views of the draft: where,
//  the reward and split, review with the bill, and the posted screen.
//  Ported from features/business/bounty-steps.js.
//

import Foundation
import SwiftUI
import UIKit

struct BountyWizardTarget: View {
    @Environment(AppStore.self) private var store
    @Binding var draft: BountyWizardDraft

    private var places: [Place] {
        store.nearbyPlaces.filter { ["cafe", "food", "books", "market", "museum", "gym"].contains($0.category ?? "") }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Where should explorers record?").font(.system(size: 24, weight: .bold)).tracking(-0.7)
            FieldBox {
                TextField("Business name", text: $draft.business)
                    .font(.system(size: 15))
                    .onChange(of: draft.business) { _, value in
                        if value.count > 40 { draft.business = String(value.prefix(40)) }
                    }
            }
            Segmented(options: [("place", "My place"), ("area", "An area")], selection: Binding(
                get: { draft.kind },
                set: { kind in
                    draft.videos = kind == "area" ? 30 : 8
                    draft.kind = kind
                }))
            BountyAreaMap(bounty: draft.build(store: store))
                .id(draft.kind + draft.placeId + draft.areaId)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            if draft.kind == "place" {
                VStack(spacing: 6) {
                    ForEach(places) { place in placeRow(place) }
                }
            } else {
                BountyWizardChips(items: store.extras.bountyAreas.filter { $0.area == store.home.id }.map { ($0.id, $0.name) },
                                  selected: draft.areaId) { draft.areaId = $0 }
            }
        }
    }

    private func placeRow(_ place: Place) -> some View {
        let on = draft.placeId == place.id
        return Button { draft.placeId = place.id } label: {
            HStack(spacing: 12) {
                PlacePhoto(place: place).frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(place.name).font(.system(size: 15, weight: .bold))
                    Text(place.address ?? "").font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1)
                }
                Spacer()
                if on { Image(systemName: "checkmark").font(.system(size: 16, weight: .bold)) }
            }
            .foregroundStyle(Palette.ink)
            .padding(8)
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(on ? Palette.ink : Palette.line, lineWidth: on ? 2 : 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

struct BountyWizardReward: View {
    @Binding var draft: BountyWizardDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set the reward").font(.system(size: 24, weight: .bold)).tracking(-0.7)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("$")
                TextField("", value: $draft.pool, format: .number)
                    .keyboardType(.numberPad)
                    .fixedSize()
                    .onSubmit { draft.pool = max(20, draft.pool) }
            }
            .font(.system(size: 54, weight: .heavy)).tracking(-2)
            .frame(maxWidth: .infinity)
            BountyWizardChips(items: [50, 100, 250, 500].map { ("\($0)", "$\($0)") }, selected: "\(draft.pool)") { draft.pool = Int($0) ?? 100 }
            Text("How it is split").labelStyle().padding(.top, 6)
            option("videos", "By walkthrough", Format.money(draft.perVideo) + " for each approved walkthrough, paid right away")
            option("even", "Evenly between everyone", "Shared equally by every explorer who helped, when the bounty closes")
            HStack(spacing: 12) {
                text("Walkthroughs wanted", "Short videos of the inside, 20 to 60 seconds each")
                IconButton(icon: "minus", label: "Fewer") { draft.videos = max(2, draft.videos - 1) }
                Text("\(draft.videos)").font(.system(size: 18, weight: .bold)).monospacedDigit().frame(minWidth: 26)
                IconButton(icon: "plus", label: "More") { draft.videos = min(60, draft.videos + 1) }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            Toggle(isOn: $draft.firstBonus) {
                text("First walkthrough bonus", Format.money((Double(draft.pool) * 0.2).rounded()) + " of it goes to whoever records first")
            }
            .tint(Palette.ink)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            Text("Runs for").labelStyle().padding(.top, 6)
            BountyWizardChips(items: [7, 14, 30].map { ("\($0)", "\($0) days") }, selected: "\(draft.days)") { draft.days = Int($0) ?? 14 }
        }
    }

    private func text(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 15, weight: .bold))
            Text(sub).font(.system(size: 11)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func option(_ value: String, _ title: String, _ sub: String) -> some View {
        let on = draft.split == value
        return Button { draft.split = value } label: {
            HStack(spacing: 12) {
                Circle().strokeBorder(on ? Palette.ink : Palette.lineStrong, lineWidth: on ? 6 : 2).frame(width: 20, height: 20)
                text(title, sub)
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(.white, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(on ? Palette.ink : Palette.line, lineWidth: on ? 2 : 1.5))
        }
        .buttonStyle(PressStyle())
    }
}

struct BountyWizardReview: View {
    @Environment(AppStore.self) private var store
    var draft: BountyWizardDraft

    var body: some View {
        let fee = (Double(draft.pool) * BountyWizardDraft.fee * 100).rounded() / 100
        VStack(alignment: .leading, spacing: 12) {
            Text("Review and post").font(.system(size: 24, weight: .bold)).tracking(-0.7)
            Text("How explorers will see it").labelStyle()
            BountyCard(bounty: draft.build(store: store), action: {})
            VStack(spacing: 8) {
                line("Bounty", Format.money(Double(draft.pool)), bold: true, muted: false)
                line("Odyssey fee, 10%", Format.money(fee), bold: false, muted: true)
                Divider()
                line("Total today", Format.money(Double(draft.pool) + fee), bold: true, muted: false).font(.system(size: 15))
            }
            .font(.system(size: 13))
            .padding(14)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            HStack(spacing: 12) {
                Image(systemName: "creditcard").font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Business card ending 4242").font(.system(size: 15, weight: .bold))
                    Text("Charged once. Unused money comes back when it ends.").font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
    }

    private func line(_ label: String, _ value: String, bold: Bool, muted: Bool) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).fontWeight(bold ? .bold : .regular).monospacedDigit()
        }
        .foregroundStyle(muted ? Palette.muted : Palette.ink)
    }
}
