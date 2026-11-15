//
//  PlaceStarButton.swift
//  Odyssey
//
//  The star in the place page's top bar. A starred place stays on your home
//  map with a gold pin until you take the star off, and checking in there
//  counts as going somewhere Odyssey picked for you.
//

import Foundation
import SwiftUI

struct PlaceStarButton: View {
    @Environment(AppStore.self) private var store
    @Environment(ToastCenter.self) private var toast
    var place: Place
    /// White on the photo, dark once the bar turns white.
    var light: Bool

    var body: some View {
        let on = store.isStarred(place)
        Button {
            let starred = store.toggleStar(place)
            Haptics.tap()
            toast.show(starred ? "Starred. It is on your map now" : "Star removed", icon: starred ? "star.fill" : "star")
        } label: {
            Image(systemName: on ? "star.fill" : "star")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(on ? Palette.gold : (light ? .white : Palette.ink))
                .frame(width: 40, height: 40)
                .background {
                    if light {
                        Circle().fill(.black.opacity(0.45)).background(.ultraThinMaterial, in: Circle())
                    }
                }
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(PressStyle(scale: 0.88))
        .accessibilityLabel(on ? "Unstar" : "Star")
    }
}
