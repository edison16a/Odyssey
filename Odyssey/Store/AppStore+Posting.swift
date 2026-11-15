//
//  AppStore+Posting.swift
//  Odyssey
//
//  Small lookups the post flow needs: the closest place to you, for the
//  camera's sample photo and the top of "Where are you?", and the place you
//  checked in at most recently today, which a video walkthrough is for.
//

import Foundation

extension AppStore {
    /// The closest place you could check in at right now.
    var nearestPlace: Place? {
        let curated = nearbyPlaces.filter { $0.category != "transit" }
        let world = osmPlaces.values.filter { $0.curated == nil && $0.coords.distance(to: here) < 600 }
        return (curated + world).min { here.distance(to: $0.coords) < here.distance(to: $1.coords) }
    }

    /// The place you checked in at most recently today.
    var lastCheckInToday: Place? {
        let today = Format.today()
        if let post = state.myPosts.first(where: { state.checkins[$0.placeId] == today }) {
            return place(post.placeId)
        }
        return state.checkins.first { $0.value == today }.flatMap { place($0.key) }
    }
}
