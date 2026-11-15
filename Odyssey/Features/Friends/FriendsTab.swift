//
//  FriendsTab.swift
//  Odyssey
//
//  Friends tab. Story bubbles across the top (a blue ring means new
//  activity, grey means seen), then the pair up offer, a map of places
//  friends explored with their photos, a weekly board and the feed.
//  Ported from friends-tab.js.
//

import Foundation
import SwiftUI

struct FriendsTab: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header.id("top")
                    storiesRow
                    pairBanner.padding(.horizontal, Space.s5).padding(.top, Space.s5)
                    section("Where friends explored", link: "Opt-in friends only") {
                        Button { router.push(.friendsMap) } label: {
                            FriendsMapPreview()
                                .frame(height: 230)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
                        }
                        .buttonStyle(PressStyle(scale: 0.99))
                    }
                    section("This week", link: "Friends board") { weekly }
                    section("Activity", link: nil) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(store.feed) { post in FriendsPostCard(post: post) }
                        }
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

    private func section<Content: View>(_ title: String, link: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: title, link: link)
            content()
        }
        .padding(.horizontal, Space.s5)
        .padding(.top, Space.s5)
    }

    // MARK: Stories

    private var storiesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                myBubble
                ForEach(store.storyPeople, id: \.self) { id in
                    if let friend = store.person(id) { bubble(friend) }
                }
            }
            .padding(.horizontal, Space.s5)
            .padding(.vertical, 8)
        }
    }

    private var myBubble: some View {
        let mine = !store.posts(by: "me").isEmpty
        return Button {
            router.present(mine ? .story(personID: "me", postID: nil) : .checkIn(placeID: nil))
        } label: {
            VStack(spacing: 6) {
                AvatarView(person: store.me, size: 64, frame: "none", ring: mine ? .new : .none)
                    .overlay(alignment: .bottomTrailing) {
                        if !mine {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(Palette.accent, in: Circle())
                                .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                                .offset(x: 2, y: 2)
                        }
                    }
                    .padding(5)
                Text("Your adventure").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
            }
            .frame(width: 74)
        }
        .buttonStyle(PressStyle(scale: 0.94))
    }

    private func bubble(_ friend: Person) -> some View {
        let fresh = store.posts(by: friend.id).contains { ["walk", "milestone", "day"].contains($0.kind) }
        let ring: AvatarView.Ring = store.seen(friend.id) ? .seen : (fresh ? .new : .seen)
        return Button {
            router.present(.story(personID: friend.id, postID: nil))
        } label: {
            VStack(spacing: 6) {
                AvatarView(person: friend, size: 64, frame: "none", ring: ring).padding(5)
                Text(friend.firstName).font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
            }
            .frame(width: 74)
        }
        .buttonStyle(PressStyle(scale: 0.94))
    }

    // MARK: Pair up

    private var pairBanner: some View {
        let faces = ["diego", "nina"].compactMap { store.seed.person($0) }
        let link = URL(string: "https://pathy.app/pair/\(store.state.user.handle)") ?? URL(string: "https://pathy.app")!
        return HStack(spacing: 12) {
            HStack(spacing: -10) {
                ForEach(faces) { face in
                    AvatarView(person: face, size: 30, frame: "none")
                        .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2))
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Explore with a friend for 2x coins").font(.system(size: 15, weight: .bold))
                Text("Check in at the same place together and you both earn double.")
                    .font(.system(size: 13))
                    .opacity(0.75)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ShareLink(item: link, subject: Text("Explore with me on Odyssey"),
                      message: Text("Check in with me on Odyssey and we both earn double coins.")) {
                Text("Invite")
            }
            .buttonStyle(.pill(.light, height: 36))
        }
        .darkCard(padding: 14)
    }

    // MARK: Weekly board

    /// Friends ranked by XP, with you slotted in, for a little rivalry.
    private var weekly: some View {
        let rows = Array((store.friends + [store.me]).sorted { $0.xp > $1.xp }.prefix(5))
        return VStack(spacing: 0) {
            ForEach(rows.indices, id: \.self) { i in
                let person = rows[i]
                if i > 0 { Rectangle().fill(Palette.line).frame(height: 1) }
                Button { FriendsNav.person(person.id, router: router) } label: {
                    HStack(spacing: Space.s3) {
                        Text("\(i + 1)")
                            .font(.system(size: 13, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Palette.muted)
                            .frame(width: 18)
                        AvatarView(person: person, size: 36)
                        Text(person.id == "me" ? "You" : person.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(person.id == "me" ? Palette.accent : Palette.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(person.xp) XP").font(.system(size: 13, weight: .bold)).monospacedDigit().foregroundStyle(Palette.ink)
                    }
                    .padding(.vertical, Space.s3)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .card(padding: Space.s4)
    }
}
