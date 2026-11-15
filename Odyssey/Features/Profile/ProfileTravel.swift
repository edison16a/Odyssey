//
//  ProfileTravel.swift
//  Odyssey
//
//  Travel numbers for the showcase (countries, cities, how much of your
//  city you have walked) and the dotted trail behind the miles card.
//  The numbers come from AppStore+Travel, which ports travel.js.
//

import Foundation
import SwiftUI

/// Travel numbers for the showcase, from the store's travel service.
enum ProfileTravel {
    static func countries(_ store: AppStore) -> [String] { store.travelCountries }
    static func cities(_ store: AppStore) -> Int { store.trails.count }
    static func cityShare(_ store: AppStore) -> Int { store.cityShare() }

    /// 12.0 as "12", 3.4 as "3.4", the way the mockup prints "Top x%".
    static func pct(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }
}

/// The soft dotted trail drawn behind the miles card.
struct ProfileTrail: View {
    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 200, y: size.height / 80)
            let trail = SVGPath.path("M4 66c22-4 30-28 52-30s26 22 48 18 22-36 46-40 30 14 46 10")
            context.stroke(trail, with: .color(Palette.accent), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [2, 7]))
            context.fill(ProfileFrameKit.circle(4, 4, 66), with: .color(.white))
            context.fill(ProfileFrameKit.circle(5, 196, 24), with: .color(.white))
        }
        .opacity(0.9)
    }
}
