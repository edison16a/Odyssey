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
    @State private var showInfo = false
    @State private var showNearby = false
    @State private var showBounties = false
    @State private var locating = false
    @State private var finding = false
    @State private var locationError: String?
    @State private var nearbyTask: Task<Void, Never>?
    @State private var nearbyRequestID = UUID()

    var body: some View {
        @Bindable var map = store.worldMap
        ZStack {
            HomeMapView(position: $map.position, zoom: $map.zoom, filter: "all", onPick: pick,
                        onBounty: { bounty = $0 }, amenities: map.amenityKinds,
                        onAmenity: { amenity = $0 }, destinations: map.results,
                        selectedDestination: map.selectedPlace,
                        onCamera: { if !paused { map.region = $0 } })
            if isPreview {
                VStack {
                    HomeAmenityChips(kinds: $map.amenityKinds).padding(.top, 10)
                    Spacer()
                    HStack { HomeFootprintChip(); Spacer(); HomeMapLegend() }.padding(10)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !isPreview { top.padding(.horizontal, 12).padding(.top, 6).padding(.bottom, 8) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isPreview { bottom.padding(.horizontal, 12).padding(.bottom, 82) }
        }
        .background(Palette.surface)
        .onAppear {
            map.initialize(store: store)
            if !isPreview { applyFocus(router.worldMapFocus) }
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
        .sheet(isPresented: $showInfo) { BountyInfoSheet() }
        .sheet(isPresented: $showNearby) { nearbyMenu }
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

    private var top: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button { router.present(.setBounty(placeID: store.worldMap.selectedPlace?.id)) } label: {
                    Label("Set Bounty", systemImage: "target").font(.system(size: 14, weight: .bold))
                        .padding(.horizontal, 16).frame(minHeight: 46)
                        .foregroundStyle(.white).background(Palette.accent, in: Capsule())
                }
                .accessibilityIdentifier("worldMap.setBounty")
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle").font(.title3).frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                }
                .accessibilityLabel("What are bounties?")
                Spacer()
                Button { showBounties = true } label: {
                    Image(systemName: "gift").font(.title3).frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                }
                .accessibilityLabel("View available bounties")
            }
            LocationSearchField(search: store.worldMap.search) { place in
                store.worldMap.clearNearby()
                pick(place)
            }
        }
    }

    private var bottom: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = store.worldMap.nearbyTitle {
                HStack {
                    Text(title).font(.caption.weight(.semibold))
                    Spacer()
                    Button("Clear") { nearbyTask?.cancel(); store.worldMap.clearNearby() }
                }
                .padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
            HStack(alignment: .bottom) {
                Button { showNearby = true } label: {
                    Label(finding ? "Searching…" : "Find Nearby", systemImage: "binoculars.fill")
                        .font(.system(size: 14, weight: .bold)).padding(.horizontal, 16).frame(minHeight: 48)
                        .background(.regularMaterial, in: Capsule())
                }
                .accessibilityIdentifier("worldMap.findNearby")
                Spacer()
                VStack(spacing: 8) {
                    Button {
                        let center = store.worldMap.region?.center ?? store.home.center.location
                        let current = store.worldMap.position.camera
                        withAnimation {
                            store.worldMap.position = .camera(MapCamera(centerCoordinate: center,
                                distance: current?.distance ?? 1500, heading: current?.heading ?? 0,
                                pitch: (current?.pitch ?? 0) > 10 ? 0 : 60))
                        }
                    } label: { Text("3D").font(.system(size: 14, weight: .bold)).frame(width: 48, height: 48).background(.regularMaterial, in: Circle()) }
                    .accessibilityLabel("Toggle 3D map")
                    Button { Task { await recenter() } } label: {
                        Group {
                            if locating { ProgressView() } else { Image(systemName: "location.fill").font(.title3) }
                        }
                        .frame(width: 48, height: 48).background(.regularMaterial, in: Circle())
                    }
                    .disabled(locating)
                    .accessibilityLabel("Current Location")
                    .accessibilityIdentifier("worldMap.currentLocation")
                }
            }
        }
        .foregroundStyle(Palette.ink)
    }

    private var nearbyMenu: some View {
        NavigationStack {
            List {
                ForEach(NearbyCategory.allCases) { category in
                    if category != .accessible || hasAccessibleData {
                        Button {
                            showNearby = false
                            nearbyTask?.cancel()
                            nearbyTask = Task { await find(category) }
                        } label: { Label(category.title, systemImage: category.icon) }
                    }
                }
                Text("Searches around the map's visible center. Amenity details depend on available source data; confirm access on arrival.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .navigationTitle("Find Nearby").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showNearby = false } } }
        }
        .presentationDetents([.medium, .large])
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
        store.worldMap.fly(to: coord)
    }

    private func find(_ category: NearbyCategory) async {
        let requestID = UUID()
        nearbyRequestID = requestID
        finding = true
        defer { if nearbyRequestID == requestID { finding = false } }
        let center = store.worldMap.region.map { Coord($0.center) } ?? store.home.center
        store.worldMap.clearNearby()
        let known = store.amenityPoints.filter { $0.verified && $0.kind == category.rawValue && $0.coord.distance(to: center) < 5000 }
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
        let coords = store.worldMap.results.map(\.coords) + known.map(\.coord)
        store.worldMap.nearbyTitle = coords.isEmpty ? "No nearby results for \(category.title)" : "\(category.title) · \(coords.count) results"
        store.worldMap.results.sort { $0.coords.distance(to: center) < $1.coords.distance(to: center) }
        store.worldMap.fit(coords)
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
