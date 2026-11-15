//
//  Icon.swift
//  Odyssey
//
//  The mockup names its icons ("coffee", "flame", "thumb-up"); this maps
//  each name onto the closest SF Symbol, so data and ported screens can keep
//  using the same names. Unknown names fall back to a plain circle.
//

import Foundation
import SwiftUI

enum Icon {
    static let map: [String: String] = [
        "compass": "safari", "users": "person.2", "plus": "plus", "minus": "minus", "calendar": "calendar",
        "user": "person", "bell": "bell", "search": "magnifyingglass", "pin": "mappin", "star": "star",
        "star-fill": "star.fill", "sparkle": "sparkle", "flame": "flame.fill", "coin": "circle.hexagongrid.fill",
        "back": "chevron.left", "chevron": "chevron.right", "down": "chevron.down", "up": "chevron.up",
        "close": "xmark", "camera": "camera", "image": "photo", "check": "checkmark", "share": "square.and.arrow.up",
        "heart": "heart", "heart-fill": "heart.fill", "chat": "bubble.left", "trophy": "trophy", "crown": "crown",
        "lock": "lock.fill", "gear": "gearshape", "edit": "pencil", "globe": "globe.americas", "route": "point.topleft.down.to.point.bottomright.curvepath",
        "navigate": "location.north.fill", "door": "door.left.hand.open", "layers": "square.3.layers.3d",
        "sliders": "slider.horizontal.3", "clock": "clock", "book": "book", "coffee": "cup.and.saucer",
        "food": "fork.knife", "tree": "tree", "landmark": "building.columns", "music": "music.note",
        "bag": "bag", "bolt": "bolt.fill", "ticket": "ticket", "dollar": "dollarsign", "store": "storefront",
        "card": "creditcard", "gift": "gift", "upload": "square.and.arrow.up", "link": "link", "more": "ellipsis",
        "flag": "flag.fill", "target": "scope", "locate": "location", "footprints": "figure.walk",
        "building": "building.2", "hallway": "door.sliding.left.hand.open", "mountain": "mountain.2",
        "ship": "sailboat", "plane": "airplane", "leaf": "leaf", "scroll": "scroll", "snow": "snowflake",
        "rocket": "paperplane", "wave": "water.waves", "diamond": "diamond.fill", "eye": "eye",
        "logout": "rectangle.portrait.and.arrow.right", "refresh": "arrow.clockwise", "send": "paperplane.fill",
        "mail": "envelope", "trash": "trash", "grid": "square.grid.2x2", "medal": "medal", "shield": "shield",
        "swap": "arrow.left.arrow.right", "location": "location", "location-fill": "location.fill",
        "moon": "moon.fill", "sun": "sun.max", "video": "video", "thumb-up": "hand.thumbsup",
        "thumb-up-fill": "hand.thumbsup.fill", "thumb-down": "hand.thumbsdown", "thumb-down-fill": "hand.thumbsdown.fill",
        "cake": "birthday.cake", "fuel": "fuelpump", "home": "house", "map-out": "map", "widget": "square.grid.2x2.fill",
        "home-fill": "house.fill", "users-fill": "person.2.fill", "compass-fill": "safari.fill", "user-fill": "person.fill",
    ]

    static func symbol(_ name: String) -> String {
        if name.contains(".") { return name }
        return map[name] ?? "circle"
    }
}

/// Small coin glyph used next to balances.
struct CoinIcon: View {
    var size: CGFloat = 16

    var body: some View {
        ZStack {
            Circle().fill(Palette.gold)
            Circle().strokeBorder(Color(hex: "#d99a00"), lineWidth: size * 0.1)
            Image(systemName: "diamond.fill").font(.system(size: size * 0.4, weight: .bold)).foregroundStyle(.white.opacity(0.9))
        }
        .frame(width: size, height: size)
    }
}
