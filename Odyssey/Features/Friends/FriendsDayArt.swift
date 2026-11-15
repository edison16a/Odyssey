//
//  FriendsDayArt.swift
//  Odyssey
//
//  Day posts look like a run tracker's activity card: the day's route
//  through every stop in order over a quiet street grid, with the totals
//  along the bottom. Used in the feed, the story viewer and profile grids.
//  Ported from day-card.js.
//

import Foundation
import SwiftUI

struct FriendsDayArt: View {
    @Environment(AppStore.self) private var store
    var day: DayPost
    var tile = false
    @State private var drawn: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color(hex: "#f4f1ea")
                grid
                route(in: CGSize(width: geo.size.width, height: geo.size.height * 0.66))
                    .offset(y: geo.size.height * (tile ? 0.04 : 0.12))
                if !tile {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(day.title).font(.system(size: 19, weight: .heavy)).tracking(-0.4).foregroundStyle(Palette.ink)
                        Text(day.when).font(.system(size: 11)).foregroundStyle(Palette.muted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                }
                VStack { Spacer(); stats }
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 1.6).delay(0.2)) { drawn = 1 } }
    }

    /// A quiet street grid so the route reads as a map without loading tiles.
    private var grid: some View {
        Canvas { context, size in
            var major = Path()
            var minor = Path()
            var step = 0
            while CGFloat(step * 16) < size.width * 1.4 {
                let x = CGFloat(step * 16)
                if step % 4 == 0 {
                    major.addRect(CGRect(x: x, y: -size.height, width: 2, height: size.height * 3))
                } else {
                    minor.addRect(CGRect(x: x, y: -size.height, width: 1, height: size.height * 3))
                }
                step += 1
            }
            step = 0
            while CGFloat(step * 16) < size.height * 1.4 {
                let y = CGFloat(step * 16)
                if step % 4 == 0 {
                    major.addRect(CGRect(x: -size.width, y: y, width: size.width * 3, height: 2))
                } else {
                    minor.addRect(CGRect(x: -size.width, y: y, width: size.width * 3, height: 1))
                }
                step += 1
            }
            context.rotate(by: .degrees(-8))
            context.fill(minor, with: .color(.black.opacity(0.03)))
            context.fill(major, with: .color(.black.opacity(0.06)))
        }
    }

    /// The stops projected into the box, padded like the mockup's 34pt.
    private func points(in size: CGSize) -> [CGPoint] {
        let coords = day.stops.compactMap { store.place($0)?.coords }
        guard !coords.isEmpty else { return [] }
        let pad: Double = tile ? 18 : 34
        let lats = coords.map(\.lat), lngs = coords.map(\.lng)
        let minLat = lats.min()!, maxLat = lats.max()!, minLng = lngs.min()!
        let spanX = max((lngs.max()! - minLng), 0.002)
        let spanY = max(maxLat - minLat, 0.002)
        let w = Double(size.width), h = Double(size.height)
        let scale = min((w - pad * 2) / spanX, (h - pad * 2) / spanY)
        let offX = (w - spanX * scale) / 2
        let offY = (h - spanY * scale) / 2
        return coords.map { CGPoint(x: offX + ($0.lng - minLng) * scale, y: offY + (maxLat - $0.lat) * scale) }
    }

    private func route(in size: CGSize) -> some View {
        let pts = points(in: size)
        var path = Path()
        for (i, p) in pts.enumerated() {
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        let stroke = StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
        return ZStack(alignment: .topLeading) {
            path.stroke(Palette.accent.opacity(0.18), style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
            path.trim(from: 0, to: drawn).stroke(Palette.accent, style: stroke)
            ForEach(pts.indices, id: \.self) { i in
                ZStack {
                    Circle().fill(i == 0 ? Palette.ink : .white)
                    Circle().strokeBorder(i == 0 ? .white : Palette.accent, lineWidth: 3)
                    Text("\(i + 1)").font(.system(size: 10, weight: .heavy)).foregroundStyle(i == 0 ? .white : Palette.accent)
                }
                .frame(width: tile ? 16 : 22, height: tile ? 16 : 22)
                .position(pts[i])
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var stats: some View {
        HStack(alignment: .top, spacing: 0) {
            cell(String(format: "%.1f km", day.km), "Distance")
            cell("\(day.stops.count)", "Places")
            if !tile {
                cell(day.time, "Time")
                cell("\(day.firsts)", "First finds")
            }
        }
        .padding(.horizontal, tile ? 8 : 16)
        .padding(.vertical, tile ? 6 : 12)
        .background(.white.opacity(0.94))
        .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
    }

    private func cell(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.system(size: tile ? 11 : 16, weight: .bold)).tracking(-0.3).foregroundStyle(Palette.ink).lineLimit(1)
            Text(label).font(.system(size: tile ? 8.5 : 10.5)).foregroundStyle(Palette.muted).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
