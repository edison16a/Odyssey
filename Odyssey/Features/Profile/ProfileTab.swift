//
//  ProfileTab.swift
//  Odyssey
//
//  Your profile, the rightmost tab. The banner and framed avatar up top,
//  the showcase of your best exploring, places you discovered first, your
//  adventure history, the business entry (until you close it), then your
//  posts and explored places. A title bar with your name
//  slides in once you scroll past the header, and your profile effect wraps
//  the whole screen. Ported from profile-tab.js.
//

import Foundation
import SwiftUI

struct ProfileTab: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var scrolled = false
    @State private var contentTab = "posts"

    var body: some View {
        ZStack(alignment: .top) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ProfileHeader(onPlaces: { showPlaces(proxy) }).id("top")
                        sections(proxy)
                        TabBarSpacer()
                    }
                }
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top > 190
                } action: { _, isScrolled in
                    withAnimation(.easeOut(duration: 0.2)) { scrolled = isScrolled }
                }
                .onChange(of: router.scrollToTop[.profile] ?? 0) { _, _ in
                    withAnimation { proxy.scrollTo("top", anchor: .top) }
                }
            }
            .ignoresSafeArea(edges: .top)
            ProfileEffectView(id: store.state.equipped.effect, cornerRadius: 44)
                .ignoresSafeArea()
            topBar
        }
        .background(Palette.surface)
    }

    private func sections(_ proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "Showcase", link: "Your best so far")
                ProfileShowcaseGrid(onPlaces: { showPlaces(proxy) })
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            ProfileFirstsSection().padding(.top, 28)
            ProfileHistorySection().padding(.top, 28)

            if !store.state.tipsSeen.contains(ProfileBusinessEntry.dismissKey) {
                ProfileBusinessEntry()
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
            }

            ProfileContent(tab: $contentTab)
                .padding(.top, 28)
                .id("content")
        }
    }

    private func showPlaces(_ proxy: ScrollViewProxy) {
        contentTab = "places"
        withAnimation { proxy.scrollTo("content", anchor: .top) }
    }

    /// The gear on the banner, which becomes a white title bar with your name once scrolled.
    private var topBar: some View {
        ZStack {
            if scrolled {
                Text(store.me.name).font(.system(size: 17, weight: .bold)).foregroundStyle(Palette.ink)
                    .transition(.opacity)
            }
            HStack {
                Spacer()
                IconButton(icon: "gear", kind: scrolled ? .soft : .dark, label: "Settings") { router.push(.settings) }
            }
        }
        .padding(.horizontal, Space.s4)
        .frame(height: 52)
        .background {
            if scrolled {
                Palette.surface
                    .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
                    .ignoresSafeArea(edges: .top)
                    .transition(.opacity)
            }
        }
    }
}
