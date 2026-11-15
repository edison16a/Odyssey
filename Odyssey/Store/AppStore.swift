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
    /// Everything the app remembers. Reading it from a screen makes that screen redraw
    /// when it changes, so changes nothing on screen depends on go through updateQuietly.
    @ObservationIgnored var state: AppState {
        _read {
            access(keyPath: \.state)
            yield raw
        }
        set {
            withMutation(keyPath: \.state) { raw = newValue }
        }
    }
    @ObservationIgnored private var raw: AppState
    /// Bumped when a new stretch of walking is saved. Footprints are recorded quietly
    /// (see updateQuietly), and the few screens that draw them watch this instead.
    private(set) var footprintsRevision = 0
    let seed = Seed.shared

    /// OpenStreetMap places seen this session, so a place page can open them by id.
    var osmPlaces: [String: Place] = [:]
    /// Demo amenity tags by place id (wifi, seating, bathroom...), from Convex.
    var placeFeatures: [String: [String]] = [:]
    /// Public bathrooms, elevators, water and wifi for the map, from Convex.
    var amenityPoints: [AmenityPoint] = []
    /// Whop deals by place id, from Convex.
    var deals: [String: [Deal]] = [:]
    /// Bounties every explorer has paid for and pushed live, from Convex.
    var liveBounties: [Bounty] = []
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
    /// Amenity tags per place, keyed by how many server tags were loaded when they were worked out.
    @ObservationIgnored var amenityCache: [String: (stamp: Int, tags: [String])] = [:]
    private static let saveQueue = DispatchQueue(label: "odyssey.save", qos: .utility)

    init() {
        if let saved = SharedStore.read(AppState.self, from: fileName) {
            raw = saved
        } else {
            raw = Seed.shared.initialState
            raw.widgetPrefs = SharedStore.prefs()
        }
    }

    /// For previews and tests: a fresh copy of the seeded state that is never saved.
    init(preview: Bool) {
        persists = false
        raw = Seed.shared.initialState
        raw.session.signedIn = true
        raw.session.onboarded = true
    }

    /// Change state, save it and let the widgets know.
    func update(_ change: (inout AppState) -> Void) {
        withMutation(keyPath: \.state) { change(&raw) }
        version += 1
        save()
    }

    /// Change state without redrawing every screen that reads it. For bookkeeping that
    /// happens on its own while you use the app (walked footprints, places Explore has
    /// shown you): redrawing all four tabs for those made scrolling hitch. Anything a
    /// screen shows must use update, or bump a revision the screen watches.
    func updateQuietly(footprints: Bool = false, _ change: (inout AppState) -> Void) {
        change(&raw)
        if footprints { footprintsRevision += 1 }
        save(widgets: false)
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
    func save(widgets: Bool = true) {
        guard persists else { return }
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.flush() }
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
        if widgets { scheduleWidgetRefresh() }
        Cloud.shared.stateChanged()
    }

    /// Write the current state now, off the main thread.
    func flush() {
        guard persists else { return }
        saveWork?.cancel()
        let snapshot = raw
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
