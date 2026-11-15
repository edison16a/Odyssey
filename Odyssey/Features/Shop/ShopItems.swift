//
//  ShopItems.swift
//  Odyssey
//
//  One shape for everything the shop sells (frames, banners, effects and
//  titles), the tiles in the grid, and the tag under each tile: Equipped,
//  Owned, Explored, Earned, locked, or the coin price.
//

import Foundation
import SwiftUI

struct ShopItem: Identifiable, Hashable {
    var type: CosmeticType
    var id: String
    var name: String
    var price: Int?
    var rarity: String
    var desc: String?
    var city: String?
    var placeId: String?
    var streak: Int?
    var earnedBy: String?

    var key: String { type.rawValue + "-" + id }

    init(_ type: CosmeticType, _ item: Cosmetic) {
        self.type = type
        id = item.id
        name = item.name
        price = item.price
        rarity = item.rarity
        desc = item.desc
        streak = item.streak
        earnedBy = item.earnedBy
    }

    init(banner: Banner) {
        type = .banner
        id = banner.id
        name = banner.name
        price = banner.price
        rarity = banner.rarity
        desc = nil
        city = banner.city
        placeId = banner.placeId
        streak = banner.streak
        earnedBy = banner.earnedBy
    }

    /// Every item of a kind, in the shop's order.
    static func all(_ type: CosmeticType, store: AppStore) -> [ShopItem] {
        switch type {
        case .frame: return store.seed.frames.filter { $0.id != "none" }.map { ShopItem(.frame, $0) }
        case .banner: return store.seed.banners.map { ShopItem(banner: $0) }
        case .effect: return store.seed.effects.filter { $0.id != "none" }.map { ShopItem(.effect, $0) }
        case .title: return store.seed.titles.map { ShopItem(.title, $0) }
        }
    }

    static func find(_ type: CosmeticType, _ id: String, store: AppStore) -> ShopItem? {
        all(type, store: store).first { $0.id == id }
    }
}

extension AppStore {
    /// Earned through exploring rather than bought: a city, a landmark, a streak or a badge.
    func shopEarned(_ item: ShopItem) -> Bool {
        if item.type == .banner, let banner = seed.banner(item.id) { return earned(banner: banner) }
        guard item.price == nil, let by = item.earnedBy else { return false }
        return by == "rank" || state.earnedBadges.contains(by)
    }

    /// Owned, free, or explored: equip straight away.
    func shopOwned(_ item: ShopItem) -> Bool {
        item.price == 0 || owns(item.type, item.id) || ((item.city != nil || item.placeId != nil) && shopEarned(item))
    }
}

/// A grid tile: the item drawn the way it looks on a profile, then its name and tag.
struct ShopItemTile: View {
    @Environment(AppStore.self) private var store
    var item: ShopItem
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ShopItemVisual(item: item, size: .tile)
                    .frame(height: 74)
                Text(item.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                    .lineLimit(2).multilineTextAlignment(.center)
                if item.type == .title, let desc = item.desc {
                    Text(desc).font(.system(size: 10.5)).foregroundStyle(Palette.muted)
                        .lineLimit(2).multilineTextAlignment(.center).frame(minHeight: 26, alignment: .top)
                }
                Text(item.rarity.uppercased()).font(.system(size: 10, weight: .heavy)).tracking(0.6)
                    .foregroundStyle(Color.rarity(item.rarity))
                ShopPriceTag(item: item)
            }
            .padding(.horizontal, 6)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
        .buttonStyle(PressStyle())
    }
}

struct ShopPriceTag: View {
    @Environment(AppStore.self) private var store
    var item: ShopItem

    var body: some View {
        if store.isEquipped(item.type, item.id) {
            Tag(text: "Equipped", icon: "check", tone: .dark)
        } else if item.price == 0 || store.owns(item.type, item.id) {
            Tag(text: "Owned", tone: .success)
        } else if (item.city != nil || item.placeId != nil) && store.shopEarned(item) {
            Tag(text: "Explored", icon: "location", tone: .accent)
        } else if let price = item.price {
            ShopCoins(amount: price, size: 13)
        } else if store.shopEarned(item) {
            Tag(text: "Earned", icon: "star-fill", tone: .gold)
        } else {
            Tag(text: item.streak.map { "\($0) day streak" } ?? "Earned only", icon: "lock")
        }
    }
}

/// A coin amount with the glyph, for prices and pills.
struct ShopCoins: View {
    var amount: Int
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 4) {
            CoinIcon(size: size + 2)
            Text(Format.number(amount)).font(.system(size: size, weight: .bold)).monospacedDigit()
        }
        .foregroundStyle(Palette.ink)
    }
}

/// How an item looks on a profile, at tile, preview or unboxing size.
struct ShopItemVisual: View {
    enum Size { case tile, big }
    @Environment(AppStore.self) private var store
    var item: ShopItem
    var size: Size

    var body: some View {
        let me = store.me
        let big = size == .big
        switch item.type {
        case .frame:
            AvatarView(person: me, size: big ? 132 : 52, frame: item.id)
                .frame(width: big ? 180 : 72, height: big ? 180 : 72)
        case .banner:
            ProfileBannerView(id: item.id, showLabel: big, animated: big)
                .frame(width: big ? 300 : 92, height: big ? 150 : 56)
                .clipShape(RoundedRectangle(cornerRadius: big ? 20 : 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: big ? 20 : 12, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
        case .effect:
            ProfileEffectCard(id: item.id, person: me, width: big ? 170 : 62)
        case .title:
            ProfileTitleText(id: item.id, text: item.name, size: big ? 30 : 13)
                .padding(.horizontal, big ? 24 : 8)
                .frame(minHeight: big ? 80 : 40)
                .background(.white, in: RoundedRectangle(cornerRadius: big ? 20 : 12, style: .continuous))
                .minimumScaleFactor(0.6)
        }
    }
}
