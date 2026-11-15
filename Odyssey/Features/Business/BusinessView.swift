//
//  BusinessView.swift
//  Odyssey
//
//  Odyssey for Business. A business puts money on walkthrough videos of its
//  place or an area, and local explorers split it as they record. This is
//  the business home: what a bounty is, the ones you posted and how far
//  along each one is. Ported from features/business/business.js.
//

import Foundation
import SwiftUI

struct BusinessView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var openBounty: BusinessSheetID?

    var body: some View {
        let list = store.myPostedBounties
        VStack(spacing: 0) {
            NavHeader(title: "Odyssey for Business", back: { router.pop() })
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero.padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 18)
                    VStack(alignment: .leading, spacing: 0) {
                        if list.isEmpty {
                            empty
                        } else {
                            stats(list)
                            SectionHeader(title: "Your bounties").padding(.top, 22)
                            VStack(spacing: 10) {
                                ForEach(list) { b in
                                    BountyCard(bounty: b) { openBounty = BusinessSheetID(id: b.id) }
                                }
                            }
                        }
                        SectionHeader(title: "How it works").padding(.top, 22)
                        VStack(alignment: .leading, spacing: 12) {
                            step("target", "Pick a place or an area", "Your storefront, a building, a street or all of \(store.home.city).")
                            step("dollar", "Set the reward and the split", "Pay per walkthrough, or share it evenly between everyone who helps.")
                            step("check", "Only approved videos pay", "Every walkthrough is reviewed before any money moves, and unused money comes back to you.")
                        }
                        Color.clear.frame(height: 40)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .background(Palette.surface)
        .sheet(item: $openBounty) { item in
            BountySheet(bountyID: item.id, onStart: { place in
                // Push once the sheet has slid away, so the place page is not opened behind it.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.push(.place(place.id)) }
            })
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "storefront")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(hex: "#3a2600"))
                .frame(width: 48, height: 48)
                .background(Palette.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text("Bring explorers through your door").font(.system(size: 26, weight: .bold)).tracking(-0.8)
            Text("Put a bounty on walkthrough videos of your cafe, your shop or a whole neighborhood. Local explorers check in, record the inside and split the reward, and people nearby see what it is like before they come.")
                .font(.system(size: 13)).lineSpacing(3).opacity(0.75)
            Button { router.present(.bountyWizard) } label: { Label("Post a bounty", systemImage: "plus") }
                .buttonStyle(.pill(.light, fill: true))
            Label("\(Format.number(1284)) explorers within 2 km of \(store.home.neighborhood)", systemImage: "person.2")
                .font(.system(size: 11)).opacity(0.65)
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 18)
        .background(Palette.ink, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
    }

    private func stats(_ list: [Bounty]) -> some View {
        let pool = list.reduce(0) { $0 + $1.pool }
        let recorded = list.reduce(0) { $0 + $1.recorded }
        return HStack(spacing: 8) {
            cell("\(list.count)", "Bounties")
            cell(Format.money(pool), "Put up")
            cell("\(recorded)", "Walkthroughs")
        }
    }

    private func cell(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 19, weight: .bold)).tracking(-0.4).monospacedDigit()
            Text(label).font(.system(size: 11)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    private var empty: some View {
        VStack(spacing: 4) {
            Image(systemName: "dollarsign").font(.system(size: 20, weight: .semibold))
            Text("No bounties yet").font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.ink)
            Text("Your first one takes about a minute.").font(.system(size: 13))
        }
        .foregroundStyle(Palette.muted)
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    private func step(_ icon: String, _ title: String, _ sub: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: Icon.symbol(icon)).font(.system(size: 16, weight: .semibold))
                .frame(width: 40, height: 40).background(Palette.surface2, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .bold))
                Text(sub).font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
        }
    }
}

/// Identifies which bounty sheet is open.
struct BusinessSheetID: Identifiable, Hashable {
    var id: String
}
