//
//  LiveActivityService.swift
//  Odyssey
//
//  Runs the adventure Live Activity. It starts when you head out to a place
//  (Directions, or starting a check-in), counts the distance down on the
//  Lock Screen and in the Dynamic Island as you walk, switches to "You're
//  here" once you are close, then shows the coins and streak after the
//  check-in and dismisses itself a little later.
//

import ActivityKit
import Foundation

@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()

    private var activity: Activity<AdventureActivityAttributes>?
    private var target: Coord?
    private var startDistance: Double = 1
    private var state: AdventureActivityAttributes.ContentState?

    var isRunning: Bool { activity != nil }
    var placeID: String? { activity?.attributes.placeID }

    var enabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// A relaunch forgets the activity started before it. Pick the newest one back up so a
    /// check-in can still complete and end it, and end any others so none linger on the Lock Screen.
    private init() {
        let running = Activity<AdventureActivityAttributes>.activities.filter { $0.activityState == .active || $0.activityState == .stale }
        if let last = running.last {
            activity = last
            state = last.content.state
        }
        for extra in running.dropLast() {
            Task { await extra.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// Start (or retarget) the adventure for a place.
    func start(place: Place, store: AppStore) {
        let distance = store.metres(to: place)
        if let activity, activity.attributes.placeID == place.id {
            // Picked up after a relaunch: aim the distance updates at the place again.
            if target == nil {
                target = place.coords
                startDistance = max(distance, 1)
            }
            return
        }
        end(immediately: true)
        guard enabled else { return }
        let first = store.status(of: place).status == .new
        let attributes = AdventureActivityAttributes(
            placeID: place.id, placeName: place.name, kind: store.placeKind(place).label,
            symbol: Icon.symbol(store.placeKind(place).icon),
            reward: Rewards.checkIn.coins + (first ? Rewards.first.coins : 0), isFirst: first, tierID: store.streakTier.id)
        let initial = AdventureActivityAttributes.ContentState(
            stage: distance < 60 ? .arrived : .heading, distanceMeters: distance, progress: distance < 60 ? 1 : 0,
            coinsEarned: 0, streakDays: store.state.streak.days,
            message: distance < 60 ? "Check in to collect" : "\(Format.walkTime(distance)) away")
        target = place.coords
        startDistance = max(distance, 1)
        state = initial
        do {
            activity = try Activity.request(attributes: attributes,
                                            content: ActivityContent(state: initial, staleDate: Date().addingTimeInterval(3600)),
                                            pushType: nil)
        } catch {
            activity = nil
        }
    }

    /// Distance updates from LocationService while heading out.
    func locationChanged(_ coord: Coord) {
        guard let target, var next = state, next.stage == .heading || next.stage == .arrived else { return }
        let distance = coord.distance(to: target)
        next.distanceMeters = distance
        next.progress = min(1, max(0, 1 - distance / startDistance))
        if distance < 60 {
            next.stage = .arrived
            next.message = "Check in to collect"
        } else {
            next.stage = .heading
            next.message = "\(Format.walkTime(distance)) away"
        }
        push(next)
    }

    /// The photo pair is taken.
    func captured() {
        guard var next = state else { return }
        next.stage = .captured
        next.progress = 1
        next.message = "Posting your adventure"
        push(next)
    }

    /// The check-in is done: show what was earned, then go away after a while.
    func complete(coins: Int, streak: Int) {
        guard var next = state else { return }
        next.stage = .complete
        next.progress = 1
        next.coinsEarned = coins
        next.streakDays = streak
        next.message = coins > 0 ? "+\(coins) coins earned" : "Explored again today"
        push(next)
        let current = activity
        Task {
            await current?.end(ActivityContent(state: next, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(15 * 60)))
        }
        activity = nil
        state = nil
        target = nil
    }

    func end(immediately: Bool = false) {
        guard let current = activity else { return }
        let last = state
        activity = nil
        state = nil
        target = nil
        Task {
            await current.end(last.map { ActivityContent(state: $0, staleDate: nil) }, dismissalPolicy: immediately ? .immediate : .default)
        }
    }

    private func push(_ next: AdventureActivityAttributes.ContentState) {
        state = next
        guard let current = activity else { return }
        Task { await current.update(ActivityContent(state: next, staleDate: Date().addingTimeInterval(3600))) }
    }
}
