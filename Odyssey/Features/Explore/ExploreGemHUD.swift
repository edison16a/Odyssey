//
//  ExploreGemHUD.swift
//  Odyssey
//
//  Your taste gem, pinned top left of the Explore feed: a small gem and the
//  personality it currently reads as. It gives a gentle pop on every save,
//  and a tap opens the full taste profile.
//

import Foundation
import SwiftUI

struct ExploreGemHUD: View {
    var gem: TasteGem
    /// Bumped on every save to pop the gem.
    var pops: Int
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                TasteGemView(gem: gem, size: 22, animated: false)
                    .keyframeAnimator(initialValue: 1.0, trigger: pops) { content, scale in
                        content.scaleEffect(scale)
                    } keyframes: { _ in
                        SpringKeyframe(1.25, duration: 0.14, spring: .snappy)
                        SpringKeyframe(1.0, duration: 0.35, spring: .smooth)
                    }
                Text(gem.persona)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.leading, 7)
            .padding(.trailing, 12)
            .frame(height: ExploreChrome.height)
            .background(ExploreChrome.fill, in: Capsule())
        }
        .buttonStyle(PressStyle(scale: 0.95))
        .accessibilityLabel("Your taste: \(gem.persona). Open taste profile")
    }
}

/// The one look shared by every control floating over the feed's photos:
/// a soft dark capsule, no borders, white type.
enum ExploreChrome {
    static let height: CGFloat = 34
    static let fill = Color.black.opacity(0.32)
}
