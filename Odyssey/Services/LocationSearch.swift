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

    private static let rowHeight: CGFloat = 58

    /// What the list shows, worked out once so its height never jumps while it fills.
    private enum Row: Identifiable {
        case suggestion(Int, MKLocalSearchCompletion)
        case place(Place)
        case status(String, error: Bool)
        case searchAll

        var id: String {
            switch self {
            case .suggestion(let i, _): "s\(i)"
            case .place(let p): "p" + p.id
            case .status(let text, _): "t" + text
            case .searchAll: "all"
            }
        }
    }

    private var rows: [Row] {
        var out: [Row] = []
        let results = Array(search.results.prefix(5))
        if !results.isEmpty {
            out = results.map { .place($0) }
        } else {
            out = search.suggestions.enumerated().map { .suggestion($0.offset, $0.element) }
        }
        if search.searching && results.isEmpty { out.insert(.status("Searching…", error: false), at: 0) }
        if let error = search.error, !search.searching { out.append(.status(error, error: true)) }
        if !search.query.isEmpty && !search.searching && results.isEmpty && search.error == nil { out.append(.searchAll) }
        return out
    }

    var body: some View {
        let list = rows
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(focused ? Palette.accent : Palette.muted)
                TextField("Search places, addresses, cities", text: $search.query)
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.ink)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($focused)
                    .onSubmit { run() }
                    .accessibilityIdentifier("worldMap.search")
                if !search.query.isEmpty || !search.results.isEmpty {
                    Button {
                        search.query = ""
                        focused = false
                    } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundStyle(Palette.faint)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(focused ? Palette.accent.opacity(0.5) : .white.opacity(0.5), lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            if !list.isEmpty && (focused || !search.results.isEmpty || search.error != nil) {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(list) { row in
                            if row.id != list.first?.id { Divider().padding(.leading, 56) }
                            view(for: row)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
                .frame(height: min(CGFloat(list.count) * Self.rowHeight, Self.rowHeight * 5))
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.14), radius: 16, y: 6)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        .animation(.snappy(duration: 0.2), value: list.count)
        .animation(.snappy(duration: 0.2), value: focused)
    }

    @ViewBuilder private func view(for row: Row) -> some View {
        switch row {
        case .suggestion(_, let suggestion):
            Button { run(suggestion) } label: { resultRow("mappin.circle.fill", suggestion.title, suggestion.subtitle) }
                .buttonStyle(.plain)
        case .place(let place):
            Button { choose(place) } label: {
                resultRow("mappin.circle.fill", place.name, place.address ?? "",
                          trailing: Format.distance(store.metres(to: place)))
            }
            .buttonStyle(.plain)
        case .status(let text, let error):
            HStack(spacing: 12) {
                Group {
                    if error { Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Palette.danger) }
                    else { ProgressView().controlSize(.small) }
                }
                .frame(width: 32)
                Text(text).font(.system(size: 14, weight: .medium)).foregroundStyle(error ? Palette.danger : Palette.muted)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: Self.rowHeight)
        case .searchAll:
            Button { run() } label: {
                resultRow("magnifyingglass.circle.fill", "Search for \u{201C}\(search.query)\u{201D}", "", accent: true)
            }
            .buttonStyle(.plain)
        }
    }

    private func resultRow(_ icon: String, _ title: String, _ subtitle: String,
                           trailing: String? = nil, accent: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundStyle(accent ? Palette.accent : Palette.danger.opacity(0.85))
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(accent ? Palette.accent : Palette.ink).lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(Palette.muted).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if let trailing { Text(trailing).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.muted) }
        }
        .padding(.horizontal, 12)
        .frame(height: Self.rowHeight)
        .contentShape(Rectangle())
    }

    /// Keep the list open while it searches, so it doesn't close and reopen.
    private func run(_ completion: MKLocalSearchCompletion? = nil) {
        Task {
            let place = await search.search(completion, store: store)
            if let place, completion != nil || search.results.count == 1 { choose(place) }
        }
    }

    private func choose(_ place: Place) {
        focused = false
        search.query = ""
        onSelect(place)
    }
}
