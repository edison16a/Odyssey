//
//  AdventureHistoryView.swift
//  Odyssey
//
//  Every adventure you have been on, newest first. Your own check-ins show
//  the photo pair you took there; earlier days from your recaps follow as
//  a timeline.
//

import Foundation
import SwiftUI

struct AdventureHistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let mine = store.state.myPosts.filter { $0.kind == "visit" }
        let earlier = ProfileHistorySection.rows(store).filter { row in !mine.contains { $0.id == row.id } }
        VStack(spacing: 0) {
            NavHeader(title: "Adventure history", back: { router.pop() }) {
                IconButton(icon: "footprints", kind: .clear, label: "Daily recaps") { router.push(.recap) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if mine.isEmpty {
                        empty
                    } else {
                        SectionHeader(title: "Your check-ins", link: "\(mine.count)")
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(mine) { post in card(post) }
                        }
                    }
                    if !earlier.isEmpty {
                        SectionHeader(title: "Earlier", link: "From your recaps").padding(.top, 28)
                        ForEach(earlier) { row in
                            ProfileHistoryRow(row: row) { router.push(.place(row.place.id)) }
                        }
                    }
                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .background(Palette.surface)
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera").font(.system(size: 28, weight: .semibold)).foregroundStyle(Palette.faint)
            Text("No check-ins yet").font(.system(size: 17, weight: .bold)).foregroundStyle(Palette.ink)
            Text("Tap + and check in somewhere. Your photos land here.")
                .font(.system(size: 13)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
            Button("Check in") { router.present(.checkIn(placeID: nil)) }
                .buttonStyle(.pill(.accent, height: 44))
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func card(_ post: Post) -> some View {
        let place = store.place(post.placeId)
        let when = post.createdAt.map { Format.shortDate($0) + ", " + Format.clock($0) } ?? "Today"
        return Button {
            router.present(.story(personID: "me", postID: post.id))
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Color.clear
                    .aspectRatio(0.78, contentMode: .fit)
                    .overlay { UserPhotoView(file: post.photoFile, fallback: place?.photo) }
                    .overlay(alignment: .topLeading) {
                        if post.selfieFile != nil {
                            UserPhotoView(file: post.selfieFile, fallback: nil)
                                .frame(width: 44, height: 58)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white, lineWidth: 2))
                                .padding(8)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if post.first == true {
                            Tag(text: "First", icon: "star-fill", tone: .rare).padding(8)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                Text(place?.name ?? "A place").font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.ink).lineLimit(1)
                Text(when).font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
        }
        .buttonStyle(PressStyle())
    }
}
