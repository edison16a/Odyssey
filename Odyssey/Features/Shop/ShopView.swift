//
//  ShopView.swift
//  Odyssey
//
//  The coin shop. Sections for frames, banners, profile effects, titles,
//  gift cards, boosts and coin packs. Tapping an item opens a preview on
//  your own mini profile before buying, and owned items equip from the
//  same sheet. A purchase ends in the unboxing. Ported from shop.js.
//

import Foundation
import SwiftUI

struct ShopView: View {
    var initialTab: String?

    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toast
    @State private var section = "frame"
    @State private var preview: ShopItem?
    @State private var unboxing: ShopItem?
    @State private var pendingUnbox: ShopItem?
    @State private var bump = false

    private static let sections: [(String, String)] = [
        ("frame", "Frames"), ("banner", "Banners"), ("effect", "Effects"), ("title", "Titles"),
        ("gift", "Gift cards"), ("boost", "Boosts"), ("coins", "Coins"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Shop", back: { router.pop() }) { coinPill }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ShopView.sections, id: \.0) { item in
                        Chip(label: item.1, isOn: section == item.0) { section = item.0 }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, Space.s3)
            ScrollView {
                content
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
            }
        }
        .background(Palette.surface)
        .onAppear {
            if let initialTab, ShopView.sections.contains(where: { $0.0 == initialTab }) { section = initialTab }
        }
        .sheet(item: $preview, onDismiss: {
            // The unboxing waits until the sheet has fully gone; presenting during the slide down can be dropped.
            if let bought = pendingUnbox {
                pendingUnbox = nil
                unboxing = bought
            }
        }) { item in
            ShopPreviewSheet(item: item) { bought in
                pendingUnbox = bought
                preview = nil
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .fullScreenCover(item: $unboxing) { item in
            ShopUnboxView(item: item)
        }
    }

    private var coinPill: some View {
        HStack(spacing: 6) {
            CoinIcon(size: 18)
            Text(Format.number(store.state.wallet.coins)).font(.system(size: 14, weight: .bold)).monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Palette.surface2, in: Capsule())
        .scaleEffect(bump ? 1.12 : 1)
    }

    @ViewBuilder private var content: some View {
        switch section {
        case "boost": boosts
        case "coins": packs
        case "gift": GiftCardsSection()
        default:
            let type = CosmeticType(rawValue: section) ?? .frame
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.s2, alignment: .top), count: 3), spacing: Space.s2) {
                ForEach(ShopItem.all(type, store: store)) { item in
                    ShopItemTile(item: item) { preview = item }
                }
            }
        }
    }

    private var boosts: some View {
        VStack(spacing: 0) {
            ForEach(store.seed.boosts) { boost in
                HStack(spacing: Space.s3) {
                    Image(systemName: Icon.symbol(boost.icon)).font(.system(size: 18, weight: .semibold))
                        .frame(width: 40, height: 40).background(Palette.surface2, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(boost.name).font(.system(size: 15, weight: .semibold))
                            if let banked = store.state.boosts[boost.id], banked > 0 { Tag(text: "x\(banked) banked") }
                        }
                        Text(boost.desc).font(.system(size: 13)).foregroundStyle(Palette.muted)
                    }
                    Spacer(minLength: 0)
                    Button {
                        if store.buyBoost(boost) { toast.show(boost.name + " banked", icon: "bolt") }
                        else { toast.show("Not enough coins yet", icon: "coin") }
                    } label: {
                        HStack(spacing: 4) { CoinIcon(size: 13); Text(Format.number(boost.price)) }
                    }
                    .buttonStyle(.pill(.primary, height: 36))
                }
                .foregroundStyle(Palette.ink)
                .padding(.vertical, Space.s3)
                Divider().overlay(Palette.line)
            }
        }
    }

    private var packs: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: Space.s2) {
                ForEach(store.seed.coinPacks) { pack in
                    Button {
                        store.buyPack(pack)
                        toast.show("+\(Format.number(pack.coins)) coins added", icon: "coin")
                        Haptics.success()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { bump = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { withAnimation { bump = false } }
                    } label: {
                        VStack(spacing: 8) {
                            CoinIcon(size: 34)
                            Text(Format.number(pack.coins)).font(.system(size: 20, weight: .bold)).monospacedDigit()
                            Text(pack.price).font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 16).frame(height: 36).background(Palette.surface2, in: Capsule())
                        }
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 22)
                        .padding(.bottom, 14)
                        .background(Palette.goldSoft, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .padding(.top, 12)
            Text("Rankings and first explorer credit can never be bought.")
                .font(.system(size: 11)).foregroundStyle(Palette.faint)
        }
    }
}
