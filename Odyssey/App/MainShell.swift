//
//  MainShell.swift
//  Odyssey
//
//  The signed in app: four tabs plus the raised + button in the middle.
//  Each tab keeps its own navigation stack alive once opened, so scroll
//  position and the map survive a tab switch. Pushed screens cover the tab
//  bar, like the mockup's stack layer. The arrival card slides in on top
//  when you reach a place.
//

import Foundation
import SwiftUI

struct MainShell: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppStore.self) private var store
    @State private var opened: Set<AppTab> = [.home]
    @State private var arrival = ArrivalWatcher()
    /// Set from outside while onboarding covers the app.
    @Environment(\.animationsPaused) private var covered

    var body: some View {
        @Bindable var router = router
        ZStack(alignment: .bottom) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                if opened.contains(tab) {
                    NavigationStack(path: router.binding(tab)) {
                        root(for: tab)
                            .toolbar(.hidden, for: .navigationBar)
                            // The tab's root sits under any pushed screen; let it rest there too.
                            .environment(\.animationsPaused, covered || router.tab != tab || router.cover != nil || !router.path(tab).isEmpty)
                            .navigationDestination(for: Route.self) { route in
                                RouteView(route: route)
                                    .toolbar(.hidden, for: .navigationBar)
                            }
                    }
                    .opacity(router.tab == tab ? 1 : 0)
                    .allowsHitTesting(router.tab == tab)
                    .environment(\.animationsPaused, covered || router.tab != tab || router.cover != nil)
                }
            }
            if router.path(router.tab).isEmpty {
                TabBar()
                    .transition(.move(edge: .bottom))
            }
        }
        .overlay(alignment: .top) {
            if let place = arrival.current, router.cover == nil {
                ArrivalBanner(place: place, close: { arrival.dismiss() })
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: store.deviceLocation) { arrival.check(store) }
        .ignoresSafeArea(.keyboard)
        .animation(.easeOut(duration: 0.2), value: router.path(router.tab).isEmpty)
        .onChange(of: router.tab) { _, tab in opened.insert(tab) }
        .fullScreenCover(item: $router.cover) { cover in
            CoverView(cover: cover)
        }
    }

    @ViewBuilder private func root(for tab: AppTab) -> some View {
        switch tab {
        case .home: HomeTab()
        case .worldMap: WorldMapView()
        case .explore: ExploreTab()
        case .profile: ProfileTab()
        }
    }
}

/// The tab bar: frosted white, four tabs and the black + tile.
struct TabBar: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            tab(.home)
            tab(.worldMap)
            Button {
                Haptics.tap()
                router.present(.scan(placeID: nil))
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Palette.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.22), radius: 8, y: 6)
            }
            .buttonStyle(PressStyle(scale: 0.92))
            .frame(maxWidth: .infinity)
            .offset(y: -2)
            .accessibilityLabel("Scan a place in 3D")
            tab(.explore)
            tab(.profile)
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background {
            Rectangle()
                .fill(.white.opacity(0.92))
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tab(_ tab: AppTab) -> some View {
        let on = router.tab == tab
        return Button {
            if !on { Haptics.tap() }
            router.select(tab)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: on ? tab.icon + ".fill" : tab.icon)
                    .font(.system(size: 21, weight: on ? .semibold : .regular))
                    .frame(height: 26)
                Text(tab.title).font(.system(size: 10.5, weight: .semibold))
            }
            .foregroundStyle(on ? Palette.ink : Palette.faint)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
    }
}

/// Space at the bottom of tab roots so content clears the tab bar.
struct TabBarSpacer: View {
    var body: some View { Color.clear.frame(height: 96) }
}
