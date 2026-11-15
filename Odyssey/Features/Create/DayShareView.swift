//
//  DayShareView.swift
//  Odyssey
//
//  The Daily Map: your adventure today. The day's best photo goes full
//  bleed with the route drawn over it, every stop marked and the totals in
//  front, ready to share to another app. Today's seeded stops get your own check-ins
//  from today added, so the map grows as you explore.
//  Ported from features/recap/recap-share.js.
//

import Foundation
import SwiftUI
import UIKit

struct DayShareView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
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

    private func render(_ day: RecapDay) {
        let renderer = ImageRenderer(content: CreateDayCard(day: day, me: store.me, animated: false).frame(width: 360, height: 640))
        renderer.scale = 3
        rendered = renderer.uiImage
    }
}
