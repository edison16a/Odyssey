//
//  DayShareCard.swift
//  Odyssey
//
//  The 9:16 card for a whole day: hero photo, the route drawn as a line
//  through every stop (blue dots for first finds), and the totals. The
//  route is projected into a box keeping the real shape, so no map is
//  needed.
//

import Foundation
import SwiftUI

struct CreateDayCard: View {
    var day: RecapDay
    var me: Person
    var animated: Bool
    @State private var drawn: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Group {
                    if let hero = day.hero { PhotoView(path: hero.photo) } else { Color(hex: "#222222") }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                LinearGradient(stops: [.init(color: .black.opacity(0.45), location: 0), .init(color: .black.opacity(0.1), location: 0.3),
                                       .init(color: .black.opacity(0.25), location: 0.55), .init(color: .black.opacity(0.85), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                route(width: geo.size.width * 0.88)
                    .offset(x: geo.size.width * 0.06, y: geo.size.height * 0.14)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        OdysseyWordmark(size: 17)
                        Spacer()
                        Text(day.date).font(.system(size: 11, weight: .bold)).foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                    foot
                }
                .padding(16)
            }
        }
        .onAppear {
            guard animated else { return }
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 1.8).delay(0.3)) { drawn = 1 }
        }
    }

    /// Stops projected into a 300 by 220 box, keeping the route's real proportions.
    private func points(in size: CGSize, pad: CGFloat) -> [CGPoint] {
        let coords = day.stops.map(\.place.coords)
        guard let minLat = coords.map(\.lat).min(), let maxLat = coords.map(\.lat).max(),
              let minLng = coords.map(\.lng).min(), let maxLng = coords.map(\.lng).max() else { return [] }
        let spanX = max(maxLng - minLng, 0.002)
        let spanY = max(maxLat - minLat, 0.002)
        let scale = min((Double(size.width) - Double(pad) * 2) / spanX, (Double(size.height) - Double(pad) * 2) / spanY)
        let offX = (Double(size.width) - spanX * scale) / 2
        let offY = (Double(size.height) - spanY * scale) / 2
        return coords.map { CGPoint(x: offX + ($0.lng - minLng) * scale, y: offY + (maxLat - $0.lat) * scale) }
    }

    private func route(width: CGFloat) -> some View {
        let size = CGSize(width: width, height: width * 220 / 300)
        let pts = points(in: size, pad: width * 0.1)
        var line = Path()
        if let first = pts.first {
            line.move(to: first)
            pts.dropFirst().forEach { line.addLine(to: $0) }
        }
        return ZStack(alignment: .topLeading) {
            line.stroke(Palette.ink.opacity(0.35), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
            line.trim(from: 0, to: animated ? drawn : 1).stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            ForEach(Array(pts.enumerated()), id: \.offset) { index, point in
                let end = index == 0 || index == pts.count - 1
                let first = day.stops[index].first
                Circle()
                    .fill(first ? Palette.accent : .white)
                    .overlay(Circle().strokeBorder(first ? .white : Palette.ink, lineWidth: 2.5))
                    .frame(width: end ? 14 : 10, height: end ? 14 : 10)
                    .position(point)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var foot: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(day.title).font(.system(size: 22, weight: .heavy)).tracking(-0.4)
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 8) {
                cell(String(format: "%.1f km", day.km), "Distance")
                cell("\(day.stops.count)", "Places")
                cell("\(day.firsts)", "First finds")
                cell("+\(day.coins)", "Coins")
            }
            HStack(spacing: 8) {
                AvatarView(person: me, size: 26)
                Text("@\(me.handle)").font(.system(size: 13, weight: .semibold))
            }
        }
        .foregroundStyle(.white)
    }

    private func cell(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.system(size: 22, weight: .bold)).tracking(-0.4).monospacedDigit()
            Text(label).font(.system(size: 11)).opacity(0.75)
        }
    }
}
