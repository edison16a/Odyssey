//
//  AdventureWidgetView.swift
//  Shared by the app and the widgets.
//
//  Today's Adventure: the one place Odyssey picked for you today, how far it
//  is and the coins waiting there. The map style draws the place on a real
//  map with its photo pinned where it is and a dot for you; large adds why
//  it was picked and two backups. The widget draws its own margins so the
//  map can reach the edges.
//

import Foundation
import SwiftUI

struct AdventureWidgetView: View {
    var size: WidgetSize
    var snapshot: WidgetSnapshot
    var prefs: WidgetPrefs

    private var style: WidgetStyle { prefs.style(for: .adventure) }
    private var colors: WidgetColors { WidgetLook.colors(.adventure, style, snapshot) }

    var body: some View {
        if let pick = snapshot.adventure {
            switch size {
            case .rectangular, .circular, .inline:
                rectangular(pick)
            default:
                if style == .map {
                    mapLayout(pick)
                } else {
                    AdventureClassicView(size: size, pick: pick, snapshot: snapshot, prefs: prefs).padding(16)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                WidgetLabel(text: "Today's adventure", symbol: "location.north.fill", color: colors.secondary)
                Spacer()
                Text("Open Odyssey to get today's pick").font(.system(size: 14, weight: .bold)).foregroundStyle(colors.text)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(size.isAccessory ? 0 : 16)
        }
    }

    @ViewBuilder private func mapLayout(_ pick: AdventurePick) -> some View {
        switch size {
        case .medium: mapMedium(pick)
        case .large: mapLarge(pick)
        default: mapSmall(pick)
        }
    }

    private func mapSmall(_ pick: AdventurePick) -> some View {
        ZStack(alignment: .bottomLeading) {
            AdventureMapPanel(pick: pick, pin: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(pick.name).font(.system(size: 14, weight: .heavy)).tracking(-0.2).lineLimit(2).foregroundStyle(Palette.ink)
                HStack(spacing: 6) {
                    Text(pick.distanceText).font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.muted)
                    Spacer(minLength: 0)
                    WidgetCoins(amount: pick.coins, color: Palette.ink, background: Palette.goldSoft)
                }
            }
            .padding(9)
            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
            .padding(8)
        }
        .overlay(alignment: .topLeading) { AdventureMapTag().padding(8) }
    }

    private func mapMedium(_ pick: AdventurePick) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                WidgetLabel(text: "Today's adventure", symbol: "location.north.fill", color: Palette.accent)
                Text(pick.name).font(.system(size: 17, weight: .heavy)).tracking(-0.3).lineLimit(2).foregroundStyle(Palette.ink)
                if prefs.showReason {
                    Text(pick.reason).font(.system(size: 11.5)).lineLimit(2).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    WidgetCoins(amount: pick.coins, color: Palette.ink, background: Palette.goldSoft)
                    if pick.isFirst {
                        AdventureFirstTag()
                    } else {
                        Text("\(pick.walkMinutes) min walk").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.muted)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            AdventureMapPanel(pick: pick, pin: 40)
                .frame(width: 150)
                .overlay(alignment: .topTrailing) {
                    Text(pick.distanceText)
                        .font(.system(size: 11, weight: .bold)).monospacedDigit().foregroundStyle(Palette.ink)
                        .padding(.horizontal, 8).frame(height: 22)
                        .background(.white, in: Capsule())
                        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                        .padding(8)
                }
        }
    }

    private func mapLarge(_ pick: AdventurePick) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            AdventureMapPanel(pick: pick, pin: 54)
                .frame(height: 196)
                .clipped()
                .overlay(alignment: .top) {
                    HStack {
                        AdventureMapTag()
                        Spacer()
                        if pick.isFirst { AdventureFirstTag() }
                    }
                    .padding(12)
                }
            VStack(alignment: .leading, spacing: 6) {
                Text(pick.name).font(.system(size: 21, weight: .heavy)).tracking(-0.4).lineLimit(1).foregroundStyle(Palette.ink)
                Text(prefs.showReason ? pick.reason : pick.kind)
                    .font(.system(size: 12)).lineLimit(2).foregroundStyle(Palette.muted)
                HStack(spacing: 8) {
                    WidgetCoins(amount: pick.coins, color: Palette.ink, background: Palette.goldSoft)
                    Text(pick.distanceText + ", \(pick.walkMinutes) min walk")
                        .font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Palette.muted)
                }
                HStack(spacing: 8) {
                    ForEach(snapshot.picks.prefix(2)) { backup in AdventureBackupChip(pick: backup) }
                }
                .padding(.top, 4)
            }
            .padding(14)
            Spacer(minLength: 0)
        }
    }

    private func rectangular(_ pick: AdventurePick) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: "location.north.fill").font(.system(size: 10, weight: .bold))
                Text("Today").font(.system(size: 12, weight: .semibold))
            }
            .opacity(0.85)
            Text(pick.name).font(.system(size: 15, weight: .bold)).lineLimit(1)
            Text(pick.distanceText + ", +\(pick.coins) coins").font(.system(size: 12, weight: .medium)).lineLimit(1).opacity(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
