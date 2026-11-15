//
//  WidgetsGalleryView.swift
//  Odyssey
//
//  Every widget Odyssey offers, laid out on a real wallpaper the way they
//  look on a phone: the home screen, the Lock Screen, and the adventure
//  Live Activity. Each widget opens its editor, and the Live Activity can
//  be tried right here with today's adventure.
//

import Combine
import Foundation
import SwiftUI

struct WidgetsGalleryView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toast
    @State private var snapshot = WidgetSnapshot.placeholder
    @State private var adding: OdysseyWidgetKind?

    private var prefs: WidgetPrefs { store.state.widgetPrefs }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Widgets", back: { router.pop() })
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    homeScreen
                    Text("Tap a widget to change how it looks. Globie changes mood with your streak.")
                        .mutedStyle()
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 16)
                    SectionHeader(title: "Lock Screen").padding(.horizontal, 16)
                    lockScreen
                    SectionHeader(title: "All widgets").padding(.horizontal, 16).padding(.top, 28)
                    VStack(spacing: 12) {
                        ForEach(OdysseyWidgetKind.allCases) { kind in
                            WidgetsKindRow(kind: kind, snapshot: snapshot, prefs: prefs,
                                           customize: { router.push(.widgetEditor(kind)) },
                                           add: { adding = kind })
                        }
                    }
                    .padding(.horizontal, 16)
                    WidgetsLiveActivityCard(snapshot: snapshot, start: startLiveActivity)
                        .padding(.horizontal, 16)
                        .padding(.top, 28)
                    Color.clear.frame(height: 40)
                }
            }
        }
        .background(Palette.surface)
        .onAppear { snapshot = WidgetBridge.snapshot(from: store) }
        .onChange(of: store.state.widgetPrefs) { _, _ in snapshot = WidgetBridge.snapshot(from: store) }
        .onReceive(NotificationCenter.default.publisher(for: WidgetBridge.imagesChanged)) { _ in
            snapshot = WidgetBridge.snapshot(from: store)
        }
        .sheet(item: $adding) { kind in
            AddWidgetSheet(kind: kind).presentationDetents([.medium, .large])
        }
    }

    private var homeScreen: some View {
        WidgetWallpaper {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    tile(.streak, .small)
                    tile(.coins, .small)
                }
                tile(.adventure, .medium)
                tile(.friends, .medium)
                OdysseyMark(size: 38)
                    .frame(width: 56, height: 56)
                    .background(Palette.ink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(8)
                    .background(.white.opacity(0.3), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.top, 6)
            }
            .padding(.vertical, 22)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var lockScreen: some View {
        WidgetWallpaper(photo: "assets/media/cities/tokyo.jpg", dim: 0.3) {
            VStack(spacing: 10) {
                WidgetPreview(kind: .streak, size: .inline, snapshot: snapshot, prefs: prefs)
                Text("9:41").font(.system(size: 84, weight: .bold)).tracking(-3).foregroundStyle(.white)
                HStack(spacing: 10) {
                    Button { router.push(.widgetEditor(.streak)) } label: {
                        WidgetPreview(kind: .streak, size: .circular, snapshot: snapshot, prefs: prefs)
                    }
                    Button { router.push(.widgetEditor(.adventure)) } label: {
                        WidgetPreview(kind: .adventure, size: .rectangular, snapshot: snapshot, prefs: prefs)
                    }
                }
                .buttonStyle(PressStyle())
                Spacer(minLength: 24)
                if let pick = snapshot.adventure {
                    AdventureActivityView(attributes: demoAttributes(pick), state: demoState(pick))
                        .background(Palette.ink.opacity(0.9), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .padding(.horizontal, 12)
                }
            }
            .padding(.top, 26)
            .padding(.bottom, 14)
        }
        .padding(.horizontal, 16)
    }

    private func tile(_ kind: OdysseyWidgetKind, _ size: WidgetSize) -> some View {
        Button { router.push(.widgetEditor(kind)) } label: {
            WidgetPreview(kind: kind, size: size, snapshot: snapshot, prefs: prefs)
        }
        .buttonStyle(PressStyle())
    }

    private func demoAttributes(_ pick: AdventurePick) -> AdventureActivityAttributes {
        AdventureActivityAttributes(placeID: pick.id, placeName: pick.name, kind: pick.kind, symbol: pick.symbol,
                                    reward: pick.coins, isFirst: pick.isFirst, tierID: snapshot.tier.id)
    }

    private func demoState(_ pick: AdventurePick) -> AdventureActivityAttributes.ContentState {
        AdventureActivityAttributes.ContentState(stage: .heading, distanceMeters: pick.distanceMeters, progress: 0.35,
                                                 coinsEarned: 0, streakDays: snapshot.streakDays,
                                                 message: "\(pick.walkMinutes) min walk away")
    }

    private func startLiveActivity() {
        guard let id = snapshot.adventure?.id, let place = store.place(id) else { return }
        guard LiveActivityService.shared.enabled else {
            toast.show("Turn on Live Activities for Odyssey in Settings", icon: "gear")
            return
        }
        LiveActivityService.shared.start(place: place, store: store)
        toast.show("Lock your phone to see it", icon: "lock")
    }
}
