import MapKit
import Observation
import SwiftUI

/// Shared by World Map and bounty creation. No GPS requirement or local region restriction.
@Observable
final class LocationSearch: NSObject, MKLocalSearchCompleterDelegate {
    var query = "" {
        didSet {
            generation += 1
            activeSearch?.cancel()
            searching = false
            results = []
            error = nil
            completer.queryFragment = query
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { suggestions = [] }
        }
    }
    var suggestions: [MKLocalSearchCompletion] = []
    var results: [Place] = []
    var searching = false
    var error: String?
    @ObservationIgnored private let completer = MKLocalSearchCompleter()
    @ObservationIgnored private var activeSearch: MKLocalSearch?
    @ObservationIgnored private var generation = 0

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        // MapKit's default completer region spans the world. Keep remote results available.
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.suggestions = self.query.isEmpty ? [] : Array(completer.results.prefix(6))
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in self.error = message }
    }

    func search(_ completion: MKLocalSearchCompletion? = nil, store: AppStore) async -> Place? {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard completion != nil || !text.isEmpty else { return nil }
        generation += 1
        let token = generation
        activeSearch?.cancel()
        let request = completion.map { MKLocalSearch.Request(completion: $0) } ?? MKLocalSearch.Request()
        if completion == nil { request.naturalLanguageQuery = text }
        request.resultTypes = [.address, .pointOfInterest]
        let search = MKLocalSearch(request: request)
        activeSearch = search
        searching = true
        error = nil
        defer { if token == generation { searching = false } }
        do {
            let response = try await search.start()
            guard token == generation, !Task.isCancelled else { return nil }
            results = response.mapItems.map { Self.register($0, store: store) }
            suggestions = []
            if results.isEmpty { error = "No places found. Try a fuller address or add a city." }
            return results.first
        } catch {
            if token == generation, !Task.isCancelled { self.error = "Search unavailable. Please try again." }
            return nil
        }
    }

    /// Keep Apple's identity where possible and reuse existing Odyssey records for known places.
    static func register(_ item: MKMapItem, store: AppStore) -> Place {
        let mark = item.placemark
        let coord = Coord(mark.coordinate)
        let name = item.name ?? mark.title ?? "Selected location"
        let known = store.seed.places + Array(store.osmPlaces.values)
        if let existing = known.first(where: {
            $0.coords.distance(to: coord) < 60 && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) { return existing }
        let key = item.identifier?.rawValue ?? "\(name)|\(coord.lat)|\(coord.lng)"
        let id = "apple-" + String(StableHash.fnv(key))
        var tags = ["source": "apple"]
        tags["addr:street"] = mark.thoroughfare
        tags["addr:city"] = mark.locality
        let place = Place(id: id, name: name, category: item.pointOfInterestCategory?.discoverID,
                          coords: coord, photo: "", address: mark.title, tags: tags,
                          website: item.url?.absoluteString, source: "apple")
        store.osmPlaces[id] = place
        return place
    }
}

struct LocationSearchField: View {
    @Environment(AppStore.self) private var store
    @Bindable var search: LocationSearch
    var onSelect: (Place) -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.accent)
                TextField("Search places, addresses, or cities...", text: $search.query)
                    .font(.system(size: 14))
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($focused)
                    .onSubmit { run() }
                    .accessibilityIdentifier("worldMap.search")
                if search.searching {
                    ProgressView()
                } else if !search.query.isEmpty {
                    Button { search.query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            if focused || !search.results.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(search.suggestions.enumerated()), id: \.offset) { _, suggestion in
                            Button { run(suggestion) } label: {
                                resultRow(suggestion.title, suggestion.subtitle)
                            }
                            .buttonStyle(.plain)
                        }
                        ForEach(search.results.prefix(5)) { place in
                            Button { choose(place) } label: { resultRow(place.name, place.address ?? "") }
                                .buttonStyle(.plain)
                        }
                        if focused && !search.query.isEmpty && !search.searching {
                            Button("Search all locations") { run() }
                                .font(.system(size: 13, weight: .semibold)).padding(12)
                        }
                    }
                }
                .frame(maxHeight: search.suggestions.isEmpty && search.results.isEmpty ? 44 : 240)
                .scrollDismissesKeyboard(.interactively)
            }
            if let error = search.error {
                Text(error).font(.caption).foregroundStyle(Palette.danger).padding(10)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.line))
    }

    private func resultRow(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
            if !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundStyle(Palette.muted) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func run(_ completion: MKLocalSearchCompletion? = nil) {
        focused = false
        Task {
            if let place = await search.search(completion, store: store), completion != nil { choose(place) }
        }
    }

    private func choose(_ place: Place) {
        focused = false
        search.query = ""
        onSelect(place)
    }
}
