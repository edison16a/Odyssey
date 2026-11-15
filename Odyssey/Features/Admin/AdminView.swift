//
//  AdminView.swift
//  Odyssey
//
//  The admin screen at the bottom of Settings. Set every stat by hand
//  (streak, coins, XP, points, bounty cash and the counts on your profile),
//  jump straight to any scene, put the hackathon spot back to unexplored, and
//  reset the app while your name, handle and photo stay as they are. Demo
//  mode sits at the top.
//

import Foundation
import SwiftUI

struct AdminView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toast
    @State private var confirmReset = false

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Admin", back: { router.pop() })
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    AdminDemoCard()
                    profile
                    stats
                    AdminScenes()
                    places
                    reset
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Palette.surface)
        .confirmationDialog("Reset app data?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                router.popToRoot()
                router.tab = .home
                store.reset()
                Task { await Cloud.shared.signOut() }
                toast.show("Fresh start. Your name and photo stayed.", icon: "refresh")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Coins, streak, check-ins and cosmetics go back to the start and you are signed out. Your name, handle and profile photo stay.")
        }
    }

    private var profile: some View {
        AdminSection(title: "Profile", note: "Kept when you reset") {
            AdminTextRow(title: "Name", text: binding(\.user.name))
            AdminTextRow(title: "Handle", text: binding(\.user.handle))
        }
    }

    private var stats: some View {
        AdminSection(title: "Stats", note: "Changes save as you type") {
            AdminNumberRow(title: "Streak days", icon: "flame", value: binding(\.streak.days), step: 1)
            Toggle(isOn: Binding(get: { store.streakClaimedToday },
                                 set: { on in store.update { $0.streak.lastDay = on ? Format.today() : nil } })) {
                Text("Today already counted").font(.system(size: 15))
            }
            .tint(Palette.accent)
            .padding(.vertical, 6)
            AdminNumberRow(title: "Best streak", icon: "trophy", value: binding(\.streak.best), step: 1)
            AdminNumberRow(title: "Coins", icon: "coin", value: binding(\.wallet.coins), step: 100)
            AdminNumberRow(title: "XP", icon: "bolt", value: binding(\.wallet.xp), step: 50)
            AdminNumberRow(title: "Ranking points", icon: "target", value: binding(\.wallet.points), step: 10)
            AdminNumberRow(title: "Bounty cash, cents", icon: "dollar", value: cashCents, step: 100)
            AdminNumberRow(title: "Places explored", icon: "pin", value: binding(\.stats.explored), step: 1)
            AdminNumberRow(title: "Friends", icon: "users", value: binding(\.stats.friends), step: 1)
            AdminNumberRow(title: "Walkthroughs", icon: "video", value: binding(\.stats.contributions), step: 1)
            AdminNumberRow(title: "Kilometres", icon: "footprints", value: kilometres, step: 5)
        }
    }

    private var places: some View {
        AdminSection(title: "Places", note: nil) {
            AdminActionRow(title: "Make Y Combinator unexplored again", icon: "star") {
                store.update { s in
                    s.visited.removeAll { $0 == "yc" }
                    s.firsts.removeAll { $0 == "yc" }
                    s.checkins["yc"] = nil
                    s.questsDone["q-yc"] = nil
                }
                toast.show("Y Combinator is waiting for its first explorer", icon: "star")
            }
            AdminActionRow(title: "Allow checking in again today", icon: "camera") {
                store.update { s in s.checkins = [:] }
                toast.show("Every place can be checked in again today", icon: "check")
            }
        }
    }

    private var reset: some View {
        AdminSection(title: "Data", note: nil) {
            AdminActionRow(title: "Reset app data", icon: "refresh", danger: true) { confirmReset = true }
        }
    }

    /// A two way binding into the saved state.
    private func binding<T>(_ path: WritableKeyPath<AppState, T>) -> Binding<T> {
        Binding(get: { store.state[keyPath: path] }, set: { value in store.update { $0[keyPath: path] = value } })
    }

    private var cashCents: Binding<Int> {
        Binding(get: { Int((store.state.wallet.cash * 100).rounded()) },
                set: { cents in store.update { $0.wallet.cash = Double(max(0, cents)) / 100 } })
    }

    private var kilometres: Binding<Int> {
        Binding(get: { Int(store.state.stats.km.rounded()) }, set: { km in store.update { $0.stats.km = Double(max(0, km)) } })
    }
}
