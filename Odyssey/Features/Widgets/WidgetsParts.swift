//
//  WidgetsParts.swift
//  Odyssey
//
//  Pieces of the widgets screens: a row per widget with its sizes side by
//  side, the Live Activity card, and the shelf on the profile page.
//

import Combine
import Foundation
import SwiftUI

/// One widget: its name, what it does and every size it comes in.
struct WidgetsKindRow: View {
    var kind: OdysseyWidgetKind
    var snapshot: WidgetSnapshot
    var prefs: WidgetPrefs
    var customize: () -> Void
    var add: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Palette.ink, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(kind.title).font(.system(size: 16, weight: .bold))
                    Text(kind.sizes.map(\.label).joined(separator: ", ")).font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
                Spacer()
            }
            Text(kind.blurb).font(.system(size: 14)).foregroundStyle(Palette.ink2)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 12) {
                    ForEach(kind.sizes.filter { !$0.isAccessory }, id: \.self) { size in
                        WidgetPreview(kind: kind, size: size, snapshot: snapshot, prefs: prefs, scale: size == .small ? 0.8 : 0.62)
                    }
                    ForEach(kind.sizes.filter(\.isAccessory), id: \.self) { size in
                        WidgetPreview(kind: kind, size: size, snapshot: snapshot, prefs: prefs)
                            .padding(10)
                            .background(Palette.ink2, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .padding(.vertical, 6)
            }
            HStack(spacing: 10) {
                Button(action: customize) { Label("Customize", systemImage: "slider.horizontal.3") }
                    .buttonStyle(.pill(.soft, height: 40, fill: true))
                Button(action: add) { Label("Add to Home Screen", systemImage: "plus") }
                    .buttonStyle(.pill(.primary, height: 40, fill: true))
            }
        }
        .card()
    }
}

/// The adventure Live Activity: what it shows and a button to try it now.
struct WidgetsLiveActivityCard: View {
    var snapshot: WidgetSnapshot
    var start: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Palette.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Adventure in progress").font(.system(size: 16, weight: .bold))
                    Text("Lock Screen and Dynamic Island").font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
            }
            Text("When you head to a place, Odyssey keeps the distance left and the coins waiting on your Lock Screen and around the camera, then shows what you earned after you check in.")
                .font(.system(size: 14)).foregroundStyle(Palette.ink2)
            WidgetsIslandMock(snapshot: snapshot)
                .frame(maxWidth: .infinity)
            Button(action: start) { Label("Try it with today's adventure", systemImage: "play.fill") }
                .buttonStyle(.pill(.accent, height: 44, fill: true))
        }
        .card()
    }
}

/// The Dynamic Island pill, compact, as it sits around the camera.
struct WidgetsIslandMock: View {
    var snapshot: WidgetSnapshot

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: snapshot.adventure?.symbol ?? "location.north.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: "#6f8dff"))
            Spacer()
            Text(snapshot.adventure?.distanceText ?? "210 m")
                .font(.system(size: 13, weight: .bold)).monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .frame(width: 210, height: 36)
        .background(Color.black, in: Capsule())
        .overlay(Circle().fill(Color(hex: "#1c1c1f")).frame(width: 11, height: 11))
        .padding(.vertical, 4)
    }
}

/// The Widgets section on the profile tab: a strip of live previews.
struct WidgetsShelf: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var snapshot = WidgetSnapshot.placeholder

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Widgets", link: "See all") { router.push(.widgets) }
                .padding(.horizontal, 20)
            // The row scrolls edge to edge but starts and ends in line with the page.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach([OdysseyWidgetKind.streak, .adventure, .coins, .quest], id: \.self) { kind in
                        Button { router.push(.widgetEditor(kind)) } label: {
                            WidgetPreview(kind: kind, size: .small, snapshot: snapshot, prefs: store.state.widgetPrefs, scale: 0.78)
                        }
                        .buttonStyle(PressStyle())
                    }
                    Button { router.push(.widgets) } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "plus").font(.system(size: 20, weight: .semibold))
                            Text("Add to\nHome Screen").font(.system(size: 12, weight: .semibold)).multilineTextAlignment(.center)
                        }
                        .foregroundStyle(Palette.ink)
                        .frame(width: 158 * 0.78, height: 158 * 0.78)
                        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PressStyle())
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
            }
        }
        .onAppear { snapshot = WidgetBridge.snapshot(from: store) }
        .onReceive(NotificationCenter.default.publisher(for: WidgetBridge.imagesChanged)) { _ in
            snapshot = WidgetBridge.snapshot(from: store)
        }
    }
}
