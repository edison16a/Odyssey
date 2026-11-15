//
//  FriendsTab.swift
//  Odyssey
//
//  Friends tab. A map of where your friends explored, one hex color per
//  friend, with their faces underneath to show one at a time, then your
//  friends list and a way to add more.
//

import Foundation
import SwiftUI

struct FriendsTab: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var focus: String?

    var body: some View {
        let friends = store.friends
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header.id("top")
                    if !friends.isEmpty {
                        section("Where friends explored") {
                            Button { router.push(.friendsMap) } label: {
                                FriendsHexMap(ids: friends.map(\.id), focus: focus)
                                    .frame(height: 300)
                                    .allowsHitTesting(false)
                                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
                                    .overlay(alignment: .topTrailing) {
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Palette.ink)
                                            .frame(width: 30, height: 30)
                                            .background(.white.opacity(0.95), in: Circle())
                                            .padding(10)
                                    }
                                    .contentShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                            }
                            .buttonStyle(PressStyle(scale: 0.99))
                        }
                        FriendsLegend(people: friends, focus: $focus).padding(.top, Space.s3)
                    }
                    section("Your friends", link: friends.isEmpty ? nil : "\(friends.count)") {
                        friendList(friends)
                    }
                    TabBarSpacer()
                }
            }
            .background(Palette.surface)
            .onChange(of: router.scrollToTop[.friends] ?? 0) { _, _ in
                withAnimation { proxy.scrollTo("top", anchor: .top) }
            }
        }
    }

    private var header: some View {
        HStack(spacing: Space.s2) {
            Text("Friends").titleStyle(30).frame(maxWidth: .infinity, alignment: .leading)
            IconButton(icon: "plus", label: "Add friends") { router.push(.addFriends) }
        }
        .padding(.horizontal, Space.s5)
        .padding(.top, 6)
        .padding(.bottom, Space.s3)
    }

    private func section<Content: View>(_ title: String, link: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: title, link: link)
            content()
        }
        .padding(.horizontal, Space.s5)
        .padding(.top, Space.s5)
    }

    private func friendList(_ friends: [Person]) -> some View {
        VStack(spacing: 0) {
            ForEach(friends) { friend in
                Button { router.push(.person(friend.id)) } label: {
                    HStack(spacing: Space.s3) {
                        AvatarView(person: friend, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(friend.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                            Text(placesLabel(store.exploredPlaces(of: friend.id).count))
                                .font(.system(size: 13)).foregroundStyle(Palette.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Circle().fill(store.friendColor(friend.id)).frame(width: 12, height: 12)
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.faint)
                    }
                    .padding(.vertical, Space.s3)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Rectangle().fill(Palette.line).frame(height: 1)
            }
            Button { router.push(.addFriends) } label: {
                HStack(spacing: Space.s3) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                        .frame(width: 44, height: 44)
                        .background(Palette.accentSoft, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add friends").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                        Text(friends.isEmpty ? "See where your friends explore" : "Find people you know")
                            .font(.system(size: 13)).foregroundStyle(Palette.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.faint)
                }
                .padding(.vertical, Space.s3)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func placesLabel(_ n: Int) -> String {
        n == 1 ? "Explored 1 place" : "Explored \(n) places"
    }
}
