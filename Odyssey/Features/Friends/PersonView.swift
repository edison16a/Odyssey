//
//  PersonView.swift
//  Odyssey
//
//  Someone else's profile, laid out like a creator profile: banner photo,
//  framed avatar, name, rank chip, four stats and actions, then who they
//  explore like, their rank roadmap and their posts or places.
//  Ported from profile-view.js and the person route in profile-tab.js.
//

import Foundation
import SwiftUI

struct PersonView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toast
    @Environment(RewardPopCenter.self) private var pop

    var personID: String
    @State private var tab = "posts"

    var body: some View {
        if let person = store.person(personID) {
            ScrollView {
                VStack(spacing: 0) {
                    banner(person)
                    header(person)
                    if let icon = person.icon, let explorer = store.seed.explorer(icon) {
                        ProfileExplorerCard(explorer: explorer, eyebrow: "Explores like")
                            .padding(.horizontal, Space.s5).padding(.top, Space.s5)
                    }
                    ProfileRoadmap(xp: person.xp) { router.push(.ranks) }
                        .padding(.horizontal, Space.s5).padding(.top, Space.s5)
                    FriendsPersonContent(person: person, tab: $tab).padding(.top, Space.s5)
                    Color.clear.frame(height: 40)
                }
            }
            .background(Palette.surface)
            .ignoresSafeArea(edges: .top)
            .overlay {
                ProfileEffectView(id: person.effect ?? "none", cornerRadius: 44)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) {
                IconButton(icon: "back", kind: .dark, label: "Back") { router.pop() }
                    .padding(.leading, Space.s4)
                    .padding(.top, 4)
            }
        } else {
            VStack {
                NavHeader(title: "Explorer", back: { router.pop() })
                Spacer()
                Text("This explorer is not on Odyssey anymore.").mutedStyle()
                Spacer()
            }
        }
    }

    private func banner(_ person: Person) -> some View {
        ProfileBannerView(id: person.banner ?? "city-berkeley")
            .frame(height: 170 + 54)
            .frame(maxWidth: .infinity)
            .clipped()
    }

    private func header(_ person: Person) -> some View {
        let rank = store.seed.ranks[min(person.rank, store.seed.ranks.count - 1)]
        return VStack(spacing: 0) {
            AvatarView(person: person, size: 96)
                .padding(5)
                .background(Palette.surface, in: Circle())
                .padding(.bottom, 10)
            Text(person.name).font(.system(size: 24, weight: .heavy)).tracking(-0.5).foregroundStyle(Palette.ink)
            Text("@" + person.handle).font(.system(size: 13)).foregroundStyle(Palette.muted).padding(.top, 2)
            Button { router.push(.ranks) } label: {
                HStack(spacing: 6) {
                    RankEmblem(tier: person.rank, size: 18, inverse: true)
                    Text(rank.name)
                    Text("\(person.xp) XP")
                        .fontWeight(.semibold)
                        .opacity(0.85)
                        .padding(.leading, 8)
                        .overlay(alignment: .leading) { Rectangle().fill(.white.opacity(0.35)).frame(width: 1) }
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.leading, 6)
                .padding(.trailing, 12)
                .frame(height: 30)
                .background(Color(hex: rank.color), in: Capsule())
            }
            .buttonStyle(PressStyle())
            .padding(.top, 10)
            Text(person.bio)
                .font(.system(size: 13))
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
                .padding(.top, 8)
                .padding(.bottom, 14)
            stats(person).padding(.bottom, 14)
            actions(person)
        }
        .padding(.horizontal, Space.s5)
        .padding(.top, -52)
    }

    private func stats(_ person: Person) -> some View {
        let friends = 40 + person.contributions * 3
        return HStack(spacing: 0) {
            stat(Format.compact(friends), "Friends")
            divider
            stat("\(person.explored)", "Explored")
            divider
            stat("\(person.contributions)", "Walkthroughs")
            divider
            stat("#\(cityRank(person))", store.home.city)
        }
    }

    private var divider: some View { Rectangle().fill(Palette.line).frame(width: 1, height: 34) }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 19, weight: .bold)).tracking(-0.4).monospacedDigit().foregroundStyle(Palette.ink)
            Text(label).font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    /// Seeded explorers rank by XP, matching the order on the city board.
    private func cityRank(_ person: Person) -> Int {
        (store.seed.people.sorted { $0.xp > $1.xp }.firstIndex { $0.id == person.id } ?? 0) + 1
    }

    private func actions(_ person: Person) -> some View {
        HStack(spacing: Space.s2) {
            if store.isFriend(person.id) {
                Button {} label: { Label("Friends", systemImage: "checkmark") }
                    .buttonStyle(.pill(.soft, height: 44, fill: true))
            } else {
                Button {
                    store.addFriend(person.id)
                    pop.friendAdded(person.id, store: store)
                } label: { Label("Add friend", systemImage: "plus") }
                    .buttonStyle(.pill(.primary, height: 44, fill: true))
            }
            Button {
                toast.show("Messages open in the full app", icon: "chat")
            } label: { Label("Message", systemImage: "bubble.left") }
                .buttonStyle(.pill(.soft, height: 44))
        }
    }
}
