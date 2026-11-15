//
//  DayShareView.swift
//  Odyssey
//
//  The Daily Map: your adventure today. The day's best photo goes full
//  bleed with the route drawn over it, every stop marked and the totals in
//  front, ready for a story. Today's seeded stops get your own check-ins
//  from today added, so the map grows as you explore.
//  Ported from features/recap/recap-share.js.
//

import Foundation
import SwiftUI
import UIKit

struct DayShareView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(RewardPopCenter.self) private var pop
    @State private var posted = false
    @State private var rendered: UIImage?

    var body: some View {
        let day = RecapBuilder.today(store)
        VStack(spacing: 0) {
            HStack {
                IconButton(icon: "close", kind: .dark, label: "Close") { router.dismissCover() }
                Text("Daily Map").font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity)
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            CreateDayCard(day: day, me: store.me, animated: true)
                .aspectRatio(9 / 16, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .shadow(color: .black.opacity(0.6), radius: 30, y: 20)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 20)
            HStack(spacing: 8) {
                Button { post(day) } label: {
                    Label(posted ? "Posted" : "Post to friends", systemImage: posted ? "checkmark" : "plus")
                }
                .buttonStyle(.pill(.light, fill: true))
                .disabled(posted)
                if let rendered {
                    ShareLink(item: Image(uiImage: rendered), preview: SharePreview(day.title, image: Image(uiImage: rendered))) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.pill(.glass, fill: true))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .foregroundStyle(.white)
        .background(Color.black.ignoresSafeArea())
        .onAppear { render(day) }
    }

    private func post(_ day: RecapDay) {
        guard !posted, let hero = day.hero else { return }
        let entry = Post(id: "mine-day-\(Int(Date().timeIntervalSince1970))", by: "me", placeId: hero.id, kind: "day",
                         minutesAgo: 0, selfie: nil, caption: "\(day.title). \(day.stops.count) places.", seconds: nil,
                         first: nil, likes: 0, comments: 0, milestone: nil,
                         day: DayPost(title: day.title, when: day.date, km: day.km, time: day.duration, firsts: day.firsts,
                                      stops: day.stops.map(\.place.id)),
                         photoFile: nil, selfieFile: nil, createdAt: Date())
        store.update { s in s.myPosts.insert(entry, at: 0) }
        posted = true
        pop.storyPosted(hero, store: store)
    }

    private func render(_ day: RecapDay) {
        let renderer = ImageRenderer(content: CreateDayCard(day: day, me: store.me, animated: false).frame(width: 360, height: 640))
        renderer.scale = 3
        rendered = renderer.uiImage
    }
}
