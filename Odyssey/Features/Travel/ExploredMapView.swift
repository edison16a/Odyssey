//
//  ExploredMapView.swift
//  Odyssey
//
//  Your explored map. The basemap stays as it is and blue hexes fill in on
//  their own wherever you go, city by city and country by country. It
//  never checks you in anywhere: that only happens when you post.
//  Ported from features/travel/explored-map.js and travel.css.
//

import CoreLocation
import Foundation
import MapKit
import SwiftUI

struct ExploredMapView: View {
    /// "world", "usa", "city" (the default) or "trip" for the latest arrival.
    var focus: String?

    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(RewardPopCenter.self) private var pop
    @State private var position: MapCameraPosition = .automatic
    @State private var scope = "city"
    @State private var cellSize = TravelHexGrid.cellSize(zoom: 14)
    @State private var cells: [TravelHexGrid.Cell] = []
    @State private var fresh: Set<TravelHexGrid.Cell> = []
    @State private var walker: Coord?
    @State private var walking = false
    @State private var walkTask: Task<Void, Never>?
    @State private var viewSize = CGSize(width: 390, height: 844)

    private let accent = Palette.accent

    var body: some View {
        GeometryReader { geo in
            ZStack {
                map
                VStack(spacing: 0) {
                    top
                    Spacer()
                    TravelMapPanel(walking: walking, walk: walk, trip: { router.present(.countryScene) })
                        .padding(.horizontal, 12)
                        .padding(.bottom, 28)
                }
            }
            .onAppear {
                viewSize = geo.size
                start()
            }
        }
        .background(Color(hex: "#e8ecf2"))
        .ignoresSafeArea(edges: .bottom)
        // Closing mid walk stops it, so it does not keep writing steps and pop its card over the app later.
        .onDisappear { walkTask?.cancel() }
    }

    private var map: some View {
        Map(position: $position) {
            ForEach(cells, id: \.self) { cell in
                let on = fresh.contains(cell)
                MapPolygon(coordinates: TravelHexGrid.corners(cell, size: cellSize))
                    .foregroundStyle(accent.opacity(on ? 0.5 : 0.24))
                    .stroke(accent.opacity(on ? 0.9 : 0.5), lineWidth: on ? 2 : 1)
            }
            if let walker {
                Annotation("", coordinate: walker.location, anchor: .center) {
                    Circle().fill(accent).frame(width: 16, height: 16)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                        .shadow(color: accent.opacity(0.4), radius: 6)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard)
        .onMapCameraChange(frequency: .onEnd) { context in
            let zoom = TravelHexGrid.zoom(longitudeDelta: context.region.span.longitudeDelta, width: Double(viewSize.width))
            let size = TravelHexGrid.cellSize(zoom: zoom)
            if size != cellSize {
                cellSize = size
                fresh = []
                redraw(flash: false)
            }
        }
        .ignoresSafeArea()
    }

    private var top: some View {
        HStack(spacing: 10) {
            IconButton(icon: "close", kind: .white, label: "Close") { router.dismissCover() }
            Segmented(options: [("world", "World"), ("usa", "USA"), ("city", store.home.city)], selection: $scope)
                .background(.white.opacity(0.92), in: Capsule())
                .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .onChange(of: scope) { _, view in
            switch view {
            case "world": fly(Coord(30, -30), zoom: 2, duration: 1)
            case "usa": fly(Coord(39.5, -105), zoom: 3, duration: 1)
            default: fly(store.home.center, zoom: 14, duration: 1)
            }
        }
    }

    private func start() {
        switch focus {
        case "world": fly(Coord(30, -30), zoom: 2, duration: 0)
        case "usa": fly(Coord(39.5, -105), zoom: 3, duration: 0)
        case "trip": fly(store.extras.demoTrip.coords, zoom: 13, duration: 0)
        default: fly(store.home.center, zoom: 14, duration: 0)
        }
        redraw(flash: false)
    }

    private func fly(_ center: Coord, zoom: Double, duration: Double) {
        let box = TravelHexGrid.box(center: center, zoom: zoom, width: Double(viewSize.width), height: Double(viewSize.height))
        let region = MKCoordinateRegion(center: box.center, span: MKCoordinateSpan(latitudeDelta: box.lat, longitudeDelta: box.lng))
        cellSize = TravelHexGrid.cellSize(zoom: zoom)
        if duration > 0 {
            withAnimation(.easeInOut(duration: duration)) { position = .region(region) }
        } else {
            position = .region(region)
        }
        redraw(flash: false)
    }

    /// Paint the cells under every trail point; new ones flash for a moment.
    private func redraw(flash: Bool) {
        let next = TravelHexGrid.cells(store.trailPoints, size: cellSize)
        if flash {
            let old = Set(cells)
            let added = Set(next.filter { !old.contains($0) })
            fresh.formUnion(added)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { fresh.subtract(added) }
        }
        cells = next
    }

    /// The demo walk: fly to the route and clear the streets one step at a time.
    private func walk() {
        guard !walking else { return }
        walking = true
        let city = store.home.city
        let sf = store.home.id == "sf"
        let route = sf ? store.extras.demoWalkSf : store.extras.demoWalk
        guard !route.isEmpty else { walking = false; return }
        walkTask = Task {
            fly(route[route.count / 2], zoom: 16, duration: 0.8)
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else {
                walking = false
                return
            }
            let before = store.cityShare()
            for point in route {
                walker = point
                store.walk(to: city, point: point)
                redraw(flash: true)
                try? await Task.sleep(for: .milliseconds(380))
                if Task.isCancelled {
                    walking = false
                    return
                }
            }
            let after = store.cityShare()
            pop.show(RewardPopModel(
                icon: "footprints", color: "#2b59ff", eyebrow: "New streets uncovered",
                title: "\(city) is \(after)% explored",
                sub: "You cleared \(route.count) new blocks " + (sf ? "along the waterfront." : "in the hills."),
                stats: [.init(glyph: "up", label: "\(city) explored", value: "+\(max(1, after - before))%")],
                shareLabel: "Share your map",
                shareText: "My explored map on Odyssey: pathy.app/map/\(store.state.user.handle)"))
            walking = false
        }
    }
}
