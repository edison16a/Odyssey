//
//  OdysseyWidgets.swift
//  OdysseyWidgets
//
//  The widget definitions. They all read the snapshot the app leaves in the
//  App Group and the style chosen in the app's widget editor, then draw the
//  same views the app's gallery previews. A new entry is scheduled for
//  midnight so Globie falls asleep when a new day starts.
//

import Foundation
import OSLog
import SwiftUI
import WidgetKit

/// Shows in the Console app under the subsystem com.edisonlaw.Odyssey.widgets.
private let log = Logger(subsystem: "com.edisonlaw.Odyssey.widgets", category: "timeline")

struct OdysseyEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot
    var prefs: WidgetPrefs
}

struct OdysseyProvider: TimelineProvider {
    func placeholder(in context: Context) -> OdysseyEntry {
        OdysseyEntry(date: Date(), snapshot: .placeholder, prefs: WidgetPrefs())
    }

    func getSnapshot(in context: Context, completion: @escaping (OdysseyEntry) -> Void) {
        log.info("snapshot requested, preview: \(context.isPreview), family: \(String(describing: context.family))")
        let entry = context.isPreview
            ? OdysseyEntry(date: Date(), snapshot: .placeholder, prefs: WidgetPrefs())
            : OdysseyEntry(date: Date(), snapshot: SharedStore.snapshot(), prefs: SharedStore.prefs())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OdysseyEntry>) -> Void) {
        let now = Date()
        let snapshot = SharedStore.snapshot()
        log.info("timeline requested, family: \(String(describing: context.family)), streak: \(snapshot.streakDays)")
        let prefs = SharedStore.prefs()
        let midnight = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400))
        let entries = [
            OdysseyEntry(date: now, snapshot: snapshot, prefs: prefs),
            OdysseyEntry(date: midnight, snapshot: snapshot, prefs: prefs),
        ]
        completion(Timeline(entries: entries, policy: .after(min(midnight, now.addingTimeInterval(3_600)))))
    }
}

/// One widget kind drawn for whichever family the system asks for.
struct OdysseyWidgetEntryView: View {
    var kind: OdysseyWidgetKind
    var entry: OdysseyEntry
    @Environment(\.widgetFamily) private var family

    private var size: WidgetSize {
        switch family {
        case .systemSmall: return .small
        case .systemMedium: return .medium
        case .systemLarge, .systemExtraLarge: return .large
        case .accessoryCircular: return .circular
        case .accessoryRectangular: return .rectangular
        case .accessoryInline: return .inline
        @unknown default: return .small
        }
    }

    var body: some View {
        let style = entry.prefs.style(for: kind)
        if size.isAccessory {
            OdysseyWidgetContent(kind: kind, size: size, snapshot: entry.snapshot, prefs: entry.prefs)
                .widgetURL(OdysseyWidgetContent.link(kind, entry.snapshot))
                .containerBackground(for: .widget) {
                    if size == .circular { AccessoryWidgetBackground() } else { Color.clear }
                }
        } else {
            OdysseyWidgetContent(kind: kind, size: size, snapshot: entry.snapshot, prefs: entry.prefs)
                .widgetURL(OdysseyWidgetContent.link(kind, entry.snapshot))
                .containerBackground(for: .widget) {
                    OdysseyWidgetBackground(kind: kind, style: style, snapshot: entry.snapshot)
                }
        }
    }
}

private func families(_ kind: OdysseyWidgetKind) -> [WidgetFamily] {
    kind.sizes.map { size in
        switch size {
        case .small: return .systemSmall
        case .medium: return .systemMedium
        case .large: return .systemLarge
        case .circular: return .accessoryCircular
        case .rectangular: return .accessoryRectangular
        case .inline: return .accessoryInline
        }
    }
}

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: OdysseyWidgetKind.streak.kindID, provider: OdysseyProvider()) { entry in
            OdysseyWidgetEntryView(kind: .streak, entry: entry)
        }
        .configurationDisplayName("Streak")
        .description("Globie wakes up when today counts and changes form at every milestone.")
        .supportedFamilies(families(.streak))
    }
}

struct AdventureWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: OdysseyWidgetKind.adventure.kindID, provider: OdysseyProvider()) { entry in
            OdysseyWidgetEntryView(kind: .adventure, entry: entry)
        }
        .configurationDisplayName("Today's Adventure")
        .description("One place picked for you each day, with the coins waiting there.")
        .supportedFamilies(families(.adventure))
        .contentMarginsDisabled()
    }
}

struct CoinsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: OdysseyWidgetKind.coins.kindID, provider: OdysseyProvider()) { entry in
            OdysseyWidgetEntryView(kind: .coins, entry: entry)
        }
        .configurationDisplayName("Coins and Rank")
        .description("Your balance and how close you are to the next rank.")
        .supportedFamilies(families(.coins))
    }
}

struct FriendsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: OdysseyWidgetKind.friends.kindID, provider: OdysseyProvider()) { entry in
            OdysseyWidgetEntryView(kind: .friends, entry: entry)
        }
        .configurationDisplayName("Friends Exploring")
        .description("Who is out exploring right now, and where.")
        .supportedFamilies(families(.friends))
    }
}

struct QuestWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: OdysseyWidgetKind.quest.kindID, provider: OdysseyProvider()) { entry in
            OdysseyWidgetEntryView(kind: .quest, entry: entry)
        }
        .configurationDisplayName("Quest")
        .description("The quest you are working on and how long is left.")
        .supportedFamilies(families(.quest))
    }
}

struct LeaderboardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: OdysseyWidgetKind.leaderboard.kindID, provider: OdysseyProvider()) { entry in
            OdysseyWidgetEntryView(kind: .leaderboard, entry: entry)
        }
        .configurationDisplayName("Leaderboard")
        .description("Where you stand this week against friends and your city.")
        .supportedFamilies(families(.leaderboard))
    }
}
