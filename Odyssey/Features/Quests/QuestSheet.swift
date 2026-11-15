//
//  QuestSheet.swift
//  Odyssey
//
//  The quest sheet. Shows the rarity, the multiplied reward and who is
//  coming along. Friend quests let you pick friends to invite right here;
//  once someone joins, the check-in button unlocks.
//  Ported from features/quests/quest-sheet.js.
//

import Foundation
import SwiftUI

struct QuestSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toast
    @Environment(\.dismiss) private var dismiss
    var questID: String
    @State private var picked: Set<String> = []

    var body: some View {
        if let quest = store.seed.quest(questID), let place = store.place(quest.placeId) {
            content(quest, place)
        }
    }

    private func content(_ quest: Quest, _ place: Place) -> some View {
        let rarity = store.questRarity(quest)
        let color = Color(hex: rarity.color)
        let ready = store.questReady(quest)
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header(quest, place, rarity: rarity, color: color)
                Text(quest.title).font(.system(size: 22, weight: .bold)).tracking(-0.4).foregroundStyle(Palette.ink)
                Text("\(place.name), \(quest.ends), drops \(rarity.odds.lowercased())")
                    .font(.system(size: 13)).foregroundStyle(Palette.muted).padding(.top, 4)
                rewards(quest)
                if quest.needsFriend { team(quest, ready: ready) }
                VStack(spacing: 8) {
                    Button {
                        dismiss()
                        // Let the sheet finish closing, or the cover can fail to present.
                        let id = quest.placeId
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.present(.checkIn(placeID: id)) }
                    } label: {
                        Label(ready ? "Check in for this quest" : "Invite a friend to start", systemImage: ready ? "camera" : "lock.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ready ? .white : Palette.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(ready ? color : Palette.surface2, in: Capsule())
                    }
                    .buttonStyle(PressStyle())
                    .disabled(!ready)
                    .opacity(ready ? 1 : 0.6)
                    Button("View place") {
                        dismiss()
                        let id = quest.placeId
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.push(.place(id)) }
                    }
                    .buttonStyle(.pill(.ghost, fill: true))
                }
                .padding(.top, 16)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
    }

    private func header(_ quest: Quest, _ place: Place, rarity: QuestRarity, color: Color) -> some View {
        PlacePhoto(place: place)
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(color, lineWidth: 3))
            .overlay(alignment: .topLeading) {
                Label(rarity.label + " quest", systemImage: "diamond.fill")
                    .font(.system(size: 11, weight: .heavy)).tracking(0.6).textCase(.uppercase)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(color, in: Capsule())
                    .padding(12)
            }
            .overlay(alignment: .bottomTrailing) {
                Text("\(quest.multiplier)x").font(.system(size: 44, weight: .black)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
                    .padding(.trailing, 12).padding(.bottom, 4)
            }
            .padding(.bottom, 14)
    }

    private func rewards(_ quest: Quest) -> some View {
        let kind = ["walk": "walkthrough", "first": "be first", "visit": "check in"][quest.kind] ?? quest.kind
        return HStack(spacing: 8) {
            rewardBox(Format.number(quest.coins * quest.multiplier), "coins", coin: true)
            rewardBox("+\(quest.xp * quest.multiplier)", "XP")
            rewardBox("\(quest.multiplier)x", kind)
        }
        .padding(.vertical, 14)
    }

    private func rewardBox(_ value: String, _ label: String, coin: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if coin { CoinIcon(size: 16) }
                Text(value).font(.system(size: 17, weight: .bold)).foregroundStyle(Palette.ink)
            }
            Text(label).font(.system(size: 11)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    private func team(_ quest: Quest, ready: Bool) -> some View {
        let invites = store.questInvites(quest.id)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Bring a friend", systemImage: "person.2").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                Spacer()
                Text(ready ? "Your crew is ready" : "Needs at least one friend").font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(store.friends) { friend in friendChip(friend, state: invites[friend.id]) }
                }
            }
            if !picked.isEmpty {
                Button {
                    let ids = Array(picked).sorted()
                    picked.removeAll()
                    store.invite(quest.id, friends: ids) { id in
                        toast.show((store.person(id)?.firstName ?? "A friend") + " joined your quest", icon: "users")
                    }
                    toast.show("Invites sent", icon: "send")
                } label: {
                    Label("Invite \(picked.count) " + (picked.count == 1 ? "friend" : "friends"), systemImage: "paperplane.fill")
                }
                .buttonStyle(.pill(.outline, fill: true))
            }
        }
        .padding(14)
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(Palette.lineStrong, lineWidth: 1.5))
    }

    private func friendChip(_ friend: Person, state: String?) -> some View {
        let on = picked.contains(friend.id)
        return Button {
            if on { picked.remove(friend.id) } else { picked.insert(friend.id) }
        } label: {
            VStack(spacing: 4) {
                AvatarView(person: friend, size: 48, frame: "none")
                Text(friend.firstName).font(.system(size: 11)).foregroundStyle(Palette.ink).lineLimit(1)
            }
            .frame(width: 62)
            .padding(.vertical, 6)
            .background(on ? Palette.accentSoft : .clear, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(on ? Palette.accent : .clear, lineWidth: 2))
            .overlay(alignment: .topTrailing) {
                if let state {
                    Text(state == "joined" ? "In" : "Invited")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(state == "joined" ? Palette.success : Palette.muted, in: Capsule())
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(state != nil)
    }
}
