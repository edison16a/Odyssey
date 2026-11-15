//
//  Palette.swift
//  Shared by the app and the widgets.
//
//  The brand is black and white with one blue accent for anything that
//  means "explored" or "yours". These match the tokens in the HTML mockup
//  one for one, so a screen ported from it looks the same.
//

import Foundation
import SwiftUI

nonisolated enum Palette {
    static let ink = Color(hex: "#0b0b0c")
    static let ink2 = Color(hex: "#2a2a2e")
    static let muted = Color(hex: "#6b6b73")
    static let faint = Color(hex: "#a1a1aa")
    static let line = Color(hex: "#ececef")
    static let lineStrong = Color(hex: "#dcdce1")
    static let surface = Color.white
    static let surface2 = Color(hex: "#f6f6f8")
    static let surface3 = Color(hex: "#efeff2")
    static let canvas = Color(hex: "#e9e9ec")

    static let accent = Color(hex: "#2b59ff")
    static let accentInk = Color(hex: "#1638c7")
    static let accentSoft = Color(hex: "#e8eeff")
    static let gold = Color(hex: "#f2b21b")
    static let goldSoft = Color(hex: "#fff5db")
    static let flame = Color(hex: "#ff6a2b")
    static let flameSoft = Color(hex: "#ffede4")
    static let success = Color(hex: "#17a35a")
    static let successSoft = Color(hex: "#e3f6ec")
    static let danger = Color(hex: "#e5484d")
    static let rare = Color(hex: "#8a5cff")
    static let rareSoft = Color(hex: "#f1ebff")
}

nonisolated extension Color {
    /// A color from a CSS style hex string such as "#2b59ff" or "2b59ff".
    init(hex: String, opacity: Double = 1) {
        let clean = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&value)
        let r, g, b: Double
        if clean.count == 3 {
            r = Double((value >> 8) & 0xF) / 15
            g = Double((value >> 4) & 0xF) / 15
            b = Double(value & 0xF) / 15
        } else {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
