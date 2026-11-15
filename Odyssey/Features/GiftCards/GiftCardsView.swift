//
//  GiftCardsView.swift
//  Odyssey
//
//  Gift cards. Both balances, the cards you already redeemed and every
//  brand. Coins buy cards at the steep coin rate; bounty cash from local
//  businesses buys them dollar for dollar. The same section sits inside
//  the shop. Ported from gift-cards.js.
//

import Foundation
import SwiftUI

struct GiftCardsView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Gift cards", back: { router.pop() })
            ScrollView {
                GiftCardsSection()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
        .background(Palette.surface)
    }
}

struct GiftCardsSection: View {
    @Environment(AppStore.self) private var store
    @State private var redeeming: GiftCard?
    @State private var showing: AppState.RedeemedCard?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            balances
            mine
            SectionHeader(title: "Redeem").padding(.top, 24)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                ForEach(store.seed.giftCards) { brand in tile(brand) }
            }
        }
        .sheet(item: $redeeming) { brand in
            GiftCardSheet(brand: brand)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(item: $showing) { card in
            if let brand = store.seed.giftCards.first(where: { $0.id == card.brand }) {
                GiftCardCodeView(brand: brand, card: card)
                    .overlay { ToastOverlay() }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
        }
    }

    private var balances: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                balance(icon: AnyView(CoinIcon(size: 20)), value: Format.number(store.state.wallet.coins), caption: "coins",
                        background: Palette.surface2)
                balance(icon: AnyView(Image(systemName: "dollarsign").font(.system(size: 17, weight: .bold)).foregroundStyle(Color(hex: "#0f7a43"))),
                        value: Format.money(store.state.wallet.cash), caption: "bounty cash", background: Color(hex: "#e8f7ee"))
            }
            Text("\(Format.number(store.seed.coinsPerDollar)) coins buy $1 of gift card. Bounty cash from local businesses redeems dollar for dollar.")
                .font(.system(size: 11)).foregroundStyle(Palette.muted).padding(.horizontal, 2)
        }
    }

    private func balance(icon: AnyView, value: String, caption: String, background: Color) -> some View {
        HStack(spacing: 10) {
            icon.frame(width: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.system(size: 18, weight: .bold)).tracking(-0.4).monospacedDigit().foregroundStyle(Palette.ink)
                Text(caption).font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(background, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    @ViewBuilder private var mine: some View {
        let cards = store.state.giftCards
        if !cards.isEmpty {
            SectionHeader(title: "Your gift cards").padding(.top, 24)
            VStack(spacing: 8) {
                ForEach(cards) { card in
                    if let brand = store.seed.giftCards.first(where: { $0.id == card.brand }) {
                        Button { showing = card } label: {
                            HStack(spacing: 12) {
                                GiftCardFace(brand: brand, amount: nil).frame(width: 64)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(brand.name) $\(card.amount)").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                                    Text(String(card.code.prefix(4)) + "-****-****").font(.system(size: 11)).monospacedDigit().foregroundStyle(Palette.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.faint)
                            }
                            .padding(10)
                            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        }
                        .buttonStyle(PressStyle())
                    }
                }
            }
        }
    }

    private func tile(_ brand: GiftCard) -> some View {
        let low = brand.amounts.min() ?? 10
        return Button { redeeming = brand } label: {
            VStack(alignment: .leading, spacing: 4) {
                GiftCardFace(brand: brand, amount: nil)
                    .overlay(alignment: .topLeading) {
                        if let tag = brand.tag { Tag(text: tag, tone: .dark).padding(6) }
                    }
                Text(brand.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink).padding(.top, 4)
                HStack(spacing: 4) {
                    CoinIcon(size: 12)
                    Text("from " + Format.compact(store.giftCardPrice(low))).font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
            }
        }
        .buttonStyle(PressStyle())
    }
}

/// A gift card face: brand color, white logo, optional amount and a little chip.
struct GiftCardFace: View {
    var brand: GiftCard
    var amount: Int?
    var big = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: big ? 18 : 12, style: .continuous).fill(Color(hex: brand.color))
            if let accent = brand.accent {
                Circle().fill(Color(hex: accent).opacity(0.5)).frame(width: big ? 220 : 90).blur(radius: big ? 40 : 18)
                    .offset(x: big ? 120 : 50, y: big ? -80 : -36)
            }
            Image(Media.name(for: brand.logo))
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .frame(maxWidth: big ? 100 : 46, maxHeight: big ? 60 : 28)
        }
        .overlay(alignment: .bottomLeading) {
            if big || amount != nil {
                RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#e0c278")).frame(width: 18, height: 13).opacity(0.85).padding(10)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let amount {
                Text("$\(amount)").font(.system(size: big ? 20 : 15, weight: .bold)).foregroundStyle(.white).padding(.trailing, 10).padding(.bottom, 8)
            }
        }
        .aspectRatio(1.586, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: big ? 18 : 12, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 6)
    }
}
