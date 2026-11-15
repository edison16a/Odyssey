//
//  NotificationsView.swift
//  Odyssey
//
//  The updates inbox. First explorer posts open the story they belong to,
//  friend requests can be answered inline, and everything is marked read
//  once the screen opens, the way a native inbox behaves.
//  Ported from features/notifications/notifications.js.
//

import Foundation
import SwiftUI

struct NotificationsView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(RewardPopCenter.self) private var pop
    /// Unread ids when the screen opened, so the dots stay until you leave.
    @State private var unread: Set<String> = []

    var body: some View {
        let all = store.seed.notifications
        VStack(spacing: 0) {
            NavHeader(title: "Updates", back: { router.pop() })
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    group("Today", all.filter { $0.minutesAgo < 1440 })
                    group("This week", all.filter { $0.minutesAgo >= 1440 })
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .background(Palette.surface)
        .onAppear {
            // Coming back from a pushed screen finds nothing new: keep the dots and skip a save.
            let fresh = Set(all.map(\.id)).subtracting(store.state.readNotifications)
            guard !fresh.isEmpty else { return }
            unread = fresh
            store.update { s in s.readNotifications = all.map(\.id) }
        }
    }

    private func group(_ title: String, _ items: [AppNotification]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(Palette.muted)
                .padding(.top, 16)
                .padding(.bottom, 8)
            ForEach(items) { item in row(item) }
        }
    }

    private func row(_ n: AppNotification) -> some View {
        let who = n.by.flatMap { store.person($0) }
        let pending = n.kind == "request" && store.state.requests.contains(n.by ?? "")
        return HStack(alignment: .top, spacing: 12) {
            lead(n, who: who)
            VStack(alignment: .leading, spacing: 2) {
                Text(n.text).font(.system(size: 13)).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                Text(Format.ago(n.minutesAgo) + " ago").font(.system(size: 11)).foregroundStyle(Palette.muted)
                if pending, let id = n.by {
                    HStack(spacing: 8) {
                        Button("Accept") {
                            store.addFriend(id)
                            pop.friendAdded(id, store: store)
                        }
                        .buttonStyle(.pill(.primary, height: 36))
                        Button("Decline") { store.declineRequest(id) }
                            .buttonStyle(.pill(.soft, height: 36))
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.trailing, 14)
            Spacer(minLength: 0)
        }
        .padding(12)
        .overlay(alignment: .topTrailing) {
            if unread.contains(n.id) {
                Circle().fill(Palette.accent).frame(width: 8, height: 8).padding(.top, 18).padding(.trailing, 12)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { follow(n) }
        .padding(.horizontal, -12)
    }

    @ViewBuilder private func lead(_ n: AppNotification, who: Person?) -> some View {
        let symbol = NotificationsKind.icon(n.kind)
        let color = NotificationsKind.color(n.kind)
        if let who {
            AvatarView(person: who, size: 44, frame: "none")
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: symbol)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(color, in: Circle())
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .offset(x: 4, y: 2)
                }
        } else {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(color, in: Circle())
        }
    }

    /// Route a tap to whatever the notification points at.
    private func follow(_ n: AppNotification) {
        guard let target = n.open else { return }
        if let post = target.post, let found = store.post(post) {
            router.push(.place(found.placeId))
        } else if let place = target.place {
            router.push(.place(place))
        } else if target.screen == "leaderboard" {
            router.push(.leaderboard)
        } else if target.screen == "streak" {
            router.push(.streak)
        } else if target.screen == "globe" {
            router.present(.globe)
        }
    }
}

enum NotificationsKind {
    static func icon(_ kind: String) -> String {
        switch kind {
        case "first": return "star.fill"
        case "quest": return "flag.fill"
        case "rank": return "trophy.fill"
        case "globe": return "globe.americas.fill"
        case "streak": return "flame.fill"
        case "pair": return "person.2.fill"
        case "request": return "person.fill"
        default: return "bell.fill"
        }
    }

    static func color(_ kind: String) -> Color {
        switch kind {
        case "first": return Palette.rare
        case "quest": return Palette.accent
        case "rank": return Palette.gold
        case "globe": return Palette.ink
        case "streak": return Palette.flame
        case "pair": return Color(hex: "#0ea5b7")
        case "request": return Palette.success
        default: return Palette.muted
        }
    }
}
