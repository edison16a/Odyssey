//
//  EditProfilePickers.swift
//  Odyssey
//
//  The cosmetic pickers on the edit profile screen: frames, effects,
//  banners, titles and the badges shown on your profile. Owned items equip
//  on tap; locked ones carry a small lock and lead to the shop.
//

import Foundation
import SwiftUI

struct EditProfilePickers: View {
    @Environment(AppStore.self) private var store
    @Environment(ToastCenter.self) private var toast
    var onLocked: (CosmeticType) -> Void

    var body: some View {
        let me = store.me
        VStack(alignment: .leading, spacing: 0) {
            row("Frame", items: store.seed.frames.map { ($0.id, $0.name) }, type: .frame) { id in
                AvatarView(person: me, size: 44, frame: id)
                    .frame(width: 62, height: 62)
            }
            row("Profile effect", items: store.seed.effects.map { ($0.id, $0.name) }, type: .effect) { id in
                ProfileEffectCard(id: id, person: me, width: 56)
            }
            row("Banner", items: store.seed.banners.map { ($0.id, $0.name) }, type: .banner) { id in
                ProfileBannerView(id: id, showLabel: false, animated: false)
                    .frame(width: 96, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            titles
            badges
        }
    }

    private func row<Visual: View>(_ title: String, items: [(String, String)], type: CosmeticType,
                                   @ViewBuilder visual: @escaping (String) -> Visual) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).labelStyle().padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items, id: \.0) { item in
                        pick(id: item.0, name: item.1, type: type, visual: visual(item.0))
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 24)
    }

    private func pick<Visual: View>(id: String, name: String, type: CosmeticType, visual: Visual) -> some View {
        let owned = store.available(type, id)
        let on = store.isEquipped(type, id)
        return Button {
            if owned {
                store.equip(type, id)
                Haptics.tap()
            } else {
                onLocked(type)
            }
        } label: {
            VStack(spacing: 6) {
                visual.frame(height: 70)
                Text(name).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.ink).lineLimit(1)
            }
            .padding(8)
            .frame(minWidth: 84)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(on ? Palette.ink : .clear, lineWidth: 2))
            .opacity(owned ? 1 : 0.55)
            .overlay(alignment: .topTrailing) {
                if !owned {
                    Image(systemName: "lock.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 20, height: 20).background(Palette.ink, in: Circle()).padding(6)
                }
            }
        }
        .buttonStyle(PressStyle())
    }

    private var titles: some View {
        let owned = store.seed.titles.filter { store.available(.title, $0.id) || store.state.equipped.title == $0.id }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Title").labelStyle()
            FlowLayout(spacing: 8) {
                ForEach(owned) { title in
                    Button { store.equip(.title, title.id) } label: {
                        ProfileTitleText(id: title.id, text: title.name, size: 13)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(store.state.equipped.title == title.id ? Palette.ink : Palette.surface2, in: Capsule())
                    }
                    .buttonStyle(PressStyle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    /// Up to three earned badges sit on your profile.
    private var badges: some View {
        let earned = store.state.earnedBadges.compactMap { store.seed.badge($0) }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Badges on your profile").labelStyle()
            FlowLayout(spacing: 8) {
                ForEach(earned) { badge in
                    let on = store.state.equipped.badges.contains(badge.id)
                    Chip(label: badge.name, icon: badge.icon, isOn: on) { toggle(badge.id) }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    private func toggle(_ id: String) {
        if store.state.equipped.badges.contains(id) {
            store.update { s in s.equipped.badges.removeAll { $0 == id } }
        } else if store.state.equipped.badges.count >= 3 {
            toast.show("Three badges fit on your profile", icon: "medal")
        } else {
            store.update { s in s.equipped.badges.append(id) }
        }
    }
}
