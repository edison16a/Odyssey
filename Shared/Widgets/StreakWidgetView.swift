//
//  StreakWidgetView.swift
//  Shared by the app and the widgets.
//
//  Globie on your home screen. Asleep until you check in, happy once today
//  counts, over the moon on a milestone, and wearing whatever form your
//  streak has earned. Medium adds the week and how far the next form is.
//  The Lock Screen versions show the count with a ring to the next form.
//

import Foundation
import SwiftUI

struct StreakWidgetView: View {
    var size: WidgetSize
    var snapshot: WidgetSnapshot
    var prefs: WidgetPrefs

    private var colors: WidgetColors { WidgetLook.colors(.streak, prefs.style(for: .streak), snapshot) }
    private var status: String {
        if snapshot.streakDays == 0 { return "Check in anywhere to start a streak" }
        return snapshot.claimedToday ? "Today counted. Globie is happy." : "Check in anywhere today to keep it going"
    }
    private var nextLine: String {
        guard let next = snapshot.nextTier else { return "Every form unlocked" }
        let left = next.days - snapshot.streakDays
        return "\(left) \(left == 1 ? "day" : "days") to \(next.name)"
    }
    private var nextProgress: Double {
        guard let next = snapshot.nextTier else { return 1 }
        let base = snapshot.tier.days
        return Double(snapshot.streakDays - base) / Double(max(1, next.days - base))
    }

    var body: some View {
        switch size {
        case .small: small
        case .medium: medium
        case .large: medium
        case .circular: circular
        case .rectangular: rectangular
        case .inline: inline
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                GlobieView(mood: snapshot.mood, form: snapshot.tier.id, size: 58, animated: false)
                Spacer(minLength: 0)
                Image(systemName: "flame.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(snapshot.claimedToday ? Palette.flame : colors.secondary)
            }
            Spacer(minLength: 2)
            Text("\(snapshot.streakDays)")
                .font(.system(size: 38, weight: .heavy))
                .tracking(-1.2)
                .monospacedDigit()
                .foregroundStyle(colors.text)
                .contentTransition(.numericText())
            Text(snapshot.claimedToday || snapshot.streakDays == 0 ? "day streak" : "check in today")
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(snapshot.claimedToday ? colors.secondary : Palette.flame)
            if prefs.showWeek {
                WidgetWeek(snapshot: snapshot, colors: colors, dot: 11, letters: false).padding(.top, 6)
            }
        }
    }

    private var medium: some View {
        HStack(spacing: 14) {
            GlobieView(mood: snapshot.mood, form: snapshot.tier.id, size: 104, animated: false)
                .frame(width: 112)
            VStack(alignment: .leading, spacing: 4) {
                WidgetLabel(text: snapshot.tier.name, symbol: "flame.fill", color: colors.accent)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(snapshot.streakDays)").font(.system(size: 34, weight: .heavy)).tracking(-1).monospacedDigit()
                    Text("day streak").font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(colors.text)
                Text(status).font(.system(size: 11.5, weight: .medium)).foregroundStyle(colors.secondary).lineLimit(2)
                Spacer(minLength: 2)
                if prefs.showWeek {
                    WidgetWeek(snapshot: snapshot, colors: colors, dot: 17)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(nextLine).font(.system(size: 11, weight: .semibold)).foregroundStyle(colors.secondary)
                        WidgetBar(value: nextProgress, color: colors.accent, track: colors.chip)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var circular: some View {
        Gauge(value: min(1, max(0, nextProgress))) {
            Image(systemName: "flame.fill")
        } currentValueLabel: {
            VStack(spacing: -1) {
                Image(systemName: "flame.fill").font(.system(size: 10, weight: .bold))
                Text("\(snapshot.streakDays)").font(.system(size: 17, weight: .heavy)).monospacedDigit()
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill").font(.system(size: 12, weight: .bold))
                Text("\(snapshot.streakDays) day streak").font(.system(size: 15, weight: .bold))
            }
            Text(snapshot.claimedToday ? nextLine : "Check in to keep it")
                .font(.system(size: 12, weight: .medium)).lineLimit(1).opacity(0.8)
            HStack(spacing: 3) {
                ForEach(Array(snapshot.week().enumerated()), id: \.offset) { _, day in
                    Capsule().fill(.primary.opacity(day.done ? 1 : 0.25)).frame(height: 4)
                }
            }
            .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Label(snapshot.claimedToday ? "\(snapshot.streakDays) day streak" : "\(snapshot.streakDays) days, check in today",
              systemImage: "flame.fill")
    }
}

/// A thin progress bar that also works inside widgets.
struct WidgetBar: View {
    var value: Double
    var color: Color
    var track: Color
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(color).frame(width: max(height, geo.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: height)
    }
}
