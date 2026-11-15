//
//  Theme.swift
//  Odyssey
//
//  Type, shape and the reusable controls every screen is built from. The
//  sizes match the HTML mockup's tokens (15pt body, 50pt pill buttons,
//  22pt card corners) so a ported screen lines up with the original.
//

import Foundation
import SwiftUI

enum Radius {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 22
    static let xl: CGFloat = 28
}

enum Space {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s8: CGFloat = 32
}

extension Font {
    /// The mockup's type scale: 11, 13, 15, 17, 22, 28 and 34 points.
    static func odyssey(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static let pXS = Font.system(size: 11, weight: .semibold)
    static let pSM = Font.system(size: 13)
    static let pMD = Font.system(size: 15)
    static let pLG = Font.system(size: 17, weight: .semibold)
    static let pXL = Font.system(size: 22, weight: .bold)
    static let p2XL = Font.system(size: 28, weight: .bold)
    static let p3XL = Font.system(size: 34, weight: .heavy)
}

extension View {
    /// Big screen titles: tight tracking like the mockup's h1.
    func titleStyle(_ size: CGFloat = 28) -> some View {
        font(.system(size: size, weight: .bold)).tracking(-0.6).foregroundStyle(Palette.ink)
    }

    /// Small caps labels above widget values ("COINS", "TODAY").
    func labelStyle(_ color: Color = Palette.muted) -> some View {
        font(.system(size: 11, weight: .semibold)).tracking(0.5).textCase(.uppercase).foregroundStyle(color)
    }

    func mutedStyle(_ size: CGFloat = 13) -> some View {
        font(.system(size: size)).foregroundStyle(Palette.muted)
    }

    /// White card with a hairline edge.
    func card(padding: CGFloat = Space.s4, radius: CGFloat = Radius.lg) -> some View {
        self.padding(padding)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
    }

    /// Soft grey card.
    func softCard(padding: CGFloat = Space.s4, radius: CGFloat = Radius.lg) -> some View {
        self.padding(padding)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Black card with white text.
    func darkCard(padding: CGFloat = Space.s4, radius: CGFloat = Radius.lg) -> some View {
        self.padding(padding)
            .foregroundStyle(.white)
            .background(Palette.ink, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// A soft press: shrink a little while held.
    func pressable() -> some View { buttonStyle(PressStyle()) }
}

/// The scale-on-press every tappable surface uses.
struct PressStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// Pill buttons: primary is black, accent is blue, soft is grey, light is white.
struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, accent, soft, light, ghost, outline, glass, success }
    var kind: Kind = .primary
    var height: CGFloat = 50
    var fill = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: height < 40 ? 13 : 15, weight: .semibold))
            .tracking(-0.15)
            .lineLimit(1)
            .padding(.horizontal, height < 40 ? 16 : 24)
            .frame(height: height)
            .frame(maxWidth: fill ? .infinity : nil)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
            .overlay {
                if kind == .outline { Capsule().strokeBorder(Palette.lineStrong, lineWidth: 1.5) }
            }
            .opacity(isEnabled ? 1 : 0.35)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary, .accent, .glass, .success: return .white
        default: return Palette.ink
        }
    }

    private var background: Color {
        switch kind {
        case .primary: return Palette.ink
        case .accent: return Palette.accent
        case .soft: return Palette.surface2
        case .light: return .white
        case .ghost, .outline: return .clear
        case .glass: return .white.opacity(0.16)
        case .success: return Palette.success
        }
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static func pill(_ kind: PillButtonStyle.Kind = .primary, height: CGFloat = 50, fill: Bool = false) -> PillButtonStyle {
        PillButtonStyle(kind: kind, height: height, fill: fill)
    }
}

