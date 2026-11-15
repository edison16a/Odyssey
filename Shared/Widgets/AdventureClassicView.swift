//
//  AdventureClassicView.swift
//  Shared by the app and the widgets.
//
//  Today's Adventure in the photo, light and dark styles: the place's
//  photo first, then its name, the distance and the coins waiting there.
//  The map style lives in AdventureWidgetView.
//

import Foundation
import SwiftUI

struct AdventureClassicView: View {
    var size: WidgetSize
    var pick: AdventurePick
    var snapshot: WidgetSnapshot
    var prefs: WidgetPrefs

    private var style: WidgetStyle { prefs.style(for: .adventure) }
    private var colors: WidgetColors { WidgetLook.colors(.adventure, style, snapshot) }

    var body: some View {
        switch size {
        case .medium: medium(pick)
        case .large: large(pick)
        default: small(pick)
        }
    }

    private func facts(_ pick: AdventurePick) -> String {
        pick.distanceText + (pick.isFirst ? ", be the first" : ", \(pick.walkMinutes) min walk")
    }

    @ViewBuilder private func small(_ pick: AdventurePick) -> some View {
        if style == .photo {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    WidgetLabel(text: "Today", symbol: "location.north.fill", color: .white)
                    Spacer(minLength: 0)
                    if pick.isFirst { Image(systemName: "star.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.gold) }
                }
                Spacer(minLength: 0)
                Text(pick.name).font(.system(size: 16, weight: .heavy)).tracking(-0.3).lineLimit(2).foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text(pick.distanceText).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                    WidgetCoins(amount: pick.coins, color: .white, background: colors.chip)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                WidgetPhoto(file: pick.imageFile)
                    .frame(height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(pick.name).font(.system(size: 14, weight: .heavy)).lineLimit(2).foregroundStyle(colors.text)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Text(pick.distanceText).font(.system(size: 11, weight: .semibold)).foregroundStyle(colors.secondary)
                    Spacer(minLength: 0)
                    WidgetCoins(amount: pick.coins, color: colors.text, background: colors.chip)
                }
            }
        }
    }

    @ViewBuilder private func medium(_ pick: AdventurePick) -> some View {
        if style == .photo {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    WidgetLabel(text: "Today's adventure", symbol: "location.north.fill", color: .white.opacity(0.9))
                    Spacer()
                    WidgetCoins(amount: pick.coins, color: .white, background: colors.chip)
                }
                Spacer(minLength: 0)
                Text(pick.name).font(.system(size: 21, weight: .heavy)).tracking(-0.4).lineLimit(1).foregroundStyle(.white)
                Text(prefs.showReason ? pick.reason : facts(pick))
                    .font(.system(size: 12, weight: .medium)).lineLimit(1).foregroundStyle(.white.opacity(0.85))
            }
        } else {
            HStack(spacing: 12) {
                WidgetPhoto(file: pick.imageFile)
                    .frame(width: 118)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    WidgetLabel(text: "Today's adventure", symbol: "location.north.fill", color: colors.accent)
                    Text(pick.name).font(.system(size: 17, weight: .heavy)).tracking(-0.3).lineLimit(2).foregroundStyle(colors.text)
                    if prefs.showReason {
                        Text(pick.reason).font(.system(size: 11.5)).lineLimit(2).foregroundStyle(colors.secondary)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        WidgetCoins(amount: pick.coins, color: colors.text, background: colors.chip)
                        Text(facts(pick)).font(.system(size: 11, weight: .semibold)).lineLimit(1).foregroundStyle(colors.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func large(_ pick: AdventurePick) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                WidgetPhoto(file: pick.imageFile)
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 2) {
                    WidgetLabel(text: "Today's adventure", symbol: "location.north.fill", color: .white.opacity(0.9))
                    Text(pick.name).font(.system(size: 22, weight: .heavy)).tracking(-0.4).lineLimit(1).foregroundStyle(.white)
                }
                .padding(12)
                if pick.isFirst {
                    Text("Be first").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 8).frame(height: 22).background(Palette.rare, in: Capsule())
                        .padding(10).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            HStack(spacing: 8) {
                WidgetCoins(amount: pick.coins, color: colors.text, background: colors.chip)
                Text(prefs.showReason ? pick.reason : facts(pick))
                    .font(.system(size: 12, weight: .medium)).lineLimit(1).foregroundStyle(colors.secondary)
            }
            ForEach(snapshot.picks.prefix(2)) { backup in
                HStack(spacing: 10) {
                    WidgetPhoto(file: backup.imageFile).frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(backup.name).font(.system(size: 13, weight: .bold)).lineLimit(1).foregroundStyle(colors.text)
                        Text(backup.kind + ", " + backup.distanceText).font(.system(size: 11)).foregroundStyle(colors.secondary)
                    }
                    Spacer(minLength: 0)
                    Text("+\(backup.coins)").font(.system(size: 12, weight: .bold)).monospacedDigit().foregroundStyle(colors.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
