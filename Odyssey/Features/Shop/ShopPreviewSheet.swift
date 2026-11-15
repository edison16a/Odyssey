//
//  ShopPreviewSheet.swift
//  Odyssey
//
//  Item preview. Shows the cosmetic on your own mini profile so you can see
//  it before spending, then buys or equips it. Cosmetics never change
//  rankings. Ported from shop-preview.js.
//

import Foundation
import SwiftUI

struct ShopPreviewSheet: View {
    var item: ShopItem
    /// Called with the item after a purchase, so the shop can play the unboxing.
    var onBought: (ShopItem) -> Void

    @Environment(AppStore.self) private var store
    @Environment(ToastCenter.self) private var toast
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                mock
                info
                button
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
        .background(Palette.surface)
        // The app's toasts sit under the sheet, so "Not enough coins yet" is drawn here too.
        .overlay { ToastOverlay() }
    }

    /// A miniature profile header wearing the previewed item.
    private var mock: some View {
        let s = store.state
        let me = store.me
        let banner = item.type == .banner ? item.id : s.equipped.banner
        let frame = item.type == .frame ? item.id : s.equipped.frame
        let title = item.type == .title ? item.id : s.equipped.title
        let effect = item.type == .effect ? item.id : s.equipped.effect
        return VStack(spacing: 0) {
            ProfileBannerView(id: banner).frame(height: 96)
            AvatarView(person: me, size: 88, frame: frame)
                .padding(4)
                .background(Palette.surface2, in: Circle())
                .padding(.top, -44)
                .padding(.bottom, 10)
            Text(me.name).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
            if let lettering = ProfileTitleText(titleID: title) {
                lettering.padding(.vertical, 2)
            }
            Text("@" + me.handle).font(.system(size: 13)).foregroundStyle(Palette.muted)
        }
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background(Palette.surface2)
        .overlay { ProfileEffectView(id: effect, cornerRadius: Radius.lg) }
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.name).titleStyle(22)
                Spacer()
                Text(item.rarity.uppercased()).font(.system(size: 10, weight: .heavy)).tracking(0.6)
                    .foregroundStyle(Color.rarity(item.rarity))
            }
            if let desc = item.desc {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if item.type == .title { ProfileTitleText(id: item.id, text: item.name, size: 13) }
                    Text(desc).font(.system(size: 13)).foregroundStyle(Palette.ink2)
                }
            }
            HStack(spacing: 4) {
                Text("You have").font(.system(size: 13)).foregroundStyle(Palette.muted)
                ShopCoins(amount: store.state.wallet.coins, size: 13)
                Text(". Cosmetics never change rankings.").font(.system(size: 13)).foregroundStyle(Palette.muted)
            }
        }
        .padding(.vertical, 14)
    }

    @ViewBuilder private var button: some View {
        let owned = store.shopOwned(item)
        let earnedOnly = item.price == nil
        if store.isEquipped(item.type, item.id) {
            Button {} label: { Label("Equipped", systemImage: "checkmark") }
                .buttonStyle(.pill(.soft, fill: true))
                .disabled(true)
        } else if owned || (earnedOnly && store.shopEarned(item)) {
            Button("Equip", action: equip).buttonStyle(.pill(.primary, fill: true))
        } else if earnedOnly {
            Button {} label: { Label(lockedText, systemImage: "lock.fill") }
                .buttonStyle(.pill(.soft, fill: true))
                .disabled(true)
        } else {
            Button(action: buy) {
                HStack(spacing: 6) {
                    Text("Buy for")
                    CoinIcon(size: 16)
                    Text(Format.number(item.price ?? 0)).monospacedDigit()
                }
            }
            .buttonStyle(.pill(.accent, fill: true))
        }
    }

    private var lockedText: String {
        if let days = item.streak { return "Reach a \(days) day streak" }
        if let badge = item.earnedBy, let found = store.seed.badge(badge) { return "Earn the \(found.name) badge" }
        if item.city != nil { return "Explore \(item.city ?? "this city") to unlock" }
        if item.placeId != nil { return "Check in there to unlock" }
        return "Earn the steward badge"
    }

    private func equip() {
        store.equip(item.type, item.id)
        Haptics.tap()
        toast.show("Equipped " + item.name, icon: "check")
        dismiss()
    }

    private func buy() {
        guard let price = item.price, store.buy(item.type, item.id, price: price) else {
            Haptics.warning()
            toast.show("Not enough coins yet. Check in somewhere new to earn more.", icon: "coin")
            return
        }
        store.equip(item.type, item.id)
        Haptics.success()
        onBought(item)
    }
}
