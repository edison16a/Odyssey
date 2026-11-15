//
//  PlaceActivity.swift
//  Odyssey
//
//  Who keeps coming back to a place and how busy it has been: the
//  regulars list with visit bars, the 18 week activity grid (one column
//  per week, darker squares mean more visits) and the photos explorers
//  posted here.
//

import Foundation
import SwiftUI

/// People with the most visits here, most first. The top one wears the crown.
struct PlaceRegulars: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(RewardPopCenter.self) private var pop
    var place: Place

    var body: some View {
        let rows = store.topExplorers(place)
        let top = max(1, rows.first?.visits ?? 1)
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Regulars", link: "\(store.visitCount(place)) explorers")
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if let who = store.person(row.id) {
                        if index > 0 { Divider().overlay(Palette.line) }
                        regularRow(index: index, who: who, visits: row.visits, share: Double(row.visits) / Double(top))
                    }
                }
            }
            .card(padding: 16)
        }
    }

    private func regularRow(index: Int, who: Person, visits: Int, share: Double) -> some View {
        HStack(spacing: 10) {
            Group {
                if index == 0 {
                    Image(systemName: "crown.fill").foregroundStyle(Palette.gold)
                } else {
                    Text("\(index + 1)").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.muted)
                }
            }
            .frame(width: 22)
            Button { router.push(.person(who.id)) } label: {
                HStack(spacing: 10) {
                    AvatarView(person: who, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(who.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                        Text("\(visits) \(visits == 1 ? "visit" : "visits")").mutedStyle(13).monospacedDigit()
                        ProgressBar(value: share, height: 4).padding(.top, 4)
                    }
                }
            }
            .buttonStyle(.plain)
            if who.id != "me" && !store.isFriend(who.id) {
                IconButton(icon: "plus", size: 32, label: "Add friend") {
                    store.addFriend(who.id)
                    pop.friendAdded(who.id, store: store)
                }
            }
        }
        .padding(.vertical, 12)
    }
}

/// GitHub style grid of explorers per day over the last 18 weeks.
struct PlaceActivityGrid: View {
    @Environment(AppStore.self) private var store
    var place: Place
    var history: PlaceHistory?

    static let shades: [Color] = [Palette.surface3, Color(hex: "#c9d6ff"), Color(hex: "#8ea8ff"), Color(hex: "#5579ff"), Palette.accent]

    var body: some View {
        let cells = history?.levels ?? store.activity(place)
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Contributions", link: history.map { "\($0.total) in 18 weeks" } ?? "Last 18 weeks")
            VStack(spacing: 10) {
                HStack(spacing: 3) {
                    ForEach(0..<18, id: \.self) { week in
                        VStack(spacing: 3) {
                            ForEach(0..<7, id: \.self) { day in
                                let index = week * 7 + day
                                square(index < cells.count ? cells[index] : 0)
                            }
                        }
                    }
                }
                HStack {
                    Text("Less")
                    Spacer()
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { level in square(level).frame(width: 12) }
                    }
                    Spacer()
                    Text("More")
                }
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted)
            }
            .card(padding: 16)
        }
    }

    private func square(_ level: Int) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(PlaceActivityGrid.shades[min(4, max(0, level))])
            .aspectRatio(1, contentMode: .fit)
    }
}

/// The latest walkthroughs explorers shared here, newest first.
struct PlaceContributions: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var items: [PlaceHistory.Item]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Recent contributions")
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    row(item)
                    if index < items.count - 1 { Divider().padding(.leading, 52) }
                }
            }
            .card(padding: 14)
        }
    }

    private func row(_ item: PlaceHistory.Item) -> some View {
        let person = item.personID.flatMap { store.person($0) } ?? (item.name == store.me.name ? store.me : nil)
        return Button {
            if let person { router.push(.person(person.id)) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                if let person {
                    AvatarView(person: person, size: 40, frame: "none")
                } else {
                    Circle().fill(Palette.surface3).frame(width: 40, height: 40)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.name).font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.ink)
                        Text("\(item.seconds)s walkthrough").font(.system(size: 12)).foregroundStyle(Palette.muted)
                        Spacer(minLength: 0)
                        Text(item.at, format: .relative(presentation: .named)).font(.system(size: 11)).foregroundStyle(Palette.muted)
                    }
                    if let summary = item.summary {
                        Text(summary).font(.system(size: 13)).foregroundStyle(Palette.ink2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

/// Explorer photos: the place with their selfie in the corner. Opens the story.
struct PlaceExplorerPhotos: View {
    @Environment(AppRouter.self) private var router
    var place: Place
    var posts: [Post]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "From explorers")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(posts) { post in
                        Button { router.push(.person(post.by)) } label: {
                            PhotoView(path: place.photo)
                                .frame(width: 132, height: 170)
                                .overlay(alignment: .topLeading) {
                                    PhotoView(path: post.selfie ?? "")
                                        .frame(width: 44, height: 58)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white, lineWidth: 2))
                                        .padding(8)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        }
                        .buttonStyle(PressStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
    }
}
