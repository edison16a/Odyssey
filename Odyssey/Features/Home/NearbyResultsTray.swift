import SwiftUI

/// One Find nearby result: a place from Apple's search, or an Odyssey verified amenity.
struct NearbyHit: Identifiable, Equatable {
    enum Source: Equatable { case place(Place), amenity(AmenityPoint) }
    var id: String
    var name: String
    var subtitle: String
    var coord: Coord
    var rating: Double?
    var reviews: Int?
    var photo: String
    var icon: String
    var verified: Bool
    var source: Source

    init(place: Place, icon: String) {
        id = "p-" + place.id
        name = place.name
        subtitle = place.address ?? ""
        coord = place.coords
        rating = place.rating
        reviews = place.reviews
        photo = place.photo
        self.icon = icon
        verified = false
        source = .place(place)
    }

    init(amenity: AmenityPoint) {
        id = "a-" + amenity.id
        name = amenity.name
        subtitle = amenity.access == "customers" ? "Customers only" : (amenity.note.isEmpty ? "Public" : amenity.note)
        coord = amenity.coord
        rating = nil
        reviews = nil
        photo = ""
        icon = amenity.icon
        verified = amenity.verified
        source = .amenity(amenity)
    }

    /// A place to hand to Apple Maps for walking directions.
    var destination: Place {
        if case .place(let place) = source { return place }
        return Place(id: id, name: name, coords: coord, photo: "")
    }
}

enum NearbySort: String, CaseIterable, Identifiable {
    case distance = "Distance", rating = "Rating"
    var id: String { rawValue }
    var icon: String { self == .distance ? "location.north.line.fill" : "star.fill" }
}

/// The results list under the map after a Find nearby search, like a maps app: a header
/// with the count and sort, then cards you swipe through. Tapping a card opens it in the
/// app; the walk button opens directions.
struct NearbyResultsTray: View {
    @Environment(AppStore.self) private var store
    var title: String
    var icon: String
    var results: [NearbyHit]
    @Binding var sort: NearbySort
    @Binding var focused: String?
    var onOpen: (NearbyHit) -> Void
    var onGo: (NearbyHit) -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header.padding(.horizontal, 16)
            if results.isEmpty {
                Text("Nothing found close by. Move the map and try again.")
                    .font(.system(size: 14)).foregroundStyle(Palette.muted)
                    .padding(.horizontal, 16).padding(.bottom, 6)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                            card(result, rank: index + 1).id(result.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $focused, anchor: .leading)
                .frame(height: 132)
            }
        }
        .padding(.top, 14).padding(.bottom, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.4), lineWidth: 1))
        .shadow(color: .black.opacity(0.16), radius: 18, y: 6)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Palette.accent)
                .frame(width: 34, height: 34)
                .background(Palette.accentSoft, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink).lineLimit(1)
                Text(results.count == 1 ? "1 result" : "\(results.count) results")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 6)
            Menu {
                Picker("Sort by", selection: $sort) {
                    ForEach(NearbySort.allCases) { option in
                        Label(option.rawValue, systemImage: option.icon).tag(option)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down").font(.system(size: 11, weight: .bold))
                    Text(sort.rawValue).font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12).frame(height: 32)
                .background(Palette.surface2, in: Capsule())
            }
            .accessibilityLabel("Sort by \(sort.rawValue)")
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 32, height: 32)
                    .background(Palette.surface2, in: Circle())
            }
            .accessibilityLabel("Close results")
        }
    }

    private func card(_ result: NearbyHit, rank: Int) -> some View {
        let metres = result.coord.distance(to: store.here)
        let on = focused == result.id
        return VStack(alignment: .leading, spacing: 10) {
            Button { onOpen(result) } label: {
                HStack(alignment: .top, spacing: 12) {
                    thumb(result)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(result.name)
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            if let rating = result.rating {
                                Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(Palette.gold)
                                Text(String(format: "%.1f", rating)).font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.ink)
                                if let reviews = result.reviews { Text("(\(reviews))").font(.system(size: 12)).foregroundStyle(Palette.muted) }
                            } else if result.verified {
                                Image(systemName: "checkmark.seal.fill").font(.system(size: 10)).foregroundStyle(Palette.success)
                                Text("Verified").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.success)
                            } else {
                                Text("No rating yet").font(.system(size: 12)).foregroundStyle(Palette.faint)
                            }
                        }
                        Text("\(Format.distance(metres)) · \(Format.walkTime(metres))")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.muted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            HStack(spacing: 8) {
                Button { onGo(result) } label: {
                    Label("Directions", systemImage: "figure.walk")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 34)
                        .background(Palette.accent, in: Capsule())
                }
                Button { onOpen(result) } label: {
                    Text("Details")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity).frame(height: 34)
                        .background(Palette.surface2, in: Capsule())
                }
            }
            .buttonStyle(PressStyle(scale: 0.96))
        }
        .padding(12)
        .frame(width: 282, height: 132)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(on ? Palette.accent : Palette.line, lineWidth: on ? 2 : 1))
        .overlay(alignment: .topLeading) {
            Text("\(rank)")
                .font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(rank == 1 && sort == .distance ? Palette.success : Palette.ink, in: Circle())
                .offset(x: 6, y: 6)
        }
    }

    @ViewBuilder private func thumb(_ result: NearbyHit) -> some View {
        Group {
            if !result.photo.isEmpty {
                PhotoView(path: result.photo)
            } else {
                Image(systemName: result.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.accentSoft)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
