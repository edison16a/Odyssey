//
//  LocationService+Footprints.swift
//  Odyssey
//
//  Turns location fixes into footprints. Only fixes that look like walking
//  count: accurate to 50 m or better and slower than a jog, so a car ride
//  does not paint the whole freeway. Points are saved in small batches, not
//  one write per fix, and whatever is waiting is saved when the app leaves
//  the screen.
//
//  With background tracking on (Settings), the phone keeps recording while
//  the app is closed. That needs "Always" permission and the location
//  background mode, which the app checks before switching it on.
//

import CoreLocation
import Foundation

extension LocationService {
    /// Faster than this is a bike, bus or car, so it does not count as explored.
    private static let walkingSpeed = 4.2
    private static let batchSize = 8
    private static let batchSeconds = 20.0

    func recordSteps(_ locations: [CLLocation]) {
        guard let store, store.state.useDeviceLocation, store.state.session.onboarded else { return }
        for fix in locations where fix.horizontalAccuracy > 0 && fix.horizontalAccuracy <= 50 {
            if fix.speed > Self.walkingSpeed { continue }
            pendingSteps.append(Coord(fix.coordinate))
        }
        if pendingSteps.count >= Self.batchSize || Date().timeIntervalSince(lastStepFlush) > Self.batchSeconds {
            flushSteps()
        }
    }

    /// Save every waiting point now.
    func flushSteps() {
        lastStepFlush = Date()
        guard !pendingSteps.isEmpty, let store else { return }
        let steps = pendingSteps
        pendingSteps.removeAll()
        store.recordFootprints(steps)
    }

    /// True when the app was built with the location background mode.
    private var canTrackInBackground: Bool {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        return modes.contains("location")
    }

    /// Turn background recording on or off, asking for Always permission first.
    func setBackgroundTracking(_ on: Bool) {
        store?.update { s in s.trackInBackground = on }
        if on && authorization != .authorizedAlways { manager.requestAlwaysAuthorization() }
        applyBackgroundTracking(on)
    }

    func applyBackgroundTracking(_ on: Bool) {
        let allowed = on && canTrackInBackground
        manager.allowsBackgroundLocationUpdates = allowed
        manager.pausesLocationUpdatesAutomatically = !allowed
        manager.showsBackgroundLocationIndicator = allowed
    }

    /// "Always" permission granted, so recording can carry on with the app closed.
    var tracksInBackground: Bool {
        (store?.state.trackInBackground ?? false) && authorization == .authorizedAlways && canTrackInBackground
    }
}
