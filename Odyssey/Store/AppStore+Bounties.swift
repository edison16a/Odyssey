//
//  AppStore+Bounties.swift
//  Odyssey
//
//  Business bounties. A business puts up a pool for walkthroughs of a place
//  or an area; explorers who record one there are paid in bounty cash,
//  either per video or as an even split of the pool across the crew. You
//  can also post your own bounty as a business. Ported from
//  services/bounties.js and services/gift-cards.js.
//

import Foundation

struct BountyPayout {
    var bounty: Bounty
    var amount: Double
    var first: Bool
    var pending: Double
}

extension AppStore {
    var extras: SeedExtras { SeedExtras.shared }

    private func roundCash(_ n: Double) -> Double { (n * 100).rounded() / 100 }

    /// Every bounty, yours first, with your progress folded in.
    var bounties: [Bounty] {
        let mine = Set(state.myBounties.map(\.id))
        let liveIDs = Set(liveBounties.map(\.id))
        let local = state.myBounties.filter { !liveIDs.contains($0.id) }
        let live = liveBounties.map { value in
            var out = value
            if mine.contains(value.id) { out.mine = true }
            return out
        }
        var seen: Set<String> = []
        return (local + live + extras.bounties).filter { seen.insert($0.id).inserted }.map { b in
            var out = b
            let p = state.bountyProgress[b.id] ?? AppState.BountyProgress()
            if p.recorded > 0 && !b.crew.contains("me") { out.crew = b.crew + ["me"] }
            out.recorded = min(b.videos, b.recorded + p.recorded)
            out.earned = p.earned
            return out
        }
    }

    func bounty(_ id: String) -> Bounty? { bounties.first { $0.id == id } }

    var openBounties: [Bounty] { bounties.filter { $0.active != false && !$0.isExpired && $0.recorded < ($0.maxExplorers ?? $0.videos) } }

    var myPostedBounties: [Bounty] { bounties.filter { $0.mine == true } }

    /// What one walkthrough pays: a share per video, or an even slice of the pool.
    func bountySlice(_ b: Bounty) -> Double {
        if let maximum = b.maxExplorers {
            return floor(b.pool * 100 / Double(max(1, maximum))) / 100
        }
        if b.split == "even" {
            return roundCash(b.pool / Double(max(1, b.crew.count + (b.crew.contains("me") ? 0 : 1))))
        }
        return roundCash((b.pool - b.firstBonus) / Double(max(1, b.videos)))
    }

    func bountyPaidOut(_ b: Bounty) -> Double {
        b.split == "even" ? 0 : Double(b.recorded) * bountySlice(b) + (b.recorded > 0 ? b.firstBonus : 0)
    }

    func bountyLeft(_ b: Bounty) -> Double { roundCash(b.pool - bountyPaidOut(b)) }

    /// The open bounty that covers a place, by place first, then by area.
    func bounty(for place: Place) -> Bounty? {
        let list = openBounties
        return list.first { bounty in
            guard bounty.target.kind == "place" else { return false }
            if bounty.target.placeId == place.id { return true }
            // A venue can have an Apple Maps ID on one phone and an OSM ID on another.
            let name = bounty.target.place?.name ?? bounty.target.name ?? ""
            return !name.isEmpty && bounty.center.distance(to: place.coords) <= 40 &&
                name.compare(place.name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
            ?? list.first { ["area", "street", "city"].contains($0.target.kind) && $0.center.distance(to: place.coords) <= $0.radius }
    }

    /// Pay out for a walkthrough recorded at a place, if a bounty covers it.
    func bountyPayout(for place: Place) -> BountyPayout? {
        guard let b = bounty(for: place), !b.isFunded, !b.isExpired else { return nil }
        let first = b.recorded == 0 && b.firstBonus > 0
        let amount = b.split == "even" ? 0 : roundCash(bountySlice(b) + (first ? b.firstBonus : 0))
        update { s in
            let p = s.bountyProgress[b.id] ?? AppState.BountyProgress()
            s.bountyProgress[b.id] = AppState.BountyProgress(recorded: p.recorded + 1, earned: roundCash(p.earned + amount))
            s.wallet.cash = roundCash(s.wallet.cash + amount)
        }
        let updated = bounty(b.id) ?? b
        return BountyPayout(bounty: updated, amount: amount, first: first, pending: b.split == "even" ? bountySlice(updated) : 0)
    }

    /// A bounty paid through Whop: the server already has it live, so just show it as yours.
    func addPaidBounty(_ paid: Bounty) {
        var b = paid
        b.mine = true
        update { s in
            s.myBounties.removeAll { $0.id == b.id }
            s.myBounties.insert(b, at: 0)
        }
    }

    // MARK: Gift cards paid with coins or bounty cash

    func canPay(_ amount: Int, cash: Bool) -> Bool {
        cash ? state.wallet.cash >= Double(amount) : state.wallet.coins >= giftCardPrice(amount)
    }

    /// Redeem a gift card with coins or with bounty cash.
    func redeem(_ card: GiftCard, amount: Int, cash: Bool) -> AppState.RedeemedCard? {
        guard canPay(amount, cash: cash) else { return nil }
        let letters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let code = (0..<4).map { _ in String((0..<4).map { _ in letters.randomElement()! }) }.joined(separator: "-")
        let redeemed = AppState.RedeemedCard(id: "gc-\(Int(Date().timeIntervalSince1970 * 1000))", brand: card.id,
                                             amount: amount, code: code, date: Format.today())
        update { s in
            if cash { s.wallet.cash = ((s.wallet.cash - Double(amount)) * 100).rounded() / 100 }
            else { s.wallet.coins -= giftCardPrice(amount) }
            s.giftCards.insert(redeemed, at: 0)
        }
        Cloud.shared.recordGiftCard(redeemed)
        return redeemed
    }
}
