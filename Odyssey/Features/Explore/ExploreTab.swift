//
//  ExploreTab.swift
//  Odyssey
//
//  Explore: a full screen, swipe-up feed of real places around you, ranked
//  by what you love. Swipe up to pass, double tap or tap the heart to save,
//  and your explorer type in the corner reacts to every save. The grid
//  button switches to list mode: Places you'll love and Hidden gems, all at
//  once, to scroll and like. Chips along the
//  top filter for the practical things (wifi, a bathroom, outlets...), and
//  search and categories sit behind the magnifying glass. Every save teaches
//  the same taste model the rest of the app uses.
//

import Foundation
import SwiftUI

struct ExploreTab: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toast

    @State private var feed = ExploreFeed()
    @State private var currentID: String?
    @State private var amenities: Set<ExploreAmenity> = []
    @State private var showLocation = false
    @State private var showSearch = false
    @State private var feeding = false
    /// Bumped on every fresh save so the gem gives a small pop.
    @State private var gemPops = 0
    /// Where the top bar ends, so the card's photo bars sit under it.
    @State private var chromeBottom: CGFloat = 0
    /// "feed" is one place a screen; "list" is everything at once in a grid.
    @AppStorage("exploreLayout") private var layout = "feed"
    @AppStorage("exploreListTab") private var listTab: ExploreListTab = .loved

    private static let tipKey = "explore-feed"
    /// The tab bar's height above the bottom safe area.
    private static let tabBarHeight: CGFloat = 62

    var body: some View {
        GeometryReader { outer in
            let topInset = outer.safeAreaInsets.top
            VStack(spacing: 0) {
                GeometryReader { geo in
                    ZStack(alignment: .top) {
                        content(size: geo.size)
                        LinearGradient(colors: [.black.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: topInset + 100)
                            .allowsHitTesting(false)
                        topBar.padding(.top, topInset + Space.s2)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { chromeBottom = $0 }
                    }
                }
                .ignoresSafeArea(edges: .top)
                Color.clear.frame(height: Self.tabBarHeight)
            }
        }
        .background(Palette.ink.ignoresSafeArea())
        .overlay {
            if !store.state.tipsSeen.contains(Self.tipKey) {
                ExploreCoachMarks {
                    withAnimation(.easeOut(duration: 0.25)) {
                        store.update { $0.tipsSeen.append(Self.tipKey) }
                    }
                }
                .transition(.opacity)
            }
        }
        .task(id: locationKey) {
            currentID = nil
            await feed.start(store: store, key: locationKey)
            syncCategory()
        }
        .onChange(of: store.state.discoverCategory) { syncCategory() }
        .onChange(of: currentID) { keepFed() }
        .onChange(of: feed.cards.count) {
            if currentID == nil || !visible.contains(where: { $0.id == currentID }) { currentID = visible.first?.id }
            keepFed()
        }
        .onChange(of: amenities) {
            if !visible.contains(where: { $0.id == currentID }) { currentID = visible.first?.id }
            keepFed()
        }
        .sheet(isPresented: $showLocation) {
            ExploreLocationSheet()
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSearch) {
            ExploreSearchSheet(filter: feed.filter) { next in
                showSearch = false
                pick(next)
            }
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(28)
            .presentationDragIndicator(.visible)
        }
    }

    /// Changes whenever the Explore location does, so the feed reloads.
    private var locationKey: String {
        let loc = store.exploreLocation
        return "\(loc.id)\(loc.center.lat),\(loc.center.lng)"
    }

    /// The cards that pass the amenity filters.
    private var visible: [Place] {
        guard !amenities.isEmpty else { return feed.cards }
        return feed.cards.filter { ExploreAmenity.place($0, has: amenities, store: store) }
    }

    // MARK: Feed

    @ViewBuilder private func content(size: CGSize) -> some View {
        let list = visible
        if layout == "list" {
            ExploreListView(places: list, tab: $listTab, loading: feed.loading || feeding,
                            topInset: chromeBottom, onToggleLike: toggleLike, onNeedMore: loadMore)
        } else if list.isEmpty {
            if feed.loading || (!feed.exhausted && amenities.isEmpty) {
                loadingPage
            } else {
                emptyPage
            }
        } else {
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(list, id: \.id) { place in
                        ExploreFeedPage(place: place,
                                        onLike: { like(place) },
                                        onToggleLike: { toggleLike(place) },
                                        onNotForMe: { notForMe(place) },
                                        onDirections: { go(place) },
                                        onDetails: { router.push(.place(place.id)) },
                                        topInset: chromeBottom)
                            .frame(width: size.width, height: size.height)
                            .id(place.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentID)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var loadingPage: some View {
        VStack(spacing: Space.s3) {
            ProgressView().tint(.white)
            Text("Finding places around you")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.ink)
    }

    private var emptyPage: some View {
        let filtered = !amenities.isEmpty
        let names = ExploreAmenity.allCases.filter { amenities.contains($0) }.map { $0.label.lowercased() }
        return VStack(spacing: Space.s2) {
            Image(systemName: filtered ? "line.3.horizontal.decrease" : "map")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.bottom, Space.s2)
            Text(filtered ? "Nothing with all of that yet" : "That is everything around here")
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.4)
            Text(filtered
                 ? "No places nearby have \(Self.list(names)). Try fewer filters."
                 : "Try another filter, or pick another place to explore.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
            if feeding {
                HStack(spacing: Space.s2) {
                    ProgressView().tint(.white).controlSize(.small)
                    Text("Looking further out").font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.6))
                .padding(.top, Space.s1)
            }
            HStack(spacing: 10) {
                if filtered {
                    Button("Clear filters") {
                        Haptics.tap()
                        withAnimation { amenities = [] }
                    }
                    .buttonStyle(.pill(.light, height: 44))
                } else {
                    Button("Show all") { pick(.all) }.buttonStyle(.pill(.light, height: 44))
                    Button("Change place") { showLocation = true }.buttonStyle(.pill(.glass, height: 44))
                }
            }
            .padding(.top, Space.s3)
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .padding(.horizontal, Space.s8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.ink)
    }

    private static func list(_ items: [String]) -> String {
        guard items.count > 1 else { return items.first ?? "that" }
        return items.dropLast().joined(separator: ", ") + " and " + items.last!
    }

    /// Keep places coming: when you near the end of what passes the filters,
    /// let the feed deal more (loading further out if it needs to).
    private func keepFed() {
        if let id = currentID, let i = feed.cards.firstIndex(where: { $0.id == id }) { feed.index = i }
        guard !feeding, !feed.loading, !feed.exhausted else { return }
        let list = visible
        let pos = list.firstIndex { $0.id == currentID } ?? 0
        guard list.count - pos <= 3 else { return }
        feeding = true
        Task {
            for _ in 0..<6 {
                let before = feed.cards.count
                // Everything dealt so far is behind you as far as the filters go.
                feed.index = feed.cards.count
                await feed.topUp(store: store)
                if feed.cards.count == before || feed.exhausted { break }
                let now = visible
                let at = now.firstIndex { $0.id == currentID } ?? 0
                if now.count - at > 3 { break }
            }
            if let id = currentID, let i = feed.cards.firstIndex(where: { $0.id == id }) { feed.index = i }
            feeding = false
        }
    }

    /// List mode: load further out whenever the grid nears its end.
    private func loadMore() {
        guard !feeding, !feed.loading, !feed.exhausted else { return }
        feeding = true
        Task {
            let wanted = visible.count + 12
            for _ in 0..<6 {
                let before = feed.cards.count
                feed.index = feed.cards.count
                await feed.topUp(store: store)
                if feed.cards.count == before || feed.exhausted { break }
                let gems = visible.filter { store.status(of: $0).status == .new }.count
                if visible.count >= wanted && (listTab == .loved || gems >= 8) { break }
            }
            feeding = false
        }
    }

    // MARK: Actions

    private func like(_ place: Place) {
        let fresh = store.voteOf(place) != 1
        if fresh { store.vote(place, 1) }
        if !store.isStarred(place) { store.toggleStar(place) }
        guard fresh else { Haptics.soft(); return }
        Haptics.success()
        gemPops += 1
    }

    private func toggleLike(_ place: Place) {
        if store.voteOf(place) == 1 {
            store.vote(place, 1) // the same thumb again undoes it
            if store.isStarred(place) { store.toggleStar(place) }
            Haptics.tap()
        } else {
            like(place)
        }
    }

    private func notForMe(_ place: Place) {
        if store.voteOf(place) != -1 { store.vote(place, -1) }
        if store.isStarred(place) { store.toggleStar(place) }
        Haptics.tap()
        toast.show("Got it, fewer like this", icon: "hand.thumbsdown.fill")
        let list = visible
        guard let i = list.firstIndex(where: { $0.id == place.id }), i + 1 < list.count else { return }
        withAnimation(.easeInOut(duration: 0.35)) { currentID = list[i + 1].id }
    }

    private func go(_ place: Place) {
        Haptics.tap()
        LiveActivityService.shared.start(place: place, store: store)
        NearbyService.directions(to: place)
    }

    // MARK: Top bar

    /// One compact row (your gem, where you are, search) and one slim row of
    /// amenity filters under it.
    private var topBar: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            HStack(spacing: Space.s2) {
                ExploreGemHUD(gem: TasteGem.of(store), pops: gemPops) {
                    Haptics.tap()
                    router.push(.tasteProfile)
                }
                .layoutPriority(1)
                Spacer(minLength: Space.s1)
                Button { showLocation = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill").font(.system(size: 10, weight: .semibold))
                        Text(store.exploreLocation.label.split(separator: ",").first.map(String.init) ?? "Nearby")
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Space.s3)
                    .frame(height: ExploreChrome.height)
                    .frame(maxWidth: 140)
                    .background(ExploreChrome.fill, in: Capsule())
                }
                .buttonStyle(PressStyle(scale: 0.95))
                .accessibilityLabel("Explore location")
                Button {
                    Haptics.tap()
                    withAnimation(.easeInOut(duration: 0.25)) { layout = layout == "list" ? "feed" : "list" }
                } label: {
                    Image(systemName: layout == "list" ? "rectangle.portrait" : "square.grid.2x2")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: ExploreChrome.height, height: ExploreChrome.height)
                        .background(ExploreChrome.fill, in: Circle())
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(PressStyle(scale: 0.92))
                .accessibilityLabel(layout == "list" ? "Show one at a time" : "Show all as a list")
                Button { Haptics.tap(); showSearch = true } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: ExploreChrome.height, height: ExploreChrome.height)
                        .background(ExploreChrome.fill, in: Circle())
                }
                .buttonStyle(PressStyle(scale: 0.92))
                .accessibilityLabel("Search and categories")
            }
            .padding(.horizontal, Space.s4)
            chips
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if feed.filter != .all {
                    ExploreGlassChip(label: filterLabel, icon: nil, isOn: true, trailing: "xmark") {
                        pick(.all)
                    }
                }
                ForEach(ExploreAmenity.allCases) { a in
                    ExploreGlassChip(label: a.label, icon: nil, isOn: amenities.contains(a)) {
                        Haptics.tap()
                        withAnimation(.easeOut(duration: 0.2)) {
                            if amenities.contains(a) { amenities.remove(a) } else { amenities.insert(a) }
                        }
                    }
                }
            }
            .padding(.horizontal, Space.s4)
        }
    }

    private var filterLabel: String {
        switch feed.filter {
        case .category(let id): return store.seed.discoverCategory(id)?.label ?? id
        default: return feed.filter.label
        }
    }

    // MARK: Filters

    private func pick(_ next: ExploreFilter) {
        Haptics.tap()
        var saved = "all"
        if case .category(let id) = next { saved = id }
        if store.state.discoverCategory != saved { store.update { s in s.discoverCategory = saved } }
        guard next != feed.filter else { return }
        currentID = nil
        feed.apply(next, store: store)
    }

    /// A category chosen elsewhere (the demo guide) carries over to the feed.
    private func syncCategory() {
        let id = store.state.discoverCategory
        let wanted: ExploreFilter = store.seed.discoverCategory(id) == nil ? .all : .category(id)
        if case .search = feed.filter, wanted == .all { return }
        if wanted != feed.filter && (wanted != .all || feed.filter.isCategory) {
            currentID = nil
            feed.apply(wanted, store: store)
        }
    }
}

extension ExploreFilter {
    var isCategory: Bool {
        if case .category = self { return true }
        return false
    }
}
