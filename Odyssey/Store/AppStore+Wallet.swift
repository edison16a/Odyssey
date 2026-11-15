//
//  AppStore+Wallet.swift
//  Odyssey
//
//  Coins, purchases and equipped cosmetics. Owned items are stored as
//  "<type>-<id>" strings (frame-fire, banner-city-berkeley, title-wanderer)
//  so one list covers every kind. Spending never touches XP or ranking
//  points. Ported from services/wallet.js and services/gift-cards.js.
//

import Foundation

enum CosmeticType: String, CaseIterable {
    case frame, banner, effect, title

    var label: String {
        switch self {
        case .frame: return "Frames"
        case .banner: return "Banners"
        case .effect: return "Effects"
        case .title: return "Titles"
        }
    }
}

extension AppStore {
    func owns(_ type: CosmeticType, _ id: String) -> Bool {
        state.owned.contains("\(type.rawValue)-\(id)")
    }

    /// Earned cosmetics: a city banner for a city you explored, a landmark banner
    /// for a place you checked in at, streak frames and banners for the badge.
    func earned(banner: Banner) -> Bool {
        if let city = banner.city { return seed.travel.trails[city] != nil }
        if let placeId = banner.placeId { return state.visited.contains(placeId) }
        if let badge = banner.earnedBy { return state.earnedBadges.contains(badge) }
        return false
    }

    func earned(_ item: Cosmetic) -> Bool {
        guard item.price == nil else { return false }
        guard let by = item.earnedBy else { return false }
        return by == "rank" || state.earnedBadges.contains(by)
    }

    /// Whether you can use an item: bought, free, or earned.
    func available(_ type: CosmeticType, _ id: String) -> Bool {
        if owns(type, id) { return true }
        switch type {
        case .banner:
            guard let banner = seed.banner(id) else { return false }
            return earned(banner: banner)
        case .frame: return seed.frames.first { $0.id == id }.map { $0.price == 0 || earned($0) } ?? false
        case .effect: return seed.effects.first { $0.id == id }.map { $0.price == 0 || earned($0) } ?? false
        case .title: return seed.titles.first { $0.id == id }.map { $0.price == 0 || earned($0) } ?? false
        }
    }

    func earn(_ amount: Int) {
        update { s in s.wallet.coins += amount }
    }

    /// Buy an item. Returns false when the balance is too low.
    @discardableResult
    func buy(_ type: CosmeticType, _ id: String, price: Int) -> Bool {
        if owns(type, id) { return true }
        guard state.wallet.coins >= price else { return false }
        update { s in
            s.wallet.coins -= price
            s.owned.append("\(type.rawValue)-\(id)")
        }
        return true
    }

    func equip(_ type: CosmeticType, _ id: String) {
        update { s in
            switch type {
            case .frame: s.equipped.frame = id
            case .banner: s.equipped.banner = id
            case .effect: s.equipped.effect = id
            case .title: s.equipped.title = id
            }
        }
    }

    func isEquipped(_ type: CosmeticType, _ id: String) -> Bool {
        switch type {
        case .frame: return state.equipped.frame == id
        case .banner: return state.equipped.banner == id
        case .effect: return state.equipped.effect == id
        case .title: return state.equipped.title == id
        }
    }

    /// A pretend coin pack. No payment is started anywhere.
    func buyPack(_ pack: CoinPack) { earn(pack.coins) }

    @discardableResult
    func buyBoost(_ boost: Boost) -> Bool {
        guard state.wallet.coins >= boost.price else { return false }
        update { s in
            s.wallet.coins -= boost.price
            s.boosts[boost.id, default: 0] += 1
        }
        return true
    }

    func giftCardPrice(_ amount: Int) -> Int { Int(Double(amount) * seed.coinsPerDollar) }

    /// Redeem coins for a gift card code. Returns nil when the balance is too low.
    func redeem(_ card: GiftCard, amount: Int) -> AppState.RedeemedCard? {
        let price = giftCardPrice(amount)
        guard state.wallet.coins >= price else { return nil }
        let letters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let code = (0..<3).map { _ in String((0..<4).map { _ in letters.randomElement()! }) }.joined(separator: "-")
        let redeemed = AppState.RedeemedCard(id: UUID().uuidString, brand: card.id, amount: amount, code: code, date: Format.today())
        update { s in
            s.wallet.coins -= price
            s.giftCards.insert(redeemed, at: 0)
        }
        return redeemed
    }
}
