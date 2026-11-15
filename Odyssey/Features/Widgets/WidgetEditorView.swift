//
//  WidgetEditorView.swift
//  Odyssey
//
//  Change how one widget looks: pick a size to preview, a style (light,
//  dark, your streak form's colors, or a photo), and the details it shows.
//  Choices save right away and the widgets on your home screen update.
//

import Combine
import Foundation
import SwiftUI

struct WidgetEditorView: View {
    var kind: OdysseyWidgetKind
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var size: WidgetSize = .small
    @State private var snapshot = WidgetSnapshot.placeholder
    @State private var adding = false

    private var prefs: WidgetPrefs { store.state.widgetPrefs }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: kind.title, back: { router.pop() })
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    stage
                    if kind.sizes.count > 1 {
                        Segmented(options: kind.sizes.map { ($0, shortLabel($0)) }, selection: $size)
                    }
                    styleSection
                    detailsSection
                    Button { adding = true } label: { Label("Add to Home Screen", systemImage: "plus") }
                        .buttonStyle(.pill(.primary, fill: true))
                    Text("Changes show on your widgets right away.")
                        .mutedStyle()
                        .frame(maxWidth: .infinity)
                }
                .padding(16)
                .padding(.bottom, 30)
            }
        }
        .background(Palette.surface)
        .onAppear {
            size = kind.sizes.first ?? .small
            snapshot = WidgetBridge.snapshot(from: store)
        }
        .onReceive(NotificationCenter.default.publisher(for: WidgetBridge.imagesChanged)) { _ in
            snapshot = WidgetBridge.snapshot(from: store)
        }
        .sheet(isPresented: $adding) {
            AddWidgetSheet(kind: kind).presentationDetents([.medium, .large])
        }
    }

    /// The preview, on wallpaper, at the chosen size.
    private var stage: some View {
        WidgetWallpaper(photo: size.isAccessory ? "assets/media/cities/tokyo.jpg" : "assets/media/cities/san-francisco.jpg",
                        dim: size.isAccessory ? 0.35 : 0.08) {
            WidgetPreview(kind: kind, size: size, snapshot: snapshot, prefs: prefs, scale: size == .large ? 0.86 : 1)
                .padding(.vertical, size == .large ? 18 : 34)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: size)
                .animation(.easeInOut(duration: 0.25), value: prefs)
        }
    }

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Style")
            HStack(spacing: 12) {
                ForEach(kind.styles) { style in
                    WidgetsStyleSwatch(style: style, kind: kind, snapshot: snapshot, selected: prefs.style(for: kind) == style) {
                        Haptics.tap()
                        store.update { s in s.widgetPrefs.styles[kind.rawValue] = style }
                    }
                }
                Spacer(minLength: 0)
            }
            if size.isAccessory {
                Text("Lock Screen widgets take the color of your Lock Screen.")
                    .mutedStyle().padding(.top, 10)
            }
        }
    }

    @ViewBuilder private var detailsSection: some View {
        switch kind {
        case .streak:
            toggle("Show this week", detail: "Seven days with a mark for each one you explored",
                   isOn: Binding(get: { prefs.showWeek }, set: { v in store.update { $0.widgetPrefs.showWeek = v } }))
        case .adventure:
            toggle("Show why it was picked", detail: "The reason from what Odyssey has learned you like",
                   isOn: Binding(get: { prefs.showReason }, set: { v in store.update { $0.widgetPrefs.showReason = v } }))
        case .coins:
            toggle("Show the next rank", detail: "A bar toward your next rank under the balance",
                   isOn: Binding(get: { prefs.showNextRank }, set: { v in store.update { $0.widgetPrefs.showNextRank = v } }))
        case .friends:
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "Details")
                Stepper(value: Binding(get: { prefs.friendCount }, set: { v in store.update { $0.widgetPrefs.friendCount = v } }), in: 1...3) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Friends on the medium size").font(.system(size: 15, weight: .semibold))
                        Text("\(prefs.friendCount) at a time").mutedStyle()
                    }
                }
                .softCard()
            }
        case .quest, .leaderboard:
            EmptyView()
        }
    }

    private func toggle(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Details")
            Toggle(isOn: isOn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold))
                    Text(detail).mutedStyle()
                }
            }
            .tint(Palette.accent)
            .softCard()
        }
    }

    private func shortLabel(_ size: WidgetSize) -> String {
        switch size {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .circular: return "Circle"
        case .rectangular: return "Lock"
        case .inline: return "Inline"
        }
    }
}

/// A round swatch showing a style's colors.
struct WidgetsStyleSwatch: View {
    var style: WidgetStyle
    var kind: OdysseyWidgetKind
    var snapshot: WidgetSnapshot
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                swatch
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
                    .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .strokeBorder(selected ? Palette.accent : .clear, lineWidth: 2.5).padding(-4))
                Text(style.label).font(.system(size: 12, weight: selected ? .bold : .medium))
                    .foregroundStyle(selected ? Palette.ink : Palette.muted)
            }
        }
        .buttonStyle(PressStyle())
    }

    /// The map style shows a corner of today's map; the others show their background.
    @ViewBuilder private var swatch: some View {
        if style == .map, let pick = snapshot.adventure {
            AdventureMapPanel(pick: pick, pin: 22)
        } else {
            OdysseyWidgetBackground(kind: kind, style: style, snapshot: snapshot)
        }
    }
}
