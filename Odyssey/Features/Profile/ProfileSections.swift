//
//  ProfileSections.swift
//  Odyssey
//
//  The rows under the showcase: places you discovered first and the
//  visible history of recent adventures. Ported from profile-showcase.js.
//

import Foundation
import SwiftUI

/// The places you discovered first, as photo cards with the date.
struct ProfileFirstsSection: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let places = store.state.firsts.reversed().compactMap { store.place($0) }
        if !places.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "Discovered first by you", link: "\(places.count) places").padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(places) { place in card(place) }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func card(_ place: Place) -> some View {
        let date = store.state.checkins[place.id] ?? store.firstExplorer(place)?.date
        return Button { router.push(.place(place.id)) } label: {
            ZStack(alignment: .bottomLeading) {
                PlacePhoto(place: place)
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 1) {
                    Text(place.name).font(.system(size: 13, weight: .bold)).lineLimit(2)
                    Text(date.map(Format.longDate) ?? "Discovered on Odyssey").font(.system(size: 11)).opacity(0.8)
                }
                .foregroundStyle(.white)
                .padding(10)
            }
            .frame(width: 150, height: 190)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(alignment: .topLeading) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").font(.system(size: 9, weight: .bold))
                    Text("First explorer").font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Palette.rare, in: Capsule())
                .padding(8)
            }
        }
        .buttonStyle(PressStyle())
    }
}

/// Recent adventures: your own check-ins first, then the seeded days.
struct ProfileHistorySection: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var limit = 6

    struct Row: Identifiable {
        var id: String
        var place: Place
        var when: String
        var first: Bool
        var video: Bool
        var photoFile: String?
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Adventure history", link: "Daily recaps") { router.push(.recap) }
            ZStack(alignment: .leading) {
                Rectangle().fill(Palette.line).frame(width: 2).padding(.vertical, 18).padding(.leading, 8)
                VStack(spacing: 0) {
                    ForEach(Array(ProfileHistorySection.rows(store).prefix(limit))) { row in
                        ProfileHistoryRow(row: row) { router.push(.place(row.place.id)) }
                    }
                }
            }
            .padding(.leading, 4)
        }
        .padding(.horizontal, 20)
    }

    /// Your check-ins newest first, then the seeded recap days in this area.
    static func rows(_ store: AppStore) -> [Row] {
        let s = store.state
        var rows: [Row] = []
        for post in s.myPosts where post.kind == "visit" {
            guard let place = store.place(post.placeId) else { continue }
            let minutes = post.createdAt.map { Int(Date().timeIntervalSince($0) / 60) } ?? 0
            let when = minutes < 60 ? "Just now" : (minutes < 1440 ? "Today, " + Format.clock(post.createdAt ?? Date()) : Format.shortDate(post.createdAt ?? Date()))
            rows.append(Row(id: post.id, place: place, when: when, first: post.first ?? false,
                            video: !(s.videos[post.placeId] ?? []).isEmpty, photoFile: post.photoFile))
        }
        let home = store.home.id
        for recap in store.seed.recaps where (recap.area ?? "berkeley") == home {
            for (index, stop) in recap.stops.reversed().enumerated() {
                guard let place = store.place(stop.placeId) else { continue }
                rows.append(Row(id: "\(recap.id)-\(index)", place: place, when: recap.date + ", " + stop.time,
                                first: stop.first ?? false, video: stop.action == "video", photoFile: nil))
            }
        }
        return rows
    }
}

struct ProfileHistoryRow: View {
    var row: ProfileHistorySection.Row
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle().fill(Palette.accent).frame(width: 10, height: 10)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3).padding(-3))
                UserPhotoView(file: row.photoFile, fallback: row.place.photo)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.place.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                    Text(row.when).font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
                if row.first {
                    Tag(text: "First", icon: "star-fill", tone: .rare)
                } else if row.video {
                    Tag(text: "", icon: "video", tone: .accent)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
