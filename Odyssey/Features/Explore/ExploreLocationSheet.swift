//
//  ExploreLocationSheet.swift
//  Odyssey
//
//  Where the Explore tab is looking. The picker offers your real location
//  (iOS asks first) and the prepared areas, so a demo can jump from
//  Dogpatch to Shibuya and show the recommendations follow you while your
//  taste stays the same.
//  Ported from discover-location.js.
//

import Foundation
import SwiftUI
import UIKit

struct ExploreLocationSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(LocationService.self) private var location
    @Environment(ToastCenter.self) private var toast
    @Environment(\.dismiss) private var dismiss

    @State private var finding = false
    @State private var denied = false

    var body: some View {
        let current = store.exploreLocation
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Explore near").titleStyle(22).padding(.bottom, 8)
                row(id: "gps", label: current.gps ? current.label : "Use my location",
                    sub: finding ? "Finding you" : "Real places around you from OpenStreetMap",
                    icon: "location", current: current.id) { useDevice() }
                if denied || location.isDenied { deniedNote }
                Text("Jump to")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.muted)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                let places = NearbyService.locations(store)
                ForEach(places.indices, id: \.self) { i in
                    let loc = places[i]
                    let far = loc.center.distance(to: store.home.center) > 25_000
                    row(id: loc.id, label: loc.label, sub: far ? "Travel, your taste comes with you" : "Near home",
                        icon: loc.id.hasPrefix("tokyo") ? "plane" : "pin", current: current.id) {
                        Haptics.tap()
                        NearbyService.choose(loc.id, store: store)
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, Space.s5)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
    }

    private func row(id: String, label: String, sub: String, icon: String, current: String,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Space.s3) {
                Image(systemName: Icon.symbol(icon))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 40, height: 40)
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                    Text(sub).font(.system(size: 13)).foregroundStyle(Palette.muted).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if current == id {
                    Image(systemName: "checkmark").font(.system(size: 16, weight: .bold)).foregroundStyle(Palette.ink)
                }
            }
            .padding(.vertical, Space.s3)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }

    /// An honest note when location is off, with a way to turn it on.
    private var deniedNote: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Location is off for Odyssey. Turn it on in Settings to explore the real places around you.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.ink2)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .buttonStyle(.pill(.primary, height: 36))
        }
        .softCard(padding: 14, radius: Radius.md)
        .padding(.bottom, 4)
    }

    private func useDevice() {
        guard !finding else { return }
        if location.isDenied {
            denied = true
            return
        }
        finding = true
        toast.show("Finding you", icon: "locate")
        Task {
            let ok = await NearbyService.useDevice(store: store, location: location)
            finding = false
            if ok {
                dismiss()
            } else {
                denied = true
                toast.show("Location is off. Allow it in Settings to explore near you.", icon: "lock")
            }
        }
    }
}
