//
//  PlaceView.swift
//  Odyssey
//
//  The place page. Real photo up top, then the two things you do here:
//  check in, or get directions in Apple Maps (which also starts the
//  adventure Live Activity). Thumbs teach Odyssey what you like. Below,
//  three tabs split the rest: Overview, Deals and Activity (see
//  PlaceSections.swift). The tab bar pins under the title bar on scroll.
//  Ported from features/place/place.js.
//

import Foundation
import SwiftUI

struct PlaceView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var placeID: String
    @State private var scrolled = false
    @State private var tab: PlaceTab = .overview
    /// Slide direction for the incoming tab.
    @State private var forward = true
    /// Real contribution history from Convex; the local estimate shows until it arrives.
    @State private var history: PlaceHistory?
    @State private var position = ScrollPosition()
    @State private var offset: CGFloat = 0
    @State private var viewport: CGFloat = 0
    /// Where the inline tab bar sits on screen, and whether it has reached the title bar.
    @State private var tabsTop: CGFloat = .greatestFiniteMagnitude
    @State private var tabsPinned = false

    var body: some View {
        if let place = store.place(placeID) {
            content(place)
        } else {
            VStack(spacing: 0) {
                NavHeader(title: "Place", back: { router.pop() })
                Spacer()
                Text("This place is not available right now").mutedStyle(15)
                Spacer()
            }
            .background(Palette.surface)
        }
    }

    private func content(_ place: Place) -> some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    hero(place)
                    PlaceMainCard(place: place)
                        .padding(.top, -26)
                    tabBar(place)
                        .padding(.horizontal, 20)
                        .padding(.vertical, Self.tabBarPadding)
                        .background(Palette.surface)
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.frame(in: .named(Self.page)).minY
                        } action: { minY in
                            tabsTop = minY
                            let pinned = minY < Self.topBarHeight
                            if pinned != tabsPinned { tabsPinned = pinned }
                        }
                        .opacity(tabsPinned ? 0 : 1)
                        .accessibilityHidden(tabsPinned)
                    tabContent(place)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .frame(minHeight: max(0, viewport - Self.topBarHeight - Self.tabBarHeight), alignment: .top)
                    Color.clear.frame(height: 40)
                }
            }
            .scrollPosition($position)
            .ignoresSafeArea(edges: .top)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top
            } action: { _, y in
                offset = y
                let isScrolled = y > 210
                if isScrolled != scrolled {
                    withAnimation(.easeOut(duration: 0.2)) { scrolled = isScrolled }
                }
            }
            topBar(place)
        }
        .coordinateSpace(name: Self.page)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewport = $0 }
        .background(Palette.surface)
        .task(id: place.id) {
            let next = await Cloud.shared.placeHistory(place.id)
            withAnimation(.easeOut(duration: 0.25)) { history = next }
        }
    }

    // MARK: Tabs

    private static let page = "placePage"
    private static let topBarHeight: CGFloat = 52
    private static let tabBarPadding: CGFloat = 10
    /// The tab bar's track (36 + 2 x 3) plus its vertical padding.
    private static let tabBarHeight: CGFloat = 42 + tabBarPadding * 2

    private func tabBar(_ place: Place) -> some View {
        PlaceTabBar(selection: tab, counts: [.deals: PlaceDealsTab.count(place, store: store)]) { select($0) }
    }

    /// Both tabs overlap during the switch so the page height never jumps twice.
    private func tabContent(_ place: Place) -> some View {
        ZStack(alignment: .top) {
            Group {
                switch tab {
                case .overview: PlaceOverviewTab(place: place, history: history)
                case .deals: PlaceDealsTab(place: place)
                case .activity: PlaceActivityTab(place: place, history: history)
                }
            }
            .id(tab)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(x: forward ? 18 : -18)),
                removal: .opacity.animation(.easeOut(duration: 0.12))
            ))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// Switch tabs. If the bar is pinned, bring the new tab's first section up under it.
    private func select(_ next: PlaceTab) {
        guard next != tab else { return }
        forward = next.rawValue > tab.rawValue
        let lift = tabsTop - Self.topBarHeight
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { tab = next }
        if tabsPinned && lift < 0 {
            position.scrollTo(y: max(0, offset + lift))
        }
    }

    private func hero(_ place: Place) -> some View {
        PhotoView(path: place.photo)
            .frame(height: 300)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .top) {
                LinearGradient(colors: [.black.opacity(0.45), .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 120)
            }
            .clipped()
    }

    /// The title bar, with a copy of the tab bar under it once the inline one scrolls up to it.
    private func topBar(_ place: Place) -> some View {
        VStack(spacing: 0) {
            titleBar(place)
            if tabsPinned {
                tabBar(place)
                    .padding(.horizontal, 20)
                    .padding(.vertical, Self.tabBarPadding)
                    .frame(maxWidth: .infinity)
                    .background(Palette.surface)
            }
        }
        .overlay(alignment: .bottom) {
            if scrolled {
                Rectangle().fill(Palette.line).frame(height: 1)
            }
        }
    }

    /// Dark round buttons over the photo, a white title bar once scrolled.
    private func titleBar(_ place: Place) -> some View {
        HStack(spacing: 8) {
            IconButton(icon: "back", kind: scrolled ? .clear : .dark, label: "Back") { router.pop() }
            Spacer()
            if scrolled {
                Text(place.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .transition(.opacity)
                Spacer()
            }
            PlaceStarButton(place: place, light: !scrolled)
            ShareLink(item: "Check out \(place.name) on Odyssey") {
                Image(systemName: Icon.symbol("share"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(scrolled ? Palette.ink : .white)
                    .frame(width: 40, height: 40)
                    .background {
                        if !scrolled {
                            Circle().fill(.black.opacity(0.45)).background(.ultraThinMaterial, in: Circle())
                        }
                    }
            }
            .accessibilityLabel("Share")
        }
        .padding(.horizontal, scrolled ? 12 : 16)
        .frame(height: Self.topBarHeight)
        .background {
            if scrolled {
                Palette.surface.ignoresSafeArea(edges: .top)
            }
        }
    }
}

/// The white sheet that overlaps the photo: tags, name, facts and actions.
private struct PlaceMainCard: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var place: Place

    var body: some View {
        let metres = store.metres(to: place)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                statusTag
                Tag(text: store.placeKind(place).label, icon: store.placeKind(place).icon)
            }
            .padding(.bottom, 8)
            Text(place.name)
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(Palette.ink)
                .padding(.bottom, 6)
            if let rating = place.rating { ratingRow(rating) }
            Text(facts(metres)).mutedStyle(13)
            actions.padding(.vertical, 16)
            whyRow(metres)
        }
        .padding([.horizontal, .top], 20)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: UnevenRoundedRectangle(topLeadingRadius: Radius.xl, topTrailingRadius: Radius.xl, style: .continuous))
    }

    @ViewBuilder private var statusTag: some View {
        let info = store.status(of: place)
        switch info.status {
        case .mine: Tag(text: "You explored this", icon: "check", tone: .success)
        case .new: Tag(text: "Be the first explorer", icon: "star-fill", tone: .rare)
        case .explored: Tag(text: "\(info.explorers) explorers", icon: "users")
        }
    }

    private func ratingRow(_ rating: Double) -> some View {
        let full = Int(rating.rounded())
        return HStack(spacing: 6) {
            HStack(spacing: 1) {
                ForEach(0..<5, id: \.self) { i in
                    Image(systemName: i < full ? "star.fill" : "star").font(.system(size: 12, weight: .semibold))
                }
            }
            .foregroundStyle(Palette.gold)
            Text(String(format: "%.1f", rating)).font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.ink)
            Text("(\(Format.number(place.reviews ?? 0)))").mutedStyle(13)
        }
        .padding(.bottom, 4)
    }

    private func facts(_ metres: Double) -> String {
        [Format.distance(metres), Format.walkTime(metres), place.hours ?? ""].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    private var actions: some View {
        let done = store.checkedInToday(place)
        return HStack(spacing: 8) {
            Button {
                router.present(.checkIn(placeID: place.id))
            } label: {
                Label(done ? "Explored today" : "Check in", systemImage: done ? "checkmark" : "camera")
            }
            .buttonStyle(.pill(done ? .soft : .accent, fill: true))
            Button {
                Haptics.tap()
                LiveActivityService.shared.start(place: place, store: store)
                NearbyService.directions(to: place)
            } label: {
                Label("Directions", systemImage: "location.north.fill")
            }
            .buttonStyle(.pill(.primary, fill: true))
        }
    }

    private func whyRow(_ metres: Double) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                OdysseyMark(size: 14)
                Text(store.why(place, metres: metres))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
            }
            .foregroundStyle(Palette.accentInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            ThumbsView(place: place)
        }
    }
}
