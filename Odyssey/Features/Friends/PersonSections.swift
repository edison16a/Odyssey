//
//  PersonSections.swift
//  Odyssey
//
//  The posts grid or the places someone explored, under their header.
//  Ported from the content tabs in profile-view.js. The explorer card and
//  rank roadmap above it are the same ones your own profile uses.
//

import Foundation
import SwiftUI

/// Posts grid or explored places, picked with two underlined tabs.
struct FriendsPersonContent: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var person: Person
    @Binding var tab: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabButton("posts", "Posts", "square.grid.2x2")
                tabButton("places", "Explored", "mappin")
            }
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
            .padding(.bottom, 2)
            if tab == "posts" { posts } else { places }
        }
    }

    private func tabButton(_ id: String, _ label: String, _ symbol: String) -> some View {
        Button { withAnimation(.easeOut(duration: 0.15)) { tab = id } } label: {
            Label(label, systemImage: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tab == id ? Palette.ink : Palette.faint)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(tab == id ? Palette.ink : .clear).frame(height: 2)
                }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var posts: some View {
        let list = store.posts(by: person.id)
        if list.isEmpty {
            Text("No posts yet.").font(.system(size: 13)).foregroundStyle(Palette.muted).padding(.vertical, Space.s8)
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
                ForEach(list) { post in FriendsPostTile(post: post) }
            }
        }
    }

    /// Places they posted from, plus every place where they were the first explorer.
    @ViewBuilder private var places: some View {
        let explored = placeList()
        if explored.isEmpty {
            Text("No places yet.").font(.system(size: 13)).foregroundStyle(Palette.muted).padding(.vertical, Space.s8)
        } else {
            VStack(spacing: 0) {
                ForEach(explored, id: \.place.id) { item in
                    Button { router.push(.place(item.place.id)) } label: {
                        HStack(spacing: Space.s3) {
                            PlacePhoto(place: item.place)
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.place.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                                Text(store.placeKind(item.place).label).font(.system(size: 13)).foregroundStyle(Palette.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            if item.first { Tag(text: "First", icon: "star-fill", tone: .rare) }
                        }
                        .padding(.vertical, Space.s3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Space.s5)
        }
    }

    private struct Item {
        var place: Place
        var first: Bool
    }

    private func placeList() -> [Item] {
        var ids: [String] = []
        for post in store.posts(by: person.id) where !ids.contains(post.placeId) { ids.append(post.placeId) }
        var firsts = Set<String>()
        for place in store.seed.places where store.firstExplorer(place)?.by == person.id {
            firsts.insert(place.id)
            if !ids.contains(place.id) { ids.append(place.id) }
        }
        return ids.compactMap { id in store.place(id).map { Item(place: $0, first: firsts.contains(id)) } }
    }
}
