//
//  LocationService.swift
//  Odyssey
//
//  The phone's real location. It asks for "while using" permission, keeps
//  the store's deviceLocation current, names the neighbourhood for labels
//  ("Dogpatch, San Francisco"), and tells the adventure Live Activity how
//  far is left whenever you move. Walking is recorded as footprints in
//  LocationService+Footprints.swift.
//

import CoreLocation
import Foundation
import MapKit
import Observation

@Observable
final class LocationService: NSObject {
    var authorization: CLAuthorizationStatus = .notDetermined
    var coordinate: Coord?
    var label: String?
    var lastError: String?

    @ObservationIgnored let manager = CLLocationManager()
    @ObservationIgnored weak var store: AppStore?
    /// Walked points waiting to be saved as footprints, and when they last were.
    @ObservationIgnored var pendingSteps: [Coord] = []
    @ObservationIgnored var lastStepFlush = Date()
    @ObservationIgnored private var lastNamed: Coord?
    @ObservationIgnored private var waiters: [CheckedContinuation<Coord?, Never>] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 20
        authorization = manager.authorizationStatus
    }

    func attach(_ store: AppStore) {
        self.store = store
        manager.activityType = .fitness
        applyBackgroundTracking(store.state.trackInBackground)
        if isAuthorized { manager.startUpdatingLocation() }
    }

    var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    var isDenied: Bool { authorization == .denied || authorization == .restricted }

    /// Ask for permission if needed, then start following the phone.
    func request() {
        if authorization == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if isAuthorized {
            manager.startUpdatingLocation()
        }
    }

    /// One fresh fix, waiting up to a few seconds. Nil when permission is off or it times out.
    func currentLocation() async -> Coord? {
        if let coordinate, isAuthorized { return coordinate }
        request()
        if isDenied { return nil }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
            manager.requestLocation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
                self?.finishWaiters(with: self?.coordinate)
            }
        }
    }

    private func finishWaiters(with value: Coord?) {
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume(returning: value) }
    }

    /// "Dogpatch, San Francisco" for a coordinate, or "Near you".
    func name(_ coord: Coord) async -> String {
        let location = CLLocation(latitude: coord.lat, longitude: coord.lng)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return "Near you" }
        let near = placemark.subLocality ?? placemark.name
        let city = placemark.locality ?? placemark.subAdministrativeArea
        let parts = [near, city].compactMap { $0 }.reduce(into: [String]()) { list, part in
            if !list.contains(part) { list.append(part) }
        }
        return parts.isEmpty ? "Near you" : parts.joined(separator: ", ")
    }

    private func handle(_ location: CLLocation) {
        let coord = Coord(location.coordinate)
        coordinate = coord
        // Small jitters do not change anything on screen, so they do not redraw the app.
        if let old = store?.deviceLocation, old.distance(to: coord) < 25 {
            finishWaiters(with: coord)
            LiveActivityService.shared.locationChanged(coord)
            return
        }
        store?.deviceLocation = coord
        finishWaiters(with: coord)
        LiveActivityService.shared.locationChanged(coord)
        if lastNamed == nil || lastNamed!.distance(to: coord) > 400 {
            lastNamed = coord
            Task { [weak self] in
                guard let self else { return }
                let name = await self.name(coord)
                self.label = name
                self.store?.deviceLabel = name
            }
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if self.isAuthorized {
                self.manager.startUpdatingLocation()
            } else if self.isDenied {
                self.finishWaiters(with: nil)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in
            self.recordSteps(locations)
            self.handle(last)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            self.lastError = message
            self.finishWaiters(with: self.coordinate)
        }
    }
}
