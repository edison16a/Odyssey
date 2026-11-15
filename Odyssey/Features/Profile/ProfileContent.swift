//
//  ProfileContent.swift
//  Odyssey
//
//  The content tabs at the bottom of your profile: a grid of your posts,
//  or the places you explored with a star where you were first.
//

import Foundation
import SwiftUI

struct ProfileContent: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Binding var tab: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabButton("posts", icon: "square.grid.2x2", title: "Posts")
                tabButton("places", icon: "mappin", title: "Explored")
            }
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
            if tab == "posts" { posts } else { places }
        }
    }

    private func tabButton(_ id: String, icon: String, title: String) -> some View {
        let on = tab == id
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { tab = id }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(on ? Palette.ink : Palette.faint)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .overlay(alignment: .bottom) { Rectangle().fill(on ? Palette.ink : .clear).frame(height: 2) }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var posts: some View {
        let list = store.posts(by: "me")
        if list.isEmpty {
            Text("No posts yet. Tap + and check in somewhere.")
                .font(.system(size: 13)).foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity).padding(.vertical, 40)
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
                ForEach(list) { post in
                    Button { router.push(.place(post.placeId)) } label: { tile(post) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.top, 2)
        }
    }

    private func tile(_ post: Post) -> some View {
        let place = store.place(post.placeId)
        return Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay { UserPhotoView(file: post.photoFile, fallback: place?.photo) }
            .overlay(alignment: .topTrailing) {
                if post.first == true {
                    Image(systemName: "star.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                        .padding(5).background(Palette.rare, in: Circle()).padding(6)
                }
            }
            .clipped()
    }

    @ViewBuilder private var places: some View {
        let firsts = Set(store.state.firsts)
        let list = store.myPlaces
        if list.isEmpty {
            Text("No places yet.").font(.system(size: 13)).foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity).padding(.vertical, 40)
        } else {
            // Grows with every place explored, so rows are built as they scroll in.
            LazyVStack(spacing: 0) {
                ForEach(list) { place in
                    Button { router.push(.place(place.id)) } label: {
                        HStack(spacing: Space.s3) {
                            PlacePhoto(place: place)
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                                Text(store.placeKind(place).label).font(.system(size: 13)).foregroundStyle(Palette.muted)
                            }
                            Spacer(minLength: 0)
                            if firsts.contains(place.id) { Tag(text: "First", icon: "star-fill", tone: .rare) }
                        }
                        .padding(.vertical, Space.s3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(Palette.line)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
