//
//  GiftCardSheet.swift
//  Odyssey
//
//  Redeem one brand. Pick an amount, see how far your coins are from it,
//  then pay with coins or bounty cash. A redeemed card shows its code.
//  Ported from gift-card-sheet.js.
//

import Foundation
import SwiftUI
import UIKit

struct GiftCardSheet: View {
    var brand: GiftCard

    @Environment(AppStore.self) private var store
    @Environment(ToastCenter.self) private var toast
    @State private var amount = 0
    @State private var redeemed: AppState.RedeemedCard?

    var body: some View {
        Group {
            if let redeemed {
                GiftCardCodeView(brand: brand, card: redeemed)
                    .overlay { ConfettiView(count: 50).allowsHitTesting(false) }
            } else {
                picker
            }
        }
        .onAppear { if amount == 0 { amount = brand.amounts.first ?? 10 } }
        // The app's toasts sit under the sheet, so "Code copied" is drawn here too.
        .overlay { ToastOverlay() }
    }

    private var picker: some View {
        let cost = store.giftCardPrice(amount)
        let coins = store.state.wallet.coins
        let short = cost - coins
        let progress = cost > 0 ? min(1, Double(coins) / Double(cost)) : 0
        let cash = store.state.wallet.cash
        return ScrollView {
            VStack(spacing: 14) {
                GiftCardFace(brand: brand, amount: amount, big: true).frame(maxWidth: 290)
                Text("\(brand.name) gift card").titleStyle(22)
                HStack(spacing: 8) {
                    ForEach(brand.amounts, id: \.self) { value in
                        Button { amount = value } label: {
                            VStack(spacing: 2) {
                                Text("$\(value)").font(.system(size: 15, weight: .bold))
                                Text(Format.compact(store.giftCardPrice(value)) + " coins").font(.system(size: 10))
                                    .foregroundStyle(amount == value ? .white.opacity(0.75) : Palette.muted)
                            }
                            .foregroundStyle(amount == value ? .white : Palette.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(amount == value ? Palette.ink : Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        }
                        .buttonStyle(PressStyle())
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        HStack(spacing: 4) {
                            CoinIcon(size: 14)
                            Text("\(Format.number(coins)) of \(Format.number(cost))").font(.system(size: 13, weight: .bold))
                        }
                        Spacer()
                        Text("\(Int(progress * 100))%").font(.system(size: 13)).foregroundStyle(Palette.muted)
                    }
                    ProgressBar(value: progress, color: Palette.gold)
                }
                Button(short > 0 ? "\(Format.number(short)) more coins to go" : "Redeem for \(Format.number(cost)) coins") {
                    finish(store.redeem(brand, amount: amount, cash: false))
                }
                .buttonStyle(.pill(.primary, fill: true))
                .disabled(!store.canPay(amount, cash: false))
                Button { finish(store.redeem(brand, amount: amount, cash: true)) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign")
                        Text("Use \(Format.money(Double(amount))) of bounty cash")
                        Text("(\(Format.money(cash)) left)").foregroundStyle(Palette.muted)
                    }
                }
                .buttonStyle(.pill(.soft, fill: true))
                .disabled(!store.canPay(amount, cash: true))
                Text("Gift cards are the one thing coins can turn into outside the app, so they take real exploring to earn.")
                    .font(.system(size: 11)).foregroundStyle(Palette.faint).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 20)
        }
    }

    private func finish(_ card: AppState.RedeemedCard?) {
        guard let card else {
            toast.show("Not enough yet", icon: "coin")
            return
        }
        Haptics.success()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { redeemed = card }
    }
}

/// The code of a redeemed card, with a copy button.
struct GiftCardCodeView: View {
    var brand: GiftCard
    var card: AppState.RedeemedCard
    @Environment(ToastCenter.self) private var toast

    var body: some View {
        VStack(spacing: 12) {
            GiftCardFace(brand: brand, amount: card.amount, big: true).frame(maxWidth: 290)
            Text("Your \(brand.name) gift card").labelStyle().padding(.top, 6)
            Text(card.code).font(.system(size: 24, weight: .heavy, design: .monospaced)).foregroundStyle(Palette.ink)
            Button {
                UIPasteboard.general.string = card.code
                toast.show("Code copied", icon: "check")
            } label: {
                Label("Copy code", systemImage: "link")
            }
            .buttonStyle(.pill(.primary, fill: true))
            Text("Saved under Your gift cards. Redeem it at \(brand.name).")
                .font(.system(size: 11)).foregroundStyle(Palette.faint).multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
    }
}
