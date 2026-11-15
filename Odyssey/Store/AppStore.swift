//
//  AppStore.swift
//  Odyssey
//
//  The one source of truth. Screens read store.state and change it with
//  store.update { $0... }, which saves to the phone and refreshes the home
//  screen widgets. The service logic from the mockup (visits, streaks,
//  taste, wallet, friends) lives in extensions next to this file.
//

import Foundation
import Observation

@Observable
final class AppStore {
    var state: AppState
    let seed = Seed.shared

    /// OpenStreetMap places seen this session, so a place page can open them by id.
    var osmPlaces: [String: Place] = [:]
    /// The phone's location, kept up to date by LocationService.
    var deviceLocation: Coord?
    var deviceLabel: String?
    /// Recommendations from Convex (Supermemory-backed), by place id.
    var cloudPicks: [String: CloudPick] = [:]

    @ObservationIgnored private let fileName = "odyssey-state.json"
    /// Previews and tests never touch the saved state or the widgets.
    @ObservationIgnored private var persists = true
    @ObservationIgnored private var publishWork: DispatchWorkItem?
    @ObservationIgnored private var saveWork: DispatchWorkItem?
    /// Bumped on every change, so cached results know when they are stale.
    @ObservationIgnored private(set) var version = 0
    @ObservationIgnored private var memos: [String: (version: Int, value: Any)] = [:]
    /// Taste features per place, keyed by the walkthrough vibe they depend on.
    @ObservationIgnored var featureCache: [String: (vibe: String, features: [String])] = [:]
    private static let saveQueue = DispatchQueue(label: "odyssey.save", qos: .utility)

    init() {
        if let saved = SharedStore.read(AppState.self, from: fileName) {
            state = saved
        } else {
            state = Seed.shared.initialState
            state.widgetPrefs = SharedStore.prefs()
        }
    }

    /// For previews and tests: a fresh copy of the seeded state that is never saved.
    init(preview: Bool) {
        persists = false
        state = Seed.shared.initialState
        state.session.signedIn = true
        state.session.onboarded = true
    }

    /// Change state, save it and let the widgets know.
    func update(_ change: (inout AppState) -> Void) {
        change(&state)
        version += 1
        save()
    }

    /// Cached results rebuild on the next read (after server data arrives, say).
    func invalidate() {
        version += 1
    }

    /// Work out a value once per change of state (and position), then reuse it.
    /// Keeps lists like "picked for you" and the feed from being rebuilt on every redraw.
    func memo<T>(_ key: String, _ make: () -> T) -> T {
        let stamp = version &* 31 &+ (deviceLocation.map { Int($0.lat * 2000) &+ Int($0.lng * 2000) } ?? 0)
        if let hit = memos[key], hit.version == stamp, let value = hit.value as? T { return value }
        let value = make()
        memos[key] = (stamp, value)
        return value
    }

    /// Saving waits for a quiet moment and writes on a background queue, so taps never wait on the disk.
    func save() {
        guard persists else { return }
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.flush() }
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
        scheduleWidgetRefresh()
        Cloud.shared.stateChanged()
    }

    /// Write the current state now, off the main thread.
    func flush() {
        guard persists else { return }
        saveWork?.cancel()
        let snapshot = state
        let name = fileName
        AppStore.saveQueue.async { SharedStore.write(snapshot, to: name) }
    }

    /// Back to the seeded fixture, like the mockup's reset. Your name, handle and
    /// profile photo stay, and so do your widget and location settings.
    func reset() {
        let keep = state
        state = seed.initialState
        state.session.signedIn = true
        state.session.onboarded = true
        state.session.email = keep.session.email
        state.user.name = keep.user.name
        state.user.handle = keep.user.handle
        state.user.avatar = keep.user.avatar
        state.widgetPrefs = keep.widgetPrefs
        state.useDeviceLocation = keep.useDeviceLocation
        version += 1
        featureCache = [:]
        save()
    }

    /// Widgets refresh once things settle, not on every tap.
    private func scheduleWidgetRefresh() {
        publishWork?.cancel()
        // A work item's block is not main actor isolated, but it runs on the main queue.
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                WidgetBridge.publish(from: self)
            }
        }
        publishWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }
}
