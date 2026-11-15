//
//  HomeTab.swift
//  Odyssey
//
//  Home tab. The street map fills the top half with the + button on the
//  left and updates on the right; the panel below scrolls with your streak,
//  today's adventure, picks for you and quests. Both refresh when the
//  store changes. Ported from features/home/home-tab.js.
//

import Foundation
import MapKit
import SwiftUI

struct HomeTab: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var position: MapCameraPosition = .automatic
    @State private var zoom = 15
    @State private var filter = "all"
    @State private var preview: Place?
    @State private var centered = false
    @State private var showReveal = false
    @State private var bountyOpen: Bounty?

    var body: some View {
        GeometryReader { geo in
            let mapHeight = (geo.size.height + geo.safeAreaInsets.top) * 0.5
            VStack(spacing: 0) {
                mapArea(top: geo.safeAreaInsets.top)
                    .frame(height: mapHeight + 22)
                panel
                    .padding(.top, -22)
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear(perform: centerOnce)
        // Your real position often arrives a moment after the map; fly there once it does.
        .onChange(of: store.deviceLocation != nil) { _, located in
            if located && store.usingRealLocation && demoFocus == nil { fly(to: store.here, zoom: 15) }
        }
        // Demo mode opens on Y Combinator, wherever the phone really is.
        .onChange(of: store.state.demoMode) { _, on in
            if on, let yc = demoFocus { fly(to: yc, zoom: 16) }
        }
        .sheet(item: $preview) { place in
            HomePlacePreview(place: place, onBounty: openBountyFromPreview)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .fullScreenCover(isPresented: $showReveal) { HomeDailyReveal() }
        .background {
            Color.clear.sheet(item: $bountyOpen) { bounty in
                BountySheet(bountyID: bounty.id) { place in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                        fly(to: place.coords, zoom: 16)
                        preview = place
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
            }
        }
    }

    /// The place preview's bounty callout closes the preview, then opens the bounty.
    private func openBountyFromPreview(_ bounty: Bounty) {
        preview = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { bountyOpen = bounty }
    }

    private func centerOnce() {
        guard !centered else { return }
        centered = true
        if let yc = demoFocus {
            position = .region(HomeMapZoom.region(center: yc, zoom: 16))
        } else {
            position = .region(HomeMapZoom.region(center: store.usingRealLocation ? store.here : store.home.center, zoom: 15))
        }
    }

    private var demoFocus: Coord? { store.demoFocus }

    private func fly(to center: Coord, zoom level: Int) {
        withAnimation(.easeInOut(duration: 0.7)) {
            position = .region(HomeMapZoom.region(center: center, zoom: level))
        }
    }

    // MARK: Map and its controls

    private func mapArea(top: CGFloat) -> some View {
        ZStack {
            HomeMapView(position: $position, zoom: $zoom, filter: filter,
                        onPick: { place in preview = place },
                        onBounty: { bounty in bountyOpen = bounty })
            VStack(spacing: 0) {
                topBar.padding(.top, top + 4)
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        HomeFootprintChip()
                        levels
                        HomeMapLegend()
                    }
                    Spacer()
                    IconButton(icon: "locate", kind: .white, label: "Recenter") { fly(to: store.usingRealLocation ? store.here : store.home.center, zoom: 15) }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 34)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            IconButton(icon: "plus", kind: .white, label: "Post or share") { router.present(.checkIn(placeID: nil)) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    filterChip("all", "All", icon: nil)
                    filterChip("new", "Be first", icon: "star-fill")
                    filterChip("mine", "Visited", icon: nil)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
            }
            .mask(LinearGradient(stops: [.init(color: .black, location: 0.82), .init(color: .clear, location: 1)],
                                 startPoint: .leading, endPoint: .trailing))
            IconButton(icon: "bell", kind: .white, badge: store.unreadNotifications, label: "Notifications") { router.push(.notifications) }
        }
        .padding(.horizontal, 16)
    }

    private func filterChip(_ id: String, _ label: String, icon: String?) -> some View {
        let on = filter == id
        return Button {
            Haptics.tap()
            filter = id
        } label: {
            HStack(spacing: 5) {
                if let icon { Image(systemName: Icon.symbol(icon)).font(.system(size: 12, weight: .bold)).foregroundStyle(on ? .white : Palette.rare) }
                Text(label).font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .frame(height: 32)
            .foregroundStyle(on ? .white : Palette.ink)
            .background(on ? Palette.ink : .white, in: Capsule())
            .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
        }
        .buttonStyle(PressStyle())
    }

    private var levels: some View {
        let current = HomeExploredLayer.level(zoom)
        let options: [(String, String, Int)] = [("street", "Street", 16), ("city", "City", 11), ("state", "State", 6)]
        return HStack(spacing: 0) {
            ForEach(options, id: \.0) { item in
                Button {
                    fly(to: store.home.center, zoom: item.2)
                } label: {
                    Text(item.1)
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .foregroundStyle(current == item.0 ? .white : Palette.muted)
                        .background(current == item.0 ? Palette.ink : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(.white.opacity(0.94), in: Capsule())
        .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
    }

    // MARK: The panel under the map

    private var panel: some View {
        ScrollViewReader { reader in
            ScrollView(showsIndicators: false) {
                HomeFeed(
                    onPick: { place in
                        fly(to: place.coords, zoom: 16)
                        preview = place
                    },
                    onReveal: { showReveal = true },
                    onBounty: { bounty in bountyOpen = bounty }
                )
                .id("top")
                .padding(.top, 16)
            }
            .onChange(of: router.scrollToTop[.home] ?? 0) { _, _ in
                withAnimation { reader.scrollTo("top", anchor: .top) }
            }
        }
        .background(Palette.surface)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: Radius.xl, topTrailingRadius: Radius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: -8)
    }
}
