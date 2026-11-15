//
//  AppStore+Cloud.swift
//  Odyssey
//
//  The store's side of Convex sync: server recommendations Explore can
//  rank with, and restoring a saved state after signing in on a new phone.
//

import Foundation

extension AppStore {
    /// Fold in a batch of server recommendations; cached rankings rebuild.
    func mergeCloudPicks(_ picks: [String: CloudPick]) {
        guard !picks.isEmpty else { return }
        cloudPicks.merge(picks) { _, new in new }
        invalidate()
    }

    func clearCloudPicks() {
        cloudPicks = [:]
        invalidate()
    }

    /// Ask Convex to rank these places, then rank them (server picks win when present).
    func rankForYouOnline(_ places: [Place]) async -> [Place] {
        await Cloud.shared.rank(places)
        return rankForYou(places)
    }

    /// Take the state saved in Convex, keeping what belongs to this phone.
    func restoreFromCloud(_ remote: AppState) {
        let local = state
        var next = remote
        next.session = local.session
        next.session.signedIn = true
        next.session.onboarded = local.session.onboarded || remote.session.onboarded
        next.widgetPrefs = local.widgetPrefs
        next.useDeviceLocation = local.useDeviceLocation
        next.trackInBackground = local.trackInBackground
        state = next
        featureCache = [:]
        cloudPicks = [:]
        invalidate()
        save()
    }
}
