//
//  TravelMapPanel.swift
//  Odyssey
//
//  The panel over the explored map: your flags, the totals, how much of
//  your city is uncovered, and the walk and Paris trip buttons. Ported
//  from panel() in features/travel/explored-map.js and travel.css.
//

import Foundation
import SwiftUI

/// The white panel along the bottom: flags, totals, your city and actions.
struct TravelMapPanel: View {
    var walking: Bool
    var walk: () -> Void
    var trip: () -> Void
    @Environment(AppStore.self) private var store

    var body: some View {
        // Walks every trail and the city grid, so it is worked out once per change of state.
        let stats = store.memo("travelStats") { store.travelStats() }
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(store.travelCountries, id: \.self) { code in
                    TravelFlag(code: store.seed.countries[code]?.flag ?? "us", width: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(.black.opacity(0.08), lineWidth: 1))
                }
            }
            HStack(alignment: .top, spacing: 0) {
                stat("\(stats.countries)", "Countries")
                stat("\(stats.states)", "States")
                stat("\(stats.cities)", "Cities")
                stat(String(format: "%.1f km²", stats.area), "Uncovered")
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(store.home.city).font(.system(size: 13, weight: .bold))
                    Spacer()
                    Text("\(stats.city)% explored").font(.system(size: 13)).monospacedDigit().foregroundStyle(Palette.muted)
                }
                ProgressBar(value: Double(stats.city) / 100)
            }
            HStack(spacing: 8) {
                Button(action: walk) { Label("Take a walk", systemImage: "figure.walk") }
                    .buttonStyle(.pill(.primary, height: 36, fill: true))
                    .disabled(walking)
                Button(action: trip) { Label("Fly to Paris", systemImage: "airplane") }
                    .buttonStyle(.pill(.soft, height: 36, fill: true))
            }
            Text("Fills in by itself as you move. Check in to earn rewards for a place.")
                .font(.system(size: 10.5))
                .foregroundStyle(Palette.faint)
                .frame(maxWidth: .infinity)
        }
        .padding(14)
        .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 25, y: 18)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.system(size: 20, weight: .bold)).tracking(-0.4).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 11)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
