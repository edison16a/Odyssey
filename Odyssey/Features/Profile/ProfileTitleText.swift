//
//  ProfileTitleText.swift
//  Odyssey
//
//  Title lettering. Every title from the shop has its own look, and the
//  same view is used in the shop, the preview and under your name, so what
//  you buy is exactly what people see. Each title is one flat color; the
//  fancier ones add a small motion: a glint passing through the letters, a
//  flicker, a flash, or colors that drift.
//

import Foundation
import SwiftUI

struct ProfileTitleText: View {
    @Environment(\.animationsPaused) private var animationsPaused
    var id: String
    var text: String
    var size: CGFloat = 15

    private enum Motion { case none, glint(Double), flicker, flash, drift([String], Double), spectrum }

    private struct Style {
        var color: String
        var highlight: String = "#ffffff"
        var motion: Motion = .none
        var serif = false
        var glow: String? = nil
    }

    private var style: Style {
        switch id {
        case "coffee-scout": return Style(color: "#8a5a2b")
        case "door-finder": return Style(color: "#2b59ff")
        case "summit-seeker": return Style(color: "#16a34a")
        case "sea-breeze": return Style(color: "#0e7490")
        case "lorekeeper": return Style(color: "#22291f", serif: true)
        case "wildflower": return Style(color: "#c026d3")
        case "night-owl": return Style(color: "#4f46e5", highlight: "#e0e7ff", motion: .glint(5))
        case "golden-hour": return Style(color: "#c98200", highlight: "#fff7cc", motion: .glint(3))
        case "trailblazer": return Style(color: "#ea580c", highlight: "#fde047", motion: .flicker, glow: "#f97316")
        case "storm-rider": return Style(color: "#1d6fd6", highlight: "#e0f2fe", motion: .flash)
        case "neon-drifter": return Style(color: "#ff2bd6", motion: .drift(["#ff2bd6", "#22d3ee"], 3.5), glow: "#ff2bd6")
        case "rare-finder": return Style(color: "#7c4dff", highlight: "#f3e8ff", motion: .glint(2.6))
        case "aurora-chaser": return Style(color: "#34d399", motion: .drift(["#34d399", "#22d3ee", "#a78bfa"], 6))
        case "mythic-mapper": return Style(color: "#ef4444", motion: .spectrum)
        case "polar-explorer": return Style(color: "#0ea5e9", highlight: "#d6f3ff", motion: .glint(4))
        default: return Style(color: "#475569")
        }
    }

    var body: some View {
        let s = style
        Group {
            switch s.motion {
            case .none:
                letters(Color(hex: s.color))
            default:
                TimelineView(OdysseyMotion.schedule(paused: animationsPaused)) { timeline in
                    animated(s, time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .shadow(color: s.glow.map { Color(hex: $0).opacity(0.45) } ?? .clear, radius: 4)
        .fixedSize()
    }

    private func letters(_ color: Color) -> some View {
        Text(text)
            .font(style.serif ? Font.system(size: size, weight: .bold, design: .serif).italic() : Font.system(size: size, weight: .heavy))
            .tracking(style.serif ? 0.6 : 0.15)
            .foregroundStyle(color)
            .lineLimit(1)
    }

    @ViewBuilder
    private func animated(_ s: Style, time: Double) -> some View {
        switch s.motion {
        case .glint(let period):
            letters(Color(hex: s.color))
                .overlay {
                    GeometryReader { geo in
                        let phase = time.truncatingRemainder(dividingBy: period) / period
                        letters(Color(hex: s.highlight))
                            .mask(alignment: .leading) {
                                Rectangle()
                                    .frame(width: geo.size.width * 0.18)
                                    .offset(x: geo.size.width * (phase * 1.5 - 0.3))
                            }
                    }
                }
        case .flicker:
            let wave = (sin(time * 2 * .pi / 1.1) + 1) / 2
            letters(Color(hex: s.color))
                .overlay { letters(Color(hex: s.highlight)).opacity(wave * 0.55) }
        case .flash:
            let cycle = time.truncatingRemainder(dividingBy: 3.2) / 3.2
            letters(Color(hex: s.color))
                .overlay { letters(Color(hex: s.highlight)).opacity(cycle > 0.9 && cycle < 0.94 ? 0.9 : 0) }
        case .drift(let colors, let period):
            let position = time.truncatingRemainder(dividingBy: period) / period * Double(colors.count)
            let index = Int(position) % colors.count
            let next = (index + 1) % colors.count
            let mix = position - Double(Int(position))
            letters(Color(hex: colors[index]))
                .overlay { letters(Color(hex: colors[next])).opacity(mix) }
        case .spectrum:
            letters(Color(hex: s.color))
                .hueRotation(.degrees(time.truncatingRemainder(dividingBy: 6) / 6 * 360))
        case .none:
            letters(Color(hex: s.color))
        }
    }
}

extension ProfileTitleText {
    /// The title for an id from the seed, or nil when the id is unknown.
    init?(titleID: String, size: CGFloat = 15) {
        guard let title = Seed.shared.titles.first(where: { $0.id == titleID }) else { return nil }
        self.init(id: title.id, text: title.name, size: size)
    }
}