/// Round icon button, 40pt, grey by default.
struct IconButton: View {
    enum Kind { case soft, white, clear, dark }
    var icon: String
    var kind: Kind = .soft
    var size: CGFloat = 40
    var badge: Int = 0
    var label: String = ""
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: Icon.symbol(icon))
                .font(.system(size: size * 0.45, weight: .semibold))
                .frame(width: size, height: size)
                .foregroundStyle(kind == .dark ? .white : Palette.ink)
                .background {
                    switch kind {
                    case .soft: Circle().fill(Palette.surface2)
                    case .white: Circle().fill(.white).shadow(color: .black.opacity(0.08), radius: 10, y: 6)
                    case .clear: Color.clear
                    case .dark: Circle().fill(.black.opacity(0.45)).background(.ultraThinMaterial, in: Circle())
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .frame(minWidth: 17, minHeight: 17)
                            .background(Palette.danger, in: Capsule())
                            .overlay(Capsule().strokeBorder(.white, lineWidth: 2))
                            .offset(x: 2, y: -2)
                    }
                }
        }
        .buttonStyle(PressStyle(scale: 0.92))
        .accessibilityLabel(label.isEmpty ? icon : label)
    }
}

/// Filter chip: grey, black when on.
struct Chip: View {
    var label: String
    var icon: String? = nil
    var isOn = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: Icon.symbol(icon)).font(.system(size: 13, weight: .semibold)) }
                Text(label).font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .frame(height: 34)
            .foregroundStyle(isOn ? .white : Palette.ink)
            .background(isOn ? Palette.ink : Palette.surface2, in: Capsule())
        }
        .buttonStyle(PressStyle())
        .animation(.easeOut(duration: 0.16), value: isOn)
    }
}

/// Small status label.
struct Tag: View {
    enum Tone { case plain, accent, gold, rare, flame, success, dark }
    var text: String
    var icon: String? = nil
    var tone: Tone = .plain

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: Icon.symbol(icon)).font(.system(size: 10, weight: .bold)) }
            Text(text).font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .foregroundStyle(colors.0)
        .background(colors.1, in: Capsule())
    }

    private var colors: (Color, Color) {
        switch tone {
        case .plain: return (Palette.ink2, Palette.surface2)
        case .accent: return (Palette.accentInk, Palette.accentSoft)
        case .gold: return (Color(hex: "#9a6a00"), Palette.goldSoft)
        case .rare: return (Color(hex: "#5b34c7"), Palette.rareSoft)
        case .flame: return (Color(hex: "#c2410c"), Palette.flameSoft)
        case .success: return (Color(hex: "#0f7a42"), Palette.successSoft)
        case .dark: return (.white, Palette.ink)
        }
    }
}

/// Section heading with an optional trailing link.
struct SectionHeader: View {
    var title: String
    var link: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 17, weight: .bold)).tracking(-0.3).foregroundStyle(Palette.ink)
            Spacer()
            if let link {
                if let action {
                    Button(link, action: action).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.muted)
                } else {
                    Text(link).font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.muted)
                }
            }
        }
        .padding(.bottom, 10)
    }
}

/// Segmented control: grey track, white pill on the chosen option.
struct Segmented<Value: Hashable>: View {
    var options: [(Value, String)]
    @Binding var selection: Value
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { option in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selection = option.0 }
                } label: {
                    Text(option.1)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selection == option.0 ? Palette.ink : Palette.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background {
                            if selection == option.0 {
                                Capsule().fill(.white).shadow(color: .black.opacity(0.06), radius: 1, y: 1)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Palette.surface2, in: Capsule())
    }
}

/// Thin progress bar.
struct ProgressBar: View {
    var value: Double
    var color: Color = Palette.accent
    var track: Color = Palette.surface3
    var height: CGFloat = 6

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

/// Grey rounded text field with a leading icon.
struct FieldBox<Content: View>: View {
    var icon: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: Space.s2) {
            if let icon { Image(systemName: Icon.symbol(icon)).foregroundStyle(Palette.muted) }
            content
        }
        .padding(.horizontal, Space.s4)
        .frame(height: 50)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }
}

/// Standard pushed screen header: back, centered title, optional trailing button.
struct NavHeader<Trailing: View>: View {
    var title: String
    var back: (() -> Void)? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack {
            Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(Palette.ink).lineLimit(1).padding(.horizontal, 56)
            HStack {
                if let back { IconButton(icon: "back", kind: .clear, label: "Back", action: back) } else { Color.clear.frame(width: 40, height: 40) }
                Spacer()
                trailing
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
    }
}

extension NavHeader where Trailing == EmptyView {
    init(title: String, back: (() -> Void)? = nil) {
        self.title = title
        self.back = back
        self.trailing = EmptyView()
    }
}
