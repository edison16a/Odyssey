//
//  HomeDailyMapCard.swift
//  Odyssey
//
//  Today's Daily Map on the home screen: your route so far drawn small, how
//  many places and how far, and a tap to open the full map to post or
//  share. It is also one tap from the camera, under the shutter.
//

import Foundation
import SwiftUI

struct HomeDailyMapCard: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let day = RecapBuilder.today(store)
        Button {
            Haptics.tap()
            router.present(.dayShare)
        } label: {
            HStack(spacing: 14) {
                route(day)
                    .frame(width: 84, height: 84)
                    .background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Map").labelStyle(Palette.accentInk)
                    Text(day.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    Text(summary(day)).font(.system(size: 13)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.faint)
            }
            .padding(12)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
        .buttonStyle(PressStyle())
    }

    private func summary(_ day: RecapDay) -> String {
        let places = day.stops.count == 1 ? "1 place" : "\(day.stops.count) places"
        return day.stops.isEmpty ? "Check in somewhere to start today's map" : places + String(format: ", %.1f km", day.km)
    }

    /// The stops drawn as a small route, keeping the real proportions.
    private func route(_ day: RecapDay) -> some View {
        Canvas { context, size in
            let coords = day.stops.map(\.place.coords)
            guard let minLat = coords.map(\.lat).min(), let maxLat = coords.map(\.lat).max(),
                  let minLng = coords.map(\.lng).min(), let maxLng = coords.map(\.lng).max() else { return }
            let pad = 14.0
            let spanX = max(maxLng - minLng, 0.002), spanY = max(maxLat - minLat, 0.002)
            let scale = min((size.width - pad * 2) / spanX, (size.height - pad * 2) / spanY)
            let offX = (size.width - spanX * scale) / 2, offY = (size.height - spanY * scale) / 2
            let points = coords.map { CGPoint(x: offX + ($0.lng - minLng) * scale, y: offY + (maxLat - $0.lat) * scale) }
            var line = Path()
            line.addLines(points)
            context.stroke(line, with: .color(Palette.accent), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            for (i, p) in points.enumerated() {
                let r: CGFloat = i == 0 || i == points.count - 1 ? 4.5 : 3
                let dot = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                context.fill(dot, with: .color(.white))
                context.stroke(dot, with: .color(Palette.accentInk), lineWidth: 2)
            }
        }
    }
}
