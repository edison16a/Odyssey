//
//  DealViews.swift
//  Odyssey
//
//  Restaurant and cafe deals sold or given away through Whop (mocked for
//  the demo). A deal card shows what you get, the price and how many are
//  left; Claim opens the Whop checkout, and once claimed the same button
//  shows your discount code again. The section sits on the place preview
//  and the place page; the shelf on Home lists deals near you.
//

import Foundation
import SwiftUI

/// The Whop style mark: an orange rounded square with a W. Not the real logo.
struct WhopMark: View {
    var size: CGFloat = 18

    var body: some View {
        Text("W")
            .font(.system(size: size * 0.62, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(DealStyle.whop, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

enum DealStyle {
    static let whop = Color(hex: "#ff6243")
    static let whopSoft = Color(hex: "#fff0ec")
    static let whopInk = Color(hex: "#c2341a")

    /// "N left · ends in X days".
    static func scarcity(_ deal: Deal) -> String {
        let left = "\(deal.remaining) left"
        return left + " · " + ends(deal.expiresAt)
    }

    static func ends(_ date: Date) -> String {
        let seconds = date.timeIntervalSinceNow
        if seconds <= 0 { return "ended" }
        let days = Int(seconds / 86_400)
        if days >= 2 { return "ends in \(days) days" }
        if days == 1 { return "ends tomorrow" }
        let hours = max(1, Int(seconds / 3600))
        return "ends in \(hours)h"
    }
}

/// The percent off badge.
struct DealPercentBadge: View {
    var deal: Deal
    var size: CGFloat = 13

    var body: some View {
        Text(deal.percent >= 100 ? "FREE" : "\(deal.percent)% OFF")
            .font(.system(size: size, weight: .black))
            .tracking(0.2)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(height: size + 11)
            .background(DealStyle.whop, in: Capsule())
    }
}

/// A deal with its Claim with Whop (or View code) button.
struct DealCard: View {
    @Environment(AppStore.self) private var store
    var deal: Deal
    var onClaim: () -> Void

    var body: some View {
        let claimed = store.state.claimedDeals[deal.id] != nil
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(deal.title).font(.system(size: 16, weight: .heavy)).tracking(-0.2).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if !deal.detail.isEmpty {
                        Text(deal.detail).font(.system(size: 13)).foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                if deal.percent > 0 { DealPercentBadge(deal: deal) }
            }
            HStack(spacing: 6) {
                Text(deal.priceText).font(.system(size: 15, weight: .heavy)).foregroundStyle(Palette.ink).monospacedDigit()
                Text("·").foregroundStyle(Palette.faint)
                Text(DealStyle.scarcity(deal)).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(deal.remaining <= 10 ? DealStyle.whopInk : Palette.muted)
                    .lineLimit(1)
            }
            Button {
                Haptics.tap()
                onClaim()
            } label: {
                HStack(spacing: 8) {
                    if claimed {
                        Image(systemName: "ticket.fill").font(.system(size: 13, weight: .bold))
                        Text("View code").font(.system(size: 15, weight: .heavy))
                    } else {
                        WhopMark(size: 20)
                        Text("Claim with Whop").font(.system(size: 15, weight: .heavy))
                    }
                }
                .foregroundStyle(claimed ? Palette.ink : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(claimed ? Palette.surface2 : Palette.ink, in: Capsule())
            }
            .buttonStyle(PressStyle(scale: 0.97))
        }
        .padding(14)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(claimed ? Palette.line : DealStyle.whop.opacity(0.35), lineWidth: 1.2))
    }
}

/// The Deals block on a place: every deal for it, each claimable through Whop.
struct PlaceDealsSection: View {
    @Environment(AppStore.self) private var store
    var place: Place
    @State private var checkout: Deal?

    var body: some View {
        let deals = store.deals[place.id] ?? []
        if !deals.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("Deals").font(.system(size: 17, weight: .bold)).foregroundStyle(Palette.ink)
                    Spacer()
                    HStack(spacing: 5) {
                        WhopMark(size: 14)
                        Text("via Whop").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.muted)
                    }
                }
                ForEach(deals) { deal in
                    DealCard(deal: deal) { checkout = deal }
                }
            }
            .sheet(item: $checkout) { deal in
                WhopCheckoutSheet(deal: deal)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
        }
    }
}

/// "Deals near you" on Home: a shelf of deal cards at nearby places, closest first.
struct HomeDealsShelf: View {
    @Environment(AppStore.self) private var store
    @State private var checkout: Deal?

    var body: some View {
        let items = nearby
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Deals Near You").font(.system(size: 17, weight: .bold)).tracking(-0.3).foregroundStyle(Palette.ink)
                    Spacer()
                    HStack(spacing: 5) {
                        WhopMark(size: 14)
                        Text("Powered by Whop").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.muted)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(items, id: \.deal.id) { item in
                            HomeDealCard(deal: item.deal, place: item.place, metres: item.metres) {
                                Haptics.tap()
                                checkout = item.deal
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 28)
            .sheet(item: $checkout) { deal in
                WhopCheckoutSheet(deal: deal)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
        }
    }

    /// The best deal at each place, nearest places first.
    private var nearby: [(deal: Deal, place: Place, metres: Double)] {
        var out: [(deal: Deal, place: Place, metres: Double)] = []
        for (placeID, deals) in store.deals {
            guard let place = store.place(placeID),
                  let best = deals.filter({ $0.expiresAt > Date() }).max(by: { $0.percent < $1.percent }) else { continue }
            out.append((best, place, store.metres(to: place)))
        }
        return Array(out.sorted { $0.metres < $1.metres }.prefix(10))
    }
}

/// A photo card for one deal on the Home shelf.
struct HomeDealCard: View {
    @Environment(AppStore.self) private var store
    var deal: Deal
    var place: Place
    var metres: Double
    var onTap: () -> Void

    var body: some View {
        let claimed = store.state.claimedDeals[deal.id] != nil
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                PlacePhoto(place: place)
                    .frame(width: 200, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if deal.percent > 0 { DealPercentBadge(deal: deal, size: 11).padding(8) }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        HStack(spacing: 4) {
                            if claimed {
                                Image(systemName: "ticket.fill").font(.system(size: 10, weight: .bold))
                                Text("Claimed").font(.system(size: 11, weight: .heavy))
                            } else {
                                WhopMark(size: 14)
                                Text(deal.priceText).font(.system(size: 11, weight: .heavy)).monospacedDigit()
                            }
                        }
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 7)
                        .frame(height: 24)
                        .background(.white, in: Capsule())
                        .padding(8)
                    }
                Text(deal.title).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink).lineLimit(1).padding(.top, 4)
                Text(place.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.ink2).lineLimit(1)
                Text("\(Format.distance(metres)) · \(DealStyle.scarcity(deal))")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1)
            }
            .frame(width: 200, alignment: .leading)
            .multilineTextAlignment(.leading)
        }
        .buttonStyle(PressStyle())
    }
}
