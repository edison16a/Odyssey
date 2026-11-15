import SwiftUI

/// Show recorded tags, never infer amenities or accessibility from a venue category.
struct PlaceAmenityDetails: View {
    @Environment(AppStore.self) private var store
    var place: Place
    var body: some View {
        let amenities = ExploreAmenity.of(place, store: store)
        if !amenities.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(store.state.demoMode ? "Amenities · Demo Data" : "Reported Amenities").font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(amenities) { amenity in Label(amenity.label, systemImage: amenity.icon).font(.caption) }
                    }
                }
                Text("Source data may be incomplete. Confirm access with the venue.").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
