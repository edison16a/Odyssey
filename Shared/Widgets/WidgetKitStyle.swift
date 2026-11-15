//
//  WidgetKitStyle.swift
//  Shared by the app and the widgets.
//
//  Colors and backgrounds for each widget style. Light is white with ink
//  text, dark is ink with white text, "streak form" takes the colors of
//  the Globie form your streak has reached, photo puts today's place
//  behind the words, map draws today's place on a real map and color gives
//  coins, friends, quests and the leaderboard their own bold background. The app's gallery and the real widgets both draw from
//  here, so a preview always matches what lands on the home screen.
//

import Foundation
import SwiftUI
import UIKit

nonisolated struct WidgetColors: Sendable {
    var text: Color
    var secondary: Color
    var accent: Color
    var chip: Color
    var dark: Bool
}

nonisolated enum WidgetLook {
    static func colors(_ kind: OdysseyWidgetKind, _ style: WidgetStyle, _ snapshot: WidgetSnapshot) -> WidgetColors {
        switch style {
        case .light:
            return WidgetColors(text: Palette.ink, secondary: Palette.muted, accent: accent(kind, snapshot, dark: false),
                                chip: Palette.surface2, dark: false)
        case .dark:
            return WidgetColors(text: .white, secondary: .white.opacity(0.62), accent: accent(kind, snapshot, dark: true),
                                chip: .white.opacity(0.12), dark: true)
        case .globie:
            let tier = snapshot.tier
            return WidgetColors(text: .white, secondary: .white.opacity(0.66), accent: tier.color,
                                chip: .white.opacity(0.12), dark: true)
        case .photo:
            return WidgetColors(text: .white, secondary: .white.opacity(0.82), accent: .white,
                                chip: .black.opacity(0.35), dark: true)
        case .map:
            return WidgetColors(text: Palette.ink, secondary: Palette.muted, accent: Palette.accent,
                                chip: Palette.surface2, dark: false)
        case .vivid:
            if kind == .coins {
                return WidgetColors(text: Palette.ink, secondary: Palette.ink.opacity(0.62), accent: Palette.ink,
                                    chip: .black.opacity(0.1), dark: false)
            }
            if kind == .leaderboard {
                return WidgetColors(text: .white, secondary: .white.opacity(0.68), accent: Palette.gold,
                                    chip: Medal.indigoChip, dark: true)
            }
            return WidgetColors(text: .white, secondary: .white.opacity(0.78), accent: .white,
                                chip: .white.opacity(0.2), dark: true)
        }
    }

    /// The bold background each widget gets in the Color style.
    static func vividColor(_ kind: OdysseyWidgetKind, _ snapshot: WidgetSnapshot) -> Color {
        switch kind {
        case .coins: return Palette.gold
        case .friends: return Palette.accent
        case .quest: return Color(hex: snapshot.quest?.colorHex ?? "#2b59ff")
        case .streak: return snapshot.tier.background
        case .adventure: return Palette.accent
        case .leaderboard: return Medal.indigo
        }
    }

    private static func accent(_ kind: OdysseyWidgetKind, _ snapshot: WidgetSnapshot, dark: Bool) -> Color {
        switch kind {
        case .streak: return Palette.flame
        case .coins: return Palette.gold
        case .quest: return Color(hex: snapshot.quest?.colorHex ?? "#2b59ff")
        case .leaderboard: return dark ? Palette.gold : Color(hex: "#b07a00")
        default: return dark ? Color(hex: "#6f8dff") : Palette.accent
        }
    }
}

/// The background behind a widget. Accessory sizes get none; the system draws them.
struct OdysseyWidgetBackground: View {
    var kind: OdysseyWidgetKind
    var style: WidgetStyle
    var snapshot: WidgetSnapshot

    var body: some View {
        switch style {
        case .light:
            kind == .streak ? Color(hex: "#eef3ff") : Color.white
        case .dark:
            Palette.ink
        case .globie:
            snapshot.tier.background
        case .photo:
            ZStack {
                if let image = SharedStore.image(snapshot.adventure?.imageFile) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Palette.ink2
                }
                LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.0), .black.opacity(0.62)],
                               startPoint: .top, endPoint: .bottom)
            }
        case .map:
            Color.white
        case .vivid:
            WidgetLook.vividColor(kind, snapshot)
        }
    }
}

/// Small caps label used at the top of widgets ("TODAY'S ADVENTURE").
struct WidgetLabel: View {
    var text: String
    var symbol: String
    var color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 10, weight: .bold))
            Text(text.uppercased()).font(.system(size: 10.5, weight: .bold)).tracking(0.4).lineLimit(1)
        }
        .foregroundStyle(color)
    }
}

/// A coin with an amount, for rewards waiting at a place.
struct WidgetCoins: View {
    var amount: Int
    var color: Color
    var background: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(Palette.gold).frame(width: 11, height: 11)
                .overlay(Image(systemName: "diamond.fill").font(.system(size: 5, weight: .bold)).foregroundStyle(.white))
            Text("+\(amount)").font(.system(size: 12, weight: .bold)).monospacedDigit()
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(background, in: Capsule())
    }
}

/// A friend's face from the shared folder, or their initial.
struct WidgetFace: View {
    var name: String
    var file: String?
    var size: CGFloat = 26

    var body: some View {
        Group {
            if let image = SharedStore.image(file, maxSide: max(96, size * 3)) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Palette.accentSoft
                    Text(String(name.prefix(1))).font(.system(size: size * 0.45, weight: .bold)).foregroundStyle(Palette.accentInk)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

/// A place photo from the shared folder.
struct WidgetPhoto: View {
    var file: String?

    var body: some View {
        if let image = SharedStore.image(file) {
            Color.clear.overlay { Image(uiImage: image).resizable().scaledToFill() }.clipped()
        } else {
            Palette.surface3.overlay { Image(systemName: "photo").foregroundStyle(Palette.faint) }
        }
    }
}
