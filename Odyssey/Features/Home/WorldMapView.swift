import MapKit
import SwiftUI

struct WorldMapView: View {
    var isPreview = false
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(LocationService.self) private var location
    @Environment(\.animationsPaused) private var paused
    @State private var preview: Place?
    @State private var bounty: Bounty?
    @State private var amenity: AmenityPoint?
    @State private var showBounties = false
    /// The Home preview keeps its own camera, zoom and layers. Sharing the World Map's made
    /// the two maps (one hidden in another tab) keep moving and re-zooming each other.
    @State private var previewPosition: MapCameraPosition = .automatic
    @State private var previewZoom = 14
    @State private var previewAmenities: Set<String> = []
    /// The Find nearby chip that is on, if any.
    @State private var activeCategory: NearbyCategory?
    @State private var locating = false
    @State private var finding = false
    @State private var locationError: String?
    @State private var nearbyTask: Task<Void, Never>?
    @State private var nearbyRequestID = UUID()
    /// Verified Odyssey amenities found by the last Find nearby, shown with Apple's results.
    @State private var nearbyAmenities: [AmenityPoint] = []
    @State private var nearbySort: NearbySort = .distance
    /// The result card scrolled into view, which the map follows.
    @State private var nearbyFocus: String?

    var body: some View {
        @Bindable var map = store.worldMap
        ZStack {
            HomeMapView(position: isPreview ? $previewPosition : $map.position,
                        zoom: isPreview ? $previewZoom : $map.zoom, filter: "all", onPick: pick,
                        onBounty: { bounty = $0 }, amenities: isPreview ? previewAmenities : map.amenityKinds,
                        onAmenity: { amenity = $0 }, destinations: isPreview ? [] : map.results,
                        selectedDestination: isPreview ? nil : map.selectedPlace,
                        compassTop: isPreview ? nil : 132,
                        onCamera: {
                            guard !isPreview, !paused else { return }
                            map.region = $0
                            map.search.region = $0
                        })
                // Full screen: the map runs under the status bar and the tab bar.
                .ignoresSafeArea(edges: isPreview ? [] : .all)
            if isPreview {
                VStack {
                    HomeAmenityChips(kinds: $previewAmenities).padding(.top, 10)
                    Spacer()
                    HStack { HomeFootprintChip(); Spacer(); HomeMapLegend() }.padding(10)
                }
            }
        }
        // Controls float over the map instead of insetting it, so the map fills the screen.
        .overlay(alignment: .top) {
            if !isPreview { top.padding(.horizontal, 12).padding(.top, 6) }
        }
        .overlay(alignment: .bottom) {
            if !isPreview { bottom.padding(.horizontal, 12).padding(.bottom, 82) }
        }
        .background(Palette.surface)
        .onAppear {
            if isPreview {
                guard previewPosition == .automatic else { return }
                let center = store.demoFocus ?? store.deviceLocation ?? store.home.center
                previewPosition = .camera(MapCamera(centerCoordinate: center.location, distance: 1500, heading: 20, pitch: 55))
            } else {
                map.initialize(store: store)
                applyFocus(router.worldMapFocus)
            }
        }
        .onChange(of: router.worldMapFocus) { _, focus in
            guard !isPreview else { return }
            applyFocus(focus)
        }
        .task(id: paused) {
            guard !paused else { return }
            while !Task.isCancelled {
                await Cloud.shared.loadLiveBounties()
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
            }
        }
        .onDisappear { nearbyTask?.cancel() }
        .onChange(of: paused) { _, value in if value { nearbyTask?.cancel() } }
        .sheet(item: $preview) { place in
            HomePlacePreview(place: place, onBounty: { selected in
                preview = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { bounty = selected }
            })
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $bounty) { selected in
            BountySheet(bountyID: selected.id) { place in
                bounty = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { pick(place) }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $amenity) { point in
            AmenitySheet(point: point).presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBounties) { bountyList }
        .alert("Location unavailable", isPresented: Binding(get: { locationError != nil }, set: { if !$0 { locationError = nil } })) {
            if location.isDenied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            }
            Button("OK", role: .cancel) { locationError = nil }
        } message: { Text(locationError ?? "Please try again outdoors.") }
    }

