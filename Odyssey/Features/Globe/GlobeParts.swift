//
//  GlobeParts.swift
//  Odyssey
//
//  Pieces of the Odyssey Globe slides: the three photo fan, the walked route
//  line, you and your closest explorer side by side, and the summary card
//  with Share and Replay on the last slide. Ported from globe-slides.js
//  and globe-art.css.
//

import Foundation
import SwiftUI

/// Three photos in a row, the middle one lifted and turned a little.
struct GlobePhotos: View {
    var places: [Place]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(places.prefix(3).enumerated()), id: \.offset) { index, place in
                Color.clear
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .overlay { PlacePhoto(place: place) }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .rotationEffect(.degrees(index == 1 ? 2 : 0))
                    .offset(y: index == 1 ? -14 : 0)
            }
        }
        .padding(.top, 10)
    }
}

/// Footprints, a dashed line and a flag.
struct GlobeRoute: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: Icon.symbol("footprints")).font(.system(size: 20, weight: .semibold))
            Line()
                .stroke(style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                .frame(height: 3)
                .opacity(0.5)
            Image(systemName: Icon.symbol("flag")).font(.system(size: 20, weight: .semibold))
        }
        .frame(width: 220)
        .padding(.top, 18)
    }

    private struct Line: Shape {
        // Shape asks for a nonisolated path(in:), and the target defaults to the main actor.
        nonisolated func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

/// You and Nina, overlapping, with a green ring around the second face.
struct GlobePair: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(spacing: -18) {
            AvatarView(person: store.me, size: 84, frame: "none")
            if let friend = store.person("nina") {
                AvatarView(person: friend, size: 84, frame: "none")
                    .overlay(Circle().strokeBorder(Color(hex: "#17a35a"), lineWidth: 4).padding(-4))
            }
        }
    }
}

/// The 2026 Globe card on the last slide.
struct GlobeSummary: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let s = store.state
        let twin = GlobeData.twin(store)
        VStack(alignment: .leading, spacing: 10) {
            OdysseyWordmark(size: 20)
            Text("2026 Globe").font(.system(size: 11, weight: .bold)).tracking(1.3).textCase(.uppercase).opacity(0.75)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                cell("\(s.stats.explored)", "places")
                cell("\(Format.number(s.stats.km)) km", "walked")
                cell("\(s.firsts.count)", "first finds")
                cell(store.rank().current.name, "rank")
            }
            .padding(.vertical, 6)
            HStack(spacing: 8) {
                Image(systemName: Icon.symbol(twin.glyph)).font(.system(size: 18, weight: .semibold))
                Text("Explores like \(twin.name)").font(.system(size: 15, weight: .semibold))
            }
            Text("@" + store.me.handle).font(.system(size: 13)).opacity(0.6)
        }
        .multilineTextAlignment(.leading)
        .foregroundStyle(.white)
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#141416"), in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
    }

    private func cell(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 24, weight: .bold)).tracking(-0.5).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.system(size: 11)).opacity(0.6)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }
}

/// Share and Replay under the summary card.
struct GlobeActions: View {
    var replay: () -> Void
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(spacing: 8) {
            ShareLink(item: "My Odyssey Globe 2026: pathy.app/globe/2026/\(store.state.user.handle)") {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.pill(.light, fill: true))
            Button("Replay", action: replay).buttonStyle(.pill(.glass, fill: true))
        }
        .padding(.top, 10)
    }
}
