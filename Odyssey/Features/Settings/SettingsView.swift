//
//  SettingsView.swift
//  Odyssey
//
//  Settings, opened from the gear on your profile. Location (follow the
//  phone, permission status, and which prepared area stands in when you
//  are away from both), camera access, the notification and sharing
//  switches from the mockup, photo credits, resetting the demo and signing
//  out.
//

import Foundation
import AVFoundation
import CoreLocation
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(LocationService.self) private var location
    @Environment(ToastCenter.self) private var toast
    @AppStorage("odyssey.settings.notifications") private var notifications = true
    @AppStorage("odyssey.settings.share") private var shareAdventures = true
    @State private var cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var confirmReset = false

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Settings", back: { router.pop() })
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    group("Location") {
                        SettingsToggleRow(icon: "location", title: "Use my real location",
                                          sub: "Distances and the home map follow your phone", isOn: useDeviceLocation)
                        SettingsToggleRow(icon: "footprints", title: "Record walks in the background",
                                          sub: "Keep drawing the streets you walk with the app closed", isOn: trackInBackground)
                        SettingsRow(icon: "location-fill", title: "Location access", value: locationText,
                                    action: locationTap)
                        areaPicker
                    }
                    group("Camera") {
                        SettingsRow(icon: "camera", title: "Camera access", value: cameraText,
                                    action: cameraTap)
                    }
                    group("Sharing") {
                        SettingsToggleRow(icon: "bell", title: "Notifications", sub: nil, isOn: $notifications)
                        SettingsToggleRow(icon: "shield", title: "Share my adventures with friends", sub: nil, isOn: $shareAdventures)
                        SettingsRow(icon: "widget", title: "Home screen widgets", value: nil) { router.push(.widgets) }
                        SettingsRow(icon: "compass", title: "Demo guide", value: nil) { router.push(.demoGuide) }
                    }
                    group("Photo credits") { SettingsCredits() }
                    group("Account") {
                        SettingsRow(icon: "refresh", title: "Reset app data", value: nil) { confirmReset = true }
                        SettingsRow(icon: "logout", title: "Sign out", value: nil, danger: true) { signOut() }
                    }
                    group("Admin") {
                        SettingsRow(icon: "sliders", title: "Admin", value: "Stats, scenes, reset") { router.push(.admin) }
                    }
                    VStack(spacing: 4) {
                        Text(Brand.motto)
                        Text(versionText).monospacedDigit()
                    }
                    .font(.system(size: 11)).foregroundStyle(Palette.faint)
                    .frame(maxWidth: .infinity).padding(.vertical, 30)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Palette.surface)
        .onAppear { cameraStatus = AVCaptureDevice.authorizationStatus(for: .video) }
        .confirmationDialog("Reset app data?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive, action: reset)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your coins, streak, check-ins and cosmetics go back to the starting demo.")
        }
    }

    /// "Version 6.5 (build 1)", read from the app bundle.
    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(version) (build \(build))"
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).labelStyle().padding(.bottom, 4)
            VStack(spacing: 0) { content() }
        }
        .padding(.top, 24)
    }

    private var areaPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("When you are away from San Francisco and Berkeley, Odyssey shows this area")
                .font(.system(size: 13)).foregroundStyle(Palette.muted)
            Segmented(options: [("sf", "San Francisco"), ("berkeley", "Berkeley")],
                      selection: Binding(get: { store.state.demoArea }, set: { area in store.update { $0.demoArea = area } }))
        }
        .padding(.vertical, Space.s3)
    }

    /// Saved through the store so the choice survives a relaunch.
    private var useDeviceLocation: Binding<Bool> {
        Binding(get: { store.state.useDeviceLocation }, set: { on in store.update { $0.useDeviceLocation = on } })
    }

    private var trackInBackground: Binding<Bool> {
        Binding(get: { store.state.trackInBackground }, set: { location.setBackgroundTracking($0) })
    }

    private var locationText: String {
        switch location.authorization {
        case .authorizedAlways, .authorizedWhenInUse: return store.deviceLabel ?? "On"
        case .denied, .restricted: return "Off"
        default: return "Not asked yet"
        }
    }

    private var cameraText: String {
        switch cameraStatus {
        case .authorized: return "On"
        case .denied, .restricted: return "Off"
        default: return "Not asked yet"
        }
    }

    /// Tapping the row asks for access, or opens Settings once it was turned off.
    private var locationTap: (@MainActor () -> Void)? {
        if location.isAuthorized { return nil }
        return { locationAction() }
    }

    private var cameraTap: (@MainActor () -> Void)? {
        if cameraStatus == .authorized { return nil }
        return { cameraAction() }
    }

    private func locationAction() {
        if location.isDenied { openSettings() } else { location.request() }
    }

    private func cameraAction() {
        if cameraStatus == .notDetermined {
            Task {
                _ = await AVCaptureDevice.requestAccess(for: .video)
                cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            }
        } else {
            openSettings()
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }

    private func reset() {
        store.reset()
        router.popToRoot()
        toast.show("Fresh start", icon: "refresh")
    }

    private func signOut() {
        router.popToRoot()
        router.tab = .home
        store.update { $0.session.signedIn = false }
        Task { await Cloud.shared.signOut() }
    }
}

struct SettingsRow: View {
    var icon: String
    var title: String
    var value: String?
    var danger = false
    var action: (@MainActor () -> Void)?

    var body: some View {
        Button { action?() } label: {
            HStack(spacing: Space.s3) {
                Image(systemName: Icon.symbol(icon)).font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(danger ? Palette.danger : Palette.ink)
                    .frame(width: 36, height: 36).background(Palette.surface2, in: Circle())
                Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(danger ? Palette.danger : Palette.ink)
                Spacer(minLength: 8)
                if let value { Text(value).font(.system(size: 13)).foregroundStyle(Palette.muted).lineLimit(1) }
                if action != nil {
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.faint)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

struct SettingsToggleRow: View {
    var icon: String
    var title: String
    var sub: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: Space.s3) {
                Image(systemName: Icon.symbol(icon)).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                    .frame(width: 36, height: 36).background(Palette.surface2, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.ink)
                    if let sub { Text(sub).font(.system(size: 12)).foregroundStyle(Palette.muted) }
                }
            }
        }
        .tint(Palette.accent)
        .padding(.vertical, 10)
    }
}
