//
//  AdminParts.swift
//  Odyssey
//
//  Pieces of the admin screen: a titled section, a number you can type or
//  nudge, a text field, an action row, and the list of scenes to jump to.
//

import Foundation
import SwiftUI

struct AdminSection<Content: View>: View {
    var title: String
    var note: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).labelStyle()
                Spacer()
                if let note { Text(note).font(.system(size: 11)).foregroundStyle(Palette.faint) }
            }
            .padding(.bottom, 6)
            VStack(spacing: 0) { content }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
    }
}

/// A number with a field to type it and minus and plus to nudge it.
struct AdminNumberRow: View {
    var title: String
    var icon: String
    @Binding var value: Int
    var step: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: Icon.symbol(icon)).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.muted).frame(width: 20)
            Text(title).font(.system(size: 15)).lineLimit(1)
            Spacer(minLength: 8)
            nudge("minus") { value = max(0, value - step) }
            TextField("0", value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .frame(width: 78, height: 32)
                .background(.white, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            nudge("plus") { value += step }
        }
        .padding(.vertical, 6)
    }

    private func nudge(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol).font(.system(size: 12, weight: .bold))
                .frame(width: 30, height: 30)
                .foregroundStyle(Palette.ink)
                .background(.white, in: Circle())
        }
        .buttonStyle(PressStyle(scale: 0.9))
    }
}

struct AdminTextRow: View {
    var title: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Text(title).font(.system(size: 15)).frame(width: 70, alignment: .leading)
            TextField(title, text: $text)
                .font(.system(size: 15, weight: .semibold))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 10)
                .frame(height: 36)
                .background(.white, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .padding(.vertical, 6)
    }
}

struct AdminActionRow: View {
    var title: String
    var icon: String
    var danger = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: Icon.symbol(icon)).font(.system(size: 14, weight: .semibold)).frame(width: 20)
                Text(title).font(.system(size: 15, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.faint)
            }
            .foregroundStyle(danger ? Palette.danger : Palette.ink)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Every scene in the app, one tap away.
struct AdminScenes: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        AdminSection(title: "Scenes", note: "Jump straight in") {
            AdminActionRow(title: "Every flow (demo guide)", icon: "compass") { router.push(.demoGuide) }
            AdminActionRow(title: "Landing and sign in", icon: "home") { store.update { $0.session.signedIn = false } }
            AdminActionRow(title: "Onboarding", icon: "sparkle") { store.update { $0.session.onboarded = false } }
            AdminActionRow(title: "Check in at Y Combinator", icon: "camera") { router.present(.checkIn(placeID: "yc")) }
            AdminActionRow(title: "Walkthrough", icon: "video") { router.present(.walkthrough(placeID: "yc")) }
            AdminActionRow(title: "Odyssey Globe", icon: "globe") { router.present(.globe) }
            AdminActionRow(title: "Explored map", icon: "map-out") { router.present(.exploredMap(focus: nil)) }
            AdminActionRow(title: "Arrive in Paris", icon: "plane") { router.present(.countryScene) }
            AdminActionRow(title: "Post a bounty", icon: "store") { router.present(.bountyWizard) }
            AdminActionRow(title: "Share your day", icon: "footprints") { router.present(.dayShare) }
            AdminActionRow(title: "Widgets", icon: "widget") { router.push(.widgets) }
            ForEach(StreakTiers.milestones, id: \.self) { days in
                AdminActionRow(title: "Streak power up at \(days) days", icon: "flame") { router.present(.powerUp(days: days)) }
            }
        }
    }
}
