//
//  PlaceTabs.swift
//  Odyssey
//
//  The three sections of a place page and the segmented bar that switches
//  between them: Overview (what the place is), Deals (Whop deals, bounties
//  and quests) and Activity (the people and history behind it). The bar
//  sits under the header and pins below the title bar once you scroll.
//

import Foundation
import SwiftUI

enum PlaceTab: Int, CaseIterable, Identifiable {
    case overview, deals, activity

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .deals: return "Deals"
        case .activity: return "Activity"
        }
    }
}

/// Grey track with a white pill that slides to the chosen tab, like `Segmented`,
/// plus a small count on tabs that have something waiting.
struct PlaceTabBar: View {
    var selection: PlaceTab
    var counts: [PlaceTab: Int] = [:]
    var onSelect: (PlaceTab) -> Void
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PlaceTab.allCases) { tab in
                let on = selection == tab
                Button {
                    guard !on else { return }
                    Haptics.tap()
                    onSelect(tab)
                } label: {
                    HStack(spacing: 6) {
                        Text(tab.title)
                            .font(.system(size: 14, weight: .semibold))
                            .tracking(-0.15)
                        if let count = counts[tab], count > 0 {
                            Text("\(count)")
                                .font(.system(size: 11, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(on ? .white : Palette.ink2)
                                .padding(.horizontal, 6)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(on ? Palette.ink : Palette.lineStrong, in: Capsule())
                        }
                    }
                    .foregroundStyle(on ? Palette.ink : Palette.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background {
                        if on {
                            Capsule()
                                .fill(Palette.surface)
                                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(3)
        .background(Palette.surface2, in: Capsule())
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: selection)
    }
}