    private var searchOpen: Bool {
        let search = store.worldMap.search
        // Only while there is text: a leftover error must never hide Set bounty and the chips.
        return !search.query.isEmpty
    }

    private var top: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Full width: nothing sits in the top corner over the map's own controls.
            LocationSearchField(search: store.worldMap.search) { place in
                clearNearby()
                pick(place)
            }
            if !searchOpen {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button {
                            Haptics.tap()
                            router.present(.setBounty(placeID: store.worldMap.selectedPlace?.id))
                        } label: {
                            Label("Set bounty", systemImage: "target")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14).frame(height: 38)
                                .background(Palette.accent, in: Capsule())
                                .shadow(color: Palette.accent.opacity(0.3), radius: 8, y: 3)
                        }
                        .buttonStyle(PressStyle(scale: 0.95))
                        .accessibilityIdentifier("worldMap.setBounty")
                        Button {
                            Haptics.tap()
                            showBounties = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "gift.fill").font(.system(size: 12, weight: .bold))
                                Text("Bounties").font(.system(size: 14, weight: .semibold))
                                if !store.openBounties.isEmpty {
                                    Text("\(store.openBounties.count)")
                                        .font(.system(size: 11, weight: .heavy)).monospacedDigit()
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5).frame(minWidth: 18, minHeight: 18)
                                        .background(Palette.danger, in: Capsule())
                                }
                            }
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 14).frame(height: 38)
                            .background(.regularMaterial, in: Capsule())
                            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                        }
                        .buttonStyle(PressStyle(scale: 0.95))
                        .accessibilityLabel("Available bounties, \(store.openBounties.count)")
                        ForEach(NearbyCategory.allCases) { category in
                            if category != .accessible || hasAccessibleData { nearbyChip(category) }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
                .padding(.horizontal, -12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .foregroundStyle(Palette.ink)
        .animation(.snappy(duration: 0.22), value: searchOpen)
    }

    private func nearbyChip(_ category: NearbyCategory) -> some View {
        let on = activeCategory == category
        return Button {
            Haptics.tap()
            nearbyTask?.cancel()
            if on {
                clearNearby()
            } else {
                activeCategory = category
                nearbyTask = Task { await find(category) }
            }
        } label: {
            HStack(spacing: 6) {
                if on && finding {
                    ProgressView().controlSize(.mini).tint(.white)
                } else {
                    Image(systemName: category.icon).font(.system(size: 12, weight: .bold))
                }
                Text(category.short).font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(on ? .white : Palette.ink)
            .padding(.horizontal, 14).frame(height: 38)
            .background { if on { Capsule().fill(Palette.ink) } else { Capsule().fill(.regularMaterial) } }
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        }
        .buttonStyle(PressStyle(scale: 0.95))
        .accessibilityLabel(category.title)
    }

    private var showsTray: Bool { activeCategory != nil && store.worldMap.nearbyTitle != nil && !finding }

    private var nearbyResults: [NearbyHit] {
        let icon = activeCategory?.icon ?? "mappin"
        var list = nearbyAmenities.map(NearbyHit.init(amenity:))
            + store.worldMap.results.map { NearbyHit(place: $0, icon: icon) }
        let here = store.here
        switch nearbySort {
        case .distance:
            list.sort { $0.coord.distance(to: here) < $1.coord.distance(to: here) }
        case .rating:
            // Rated places first, best first; unrated ones after, nearest first.
            list.sort { ($0.rating ?? -1, -$0.coord.distance(to: here)) > ($1.rating ?? -1, -$1.coord.distance(to: here)) }
        }
        return list
    }

    private var bottom: some View {
        VStack(alignment: .trailing, spacing: 10) {
            VStack(spacing: 0) {
                Button(action: toggle3D) {
                    Text(is3D ? "2D" : "3D").font(.system(size: 14, weight: .heavy))
                        .frame(width: 50, height: 50)
                }
                .accessibilityLabel("Toggle 3D map")
                Divider().frame(width: 30)
                Button { Task { await recenter() } } label: {
                    Group {
                        if locating { ProgressView().controlSize(.small) } else { Image(systemName: "location.fill").font(.system(size: 17, weight: .semibold)) }
                    }
                    .frame(width: 50, height: 50)
                }
                .disabled(locating)
                .accessibilityLabel("Current Location")
                .accessibilityIdentifier("worldMap.currentLocation")
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            .frame(maxWidth: .infinity, alignment: .trailing)
            if showsTray, let category = activeCategory {
                NearbyResultsTray(title: category.title, icon: category.icon, results: nearbyResults,
                                  sort: $nearbySort, focused: $nearbyFocus,
                                  onOpen: openResult, onGo: { NearbyService.directions(to: $0.destination) },
                                  onClose: clearNearby)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .foregroundStyle(Palette.ink)
        .animation(.snappy(duration: 0.25), value: showsTray)
        .onChange(of: nearbyFocus) { _, id in
            guard let id, let result = nearbyResults.first(where: { $0.id == id }) else { return }
            if case .place(let place) = result.source { store.worldMap.selectedPlace = place }
            store.worldMap.fly(to: result.coord, distance: 1400)
        }
        .onChange(of: nearbySort) { nearbyFocus = nil }
    }

    private func openResult(_ result: NearbyHit) {
        Haptics.tap()
        switch result.source {
        case .place(let place): pick(place)
        case .amenity(let point):
            store.worldMap.fly(to: point.coord, distance: 1200)
            amenity = point
        }
    }

    private var is3D: Bool { (store.worldMap.position.camera?.pitch ?? 55) > 10 }

    private func toggle3D() {
        Haptics.tap()
        let center = store.worldMap.region?.center ?? store.home.center.location
        let current = store.worldMap.position.camera
        withAnimation(.easeInOut(duration: 0.5)) {
            store.worldMap.position = .camera(MapCamera(centerCoordinate: center,
                distance: current?.distance ?? 1500, heading: current?.heading ?? 0,
                pitch: is3D ? 0 : 60))
        }
    }

    private func clearNearby() {
        nearbyTask?.cancel()
        activeCategory = nil
        finding = false
        nearbyAmenities = []
        nearbyFocus = nil
        store.worldMap.selectedPlace = nil
        store.worldMap.clearNearby()
    }

    private var hasAccessibleData: Bool {
        let center = store.worldMap.region.map { Coord($0.center) } ?? store.home.center
        return store.osmPlaces.values.contains {
            $0.tags?["entrance"] != nil && $0.tags?["wheelchair"] == "yes" && $0.coords.distance(to: center) < 5000
        }
    }

    private var bountyList: some View {
        NavigationStack {
            List {
                ForEach(store.openBounties) { item in
                    Button {
                        showBounties = false
                        store.worldMap.fly(to: item.center, distance: max(1500, item.radius * 4))
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { bounty = item }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text((item.isFunded ? "" : "Demo · ") + BountyText.whereText(item, store: store)).font(.headline)
                            Text("\(Format.money(item.pool)) · Up to \(item.maxExplorers ?? item.videos) explorers")
                            Text(BountyText.splitLine(item, store: store)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if store.openBounties.isEmpty { Text("No funded bounties are currently available.") }
            }
            .navigationTitle("Available Bounties").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showBounties = false } } }
        }
    }

    private func applyFocus(_ focus: String?) {
        switch focus {
        case "world": store.worldMap.fly(to: Coord(30, -30), distance: 25_000_000)
        case "usa": store.worldMap.fly(to: Coord(39.5, -105), distance: 8_000_000)
        case "trip": store.worldMap.fly(to: store.extras.demoTrip.coords, distance: 3000)
        default: break
        }
        // Consume the legacy focus once so a later tab switch preserves exploration.
        router.worldMapFocus = nil
    }

    private func pick(_ place: Place) {
        store.worldMap.select(place)
        preview = place
    }

    private func recenter() async {
        locating = true
        defer { locating = false }
        guard let coord = await location.currentLocation() else {
            locationError = location.isDenied ? "Allow location access in Settings to center on your position. You can still search anywhere." : "A GPS fix isn't available. Please try again."
            return
        }
        // Asking to see where you are means the map should follow the phone from now on.
        if !store.state.useDeviceLocation { store.update { $0.useDeviceLocation = true } }
        store.worldMap.fly(to: coord)
    }

    private func find(_ category: NearbyCategory) async {
        let requestID = UUID()
        nearbyRequestID = requestID
        finding = true
        defer { if nearbyRequestID == requestID { finding = false } }
        let center = store.worldMap.region.map { Coord($0.center) } ?? store.home.center
        store.worldMap.clearNearby()
        nearbyAmenities = []
        nearbyFocus = nil
        let known = store.amenityPoints.filter { $0.kind == category.rawValue && $0.coord.distance(to: center) < 5000 }
        if category == .accessible {
            let places = store.osmPlaces.values.filter {
                $0.tags?["entrance"] != nil && $0.tags?["wheelchair"] == "yes" && $0.coords.distance(to: center) < 5000
            }
            store.worldMap.results = Array(places)
        } else {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = category.query
            request.resultTypes = [.pointOfInterest]
            request.region = MKCoordinateRegion(center: center.location, latitudinalMeters: 7000, longitudinalMeters: 7000)
            if category == .parking { request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.parking]) }
            do {
                let response = try await MKLocalSearch(request: request).start()
                guard !Task.isCancelled else { return }
                store.worldMap.results = response.mapItems.filter { Coord($0.placemark.coordinate).distance(to: center) < 7000 }
                    .map { LocationSearch.register($0, store: store) }
            } catch {
                guard !Task.isCancelled else { return }
                if known.isEmpty { store.worldMap.nearbyTitle = "Search unavailable. Try again."; return }
            }
        }
        guard !Task.isCancelled else { return }
        store.worldMap.amenityKinds = [category.rawValue]
        // Keep the 30 closest, like a maps app, and frame the closest few so the
        // overview opens on what's actually near you rather than the whole city.
        store.worldMap.results.sort { $0.coords.distance(to: center) < $1.coords.distance(to: center) }
        store.worldMap.results = Array(store.worldMap.results.prefix(30))
        nearbyAmenities = Array(known.sorted { $0.coord.distance(to: center) < $1.coord.distance(to: center) }.prefix(30))
        let coords = (store.worldMap.results.map(\.coords) + nearbyAmenities.map(\.coord))
            .sorted { $0.distance(to: center) < $1.distance(to: center) }
        store.worldMap.nearbyTitle = coords.isEmpty ? "No nearby results for \(category.title)" : "\(category.title) · \(coords.count) results"
        store.worldMap.fit(Array(coords.prefix(6)) + [center], bottomRoom: 0.9)
    }
}

enum NearbyCategory: String, CaseIterable, Identifiable {
    case bathroom, parking, wifi, water, elevator, study, seating, accessible
    var id: String { rawValue }
    var title: String {
        switch self {
        case .bathroom: return "Nearest Bathroom"
        case .parking: return "Nearest Parking Garage / Structure"
        case .wifi: return "Nearest Wi-Fi"
        case .water: return "Nearest Water Fountain"
        case .elevator: return "Nearest Elevator"
        case .study: return "Study Spaces"
        case .seating: return "Cafés with Seating"
        case .accessible: return "Accessible Entrances"
        }
    }
    /// The label on the chip over the map.
    var short: String {
        switch self {
        case .bathroom: return "Bathrooms"
        case .parking: return "Parking"
        case .wifi: return "Wi-Fi"
        case .water: return "Water"
        case .elevator: return "Elevators"
        case .study: return "Study"
        case .seating: return "Cafés"
        case .accessible: return "Accessible"
        }
    }
    var query: String {
        switch self {
        case .bathroom: return "public restroom"
        case .parking: return "parking"
        case .wifi: return "public wifi"
        case .water: return "drinking water fountain"
        case .elevator: return "public elevator"
        case .study: return "library study space"
        case .seating: return "cafe seating"
        case .accessible: return "accessible entrance"
        }
    }
    var icon: String {
        switch self {
        case .parking: return "parkingsign.circle"
        case .study: return "books.vertical"
        case .seating: return "cup.and.saucer"
        case .accessible: return "figure.roll"
        default: return AmenityStyle.icon(rawValue)
        }
    }
}
