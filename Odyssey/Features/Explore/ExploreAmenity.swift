//
//  ExploreAmenity.swift
//  Odyssey
//
//  The practical things you look for in a place: wifi, somewhere to sit, a
//  bathroom, outlets, quiet, step-free access and an elevator. They come
//  from the demo amenity tags loaded from Convex, and Explore filters by them.
//

import Foundation
import SwiftUI

enum ExploreAmenity: String, CaseIterable, Identifiable, Hashable {
    case wifi, seating, bathroom, outlets, quiet, accessible, elevator

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wifi: return "Wifi"
        case .seating: return "Seating"
        case .bathroom: return "Bathroom"
        case .outlets: return "Outlets"
        case .quiet: return "Quiet"
        case .accessible: return "Accessible"
        case .elevator: return "Elevator"
        }
    }

    var icon: String {
        switch self {
        case .wifi: return "wifi"
        case .seating: return "chair.lounge.fill"
        case .bathroom: return "toilet.fill"
        case .outlets: return "powerplug.fill"
        case .quiet: return "speaker.slash.fill"
        case .accessible: return "figure.roll"
        case .elevator: return "arrow.up.arrow.down.square.fill"
        }
    }

    /// The amenities a place has, in the standard order.
    @MainActor
    static func of(_ place: Place, store: AppStore) -> [ExploreAmenity] {
        let tags = store.amenities(of: place)
        return allCases.filter { tags.contains($0.rawValue) }
    }

    /// True when the place has every amenity asked for.
    @MainActor
    static func place(_ place: Place, has wanted: Set<ExploreAmenity>, store: AppStore) -> Bool {
        guard !wanted.isEmpty else { return true }
        let tags = Set(store.amenities(of: place))
        return wanted.allSatisfy { tags.contains($0.rawValue) }
    }
}

/// A slim chip over the feed's photos: dark and quiet when off, white when on.
struct ExploreGlassChip: View {
    var label: String
    var icon: String?
    var isOn = false
    var trailing: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon).font(.system(size: 10, weight: .semibold)) }
                Text(label).font(.system(size: 12, weight: .semibold))
                if let trailing { Image(systemName: trailing).font(.system(size: 9, weight: .bold)) }
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .foregroundStyle(isOn ? Palette.ink : .white)
            .background(isOn ? Color.white : ExploreChrome.fill, in: Capsule())
        }
        .buttonStyle(PressStyle(scale: 0.94))
        .animation(.easeOut(duration: 0.16), value: isOn)
    }
}
