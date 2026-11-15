//
//  Brand.swift
//  Odyssey
//
//  The Odyssey logo and wordmark. The logo is the silver rhombus with a
//  globe in the middle, kept in Media.xcassets as brand-odyssey-logo, so a
//  new version of the art only means replacing that one PNG. The wordmark
//  is set in type, which keeps it sharp at every size and easy to recolor.
//

import Foundation
import SwiftUI

/// The rhombus and globe logo.
struct OdysseyMark: View {
    var size: CGFloat = 16

    var body: some View {
        Image("brand-odyssey-logo")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("Odyssey")
    }
}

/// "Odyssey" set in heavy rounded type.
struct OdysseyWordmark: View {
    var size: CGFloat = 24
    var color: Color = .white

    var body: some View {
        Text("Odyssey")
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .tracking(-size * 0.03)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
    }
}

enum Brand {
    static let name = "Odyssey"
    static let motto = "Go Explore. Get Rewarded."
    static let tagline = "Turn everyday life into an adventure."
}
