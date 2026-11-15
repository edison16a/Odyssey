//
//  ArrivalWatcher.swift
//  Odyssey
//
//  Notices when you walk up to a place. Walking past counts as exploring,
//  but a place is only yours once you check in with a photo, so when you
//  are within a few steps of one you have not checked in at today, a card
//  slides in with who has been there and a Check in button. Each place is
//  offered once per launch, so standing still does not keep nagging.
//

import Foundation
import Observation
import SwiftUI

@Observable
final class ArrivalWatcher {
    /// The place you are standing at, while its card is up.
    var current: Place?

    @ObservationIgnored private var offered: Set<String> = []
    /// Close enough to be standing at the door, allowing for GPS drift.
    private static let reach = 35.0

    /// Look around after the phone moved.
    func check(_ store: AppStore) {
        guard store.usingRealLocation, store.state.session.onboarded, let here = store.deviceLocation else { return }
        pick(store, here)
        // Make sure the places around you are loaded, then look again with them in.
        Task { [weak self] in
            await WorldPlaces.load(around: here, store: store)
            guard let self, store.deviceLocation == here else { return }
            self.pick(store, here)
        }
    }

    func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) { current = nil }
    }

    private func pick(_ store: AppStore, _ here: Coord) {
        if let shown = current, shown.coords.distance(to: here) > Self.reach * 2 { dismiss() }
        guard current == nil else { return }
        let world = store.osmPlaces.values.filter { $0.curated == nil && $0.coords.distance(to: here) < Self.reach }
        let curated = store.seed.places.filter { $0.coords.distance(to: here) < Self.reach }
        let fresh = (curated + world).filter { !offered.contains($0.id) && !store.checkedInToday($0) }
        guard let nearest = fresh.min(by: { $0.coords.distance(to: here) < $1.coords.distance(to: here) }) else { return }
        offered.insert(nearest.id)
        Haptics.tap()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { current = nearest }
    }
}
