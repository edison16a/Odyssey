//
//  RecapView.swift
//  Odyssey
//
//  Daily recap, Strava style. The top maps the day's route through every
//  stop in order with numbered pins; the stats strip totals it up; the
//  timeline lists what happened at each place. Ported from recap.js.
//

import Foundation
import CoreLocation
import MapKit
import SwiftUI

struct RecapView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var recapID: String?
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        if let day = RecapBuilder.build(store, id: recapID) {
            content(day)
        } else {
            VStack {
                NavHeader(title: "Recap", back: { router.pop() })
                Spacer()
                Text("No recap yet").foregroundStyle(Palette.muted)
                Spacer()
            }
        }
    }

    private func content(_ day: RecapDay) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                map(day)
                    .frame(height: geo.size.height * 0.46 + geo.safeAreaInsets.top)
                    .ignoresSafeArea(edges: .top)
                // The list starts under the map, so the map above it stays free to drag.
                ScrollView {
                    sheet(day)
                }
                .scrollIndicators(.hidden)
                .padding(.top, geo.size.height * 0.46 - 22)
                topBar(day)
            }
        }
        .background(Palette.surface)
        .onChange(of: recapID) { _, _ in
            position = .automatic
        }
    }

    private func map(_ day: RecapDay) -> some View {
        RecapRouteMap(day: day, replay: recapID ?? "", position: $position)
    }

    private func topBar(_ day: RecapDay) -> some View {
        HStack {
            IconButton(icon: "back", kind: .white, label: "Back") { router.pop() }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "calendar").font(.system(size: 13, weight: .semibold))
                Text(day.date).font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(.white, in: Capsule())
            .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
            Spacer()
            IconButton(icon: "share", kind: .white, label: "Share") { router.present(.dayShare) }
        }
        .padding(.horizontal, Space.s4)
        .padding(.top, 4)
    }

    private func sheet(_ day: RecapDay) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily recap, started \(day.start)").labelStyle()
                Text(day.title).titleStyle(24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
            days
            RecapStats(day: day).padding(.horizontal, 20)
            RecapTimeline(day: day) { place in router.push(.place(place.id)) }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            Button { router.present(.dayShare) } label: { Label("Share your recap", systemImage: "square.and.arrow.up") }
                .buttonStyle(.pill(.primary, fill: true))
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: UnevenRoundedRectangle(topLeadingRadius: Radius.xl, topTrailingRadius: Radius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: -8)
    }

    /// Other days you can look back on.
    @ViewBuilder private var days: some View {
        let recaps = RecapBuilder.available(store)
        if recaps.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recaps) { recap in
                        let on = (recapID ?? RecapBuilder.todayID(store)) == recap.id
                        Chip(label: recap.date, isOn: on) { recapID = recap.id }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 14)
        }
    }
}

/// The day's route with its numbered pins. It owns the draw in progress, so only the map
/// redraws on every step of it rather than the whole recap with its timeline.
private struct RecapRouteMap: View {
    var day: RecapDay
    /// Changes when another day is picked, which replays the draw.
    var replay: String
    @Binding var position: MapCameraPosition
    /// How much of the route has drawn itself in, 0 to 1.
    @State private var drawn: Double = 0

    var body: some View {
        Map(position: $position) {
            MapPolyline(coordinates: RecapBuilder.partialRoute(day.stops.map { $0.place.coords }, drawn))
                .stroke(Palette.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            ForEach(day.stops) { stop in
                Annotation("", coordinate: stop.place.coords.location, anchor: .center) {
                    Text("\(stop.id + 1)")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(stop.first ? Palette.accent : Palette.ink, in: Circle())
                        .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                        .shadow(color: .black.opacity(0.3), radius: 5, y: 3)
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        // Picking another day cancels the draw already running instead of racing it.
        .task(id: replay) { await drawRoute() }
    }

    /// The route draws itself in over 2.2 seconds, after a short pause, easing out.
    private func drawRoute() async {
        drawn = 0
        try? await Task.sleep(for: .milliseconds(400))
        if Task.isCancelled { return }
        let start = Date()
        while drawn < 1 {
            let t = min(1, Date().timeIntervalSince(start) / 2.2)
            drawn = 1 - pow(1 - t, 3)
            try? await Task.sleep(for: .milliseconds(16))
            if Task.isCancelled { return }
        }
    }
}

/// Six totals in a grey strip: distance, moving time, places, coins, XP and first finds.
struct RecapStats: View {
    var day: RecapDay

    var body: some View {
        let cells: [(String, String)] = [
            (String(format: "%.1f km", day.km), "Distance"), (day.moving, "Moving"), ("\(day.stops.count)", "Places"),
            ("+\(day.coins)", "Coins"), ("+\(day.xp)", "XP"), ("\(day.firsts)", day.firsts == 1 ? "First find" : "First finds"),
        ]
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(0..<2, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { column in
                        let cell = cells[row * 3 + column]
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cell.0).font(.system(size: 19, weight: .bold)).tracking(-0.4).monospacedDigit().foregroundStyle(Palette.ink)
                            Text(cell.1).font(.system(size: 11)).foregroundStyle(Palette.muted)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .leading) {
                            if column > 0 { Rectangle().fill(Palette.line).frame(width: 1) }
                        }
                        .overlay(alignment: .bottom) {
                            if row == 0 { Rectangle().fill(Palette.line).frame(height: 1) }
                        }
                    }
                }
            }
        }
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }
}
