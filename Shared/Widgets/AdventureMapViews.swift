//
//  AdventureMapViews.swift
//  Shared by the app and the widgets.
//
//  The pieces of the map style: the map the app rendered with the place's
//  photo pinned where it is and a dotted walk from your blue dot, plus the
//  little tags and backup chips around it. Without a map yet it shows the
//  place's photo instead.
//

import Foundation
import SwiftUI

struct AdventureMapPanel: View {
    var pick: AdventurePick
    var pin: CGFloat = 46

    var body: some View {
        if let map = SharedStore.image(pick.mapFile) {
            GeometryReader { geo in
                let size = geo.size
                let side = max(size.width, size.height)
                let originX = (size.width - side) / 2
                let originY = (size.height - side) / 2
                let place = CGPoint(x: originX + CGFloat(pick.placeX ?? 0.5) * side,
                                    y: originY + CGFloat(pick.placeY ?? 0.5) * side)
                ZStack(alignment: .topLeading) {
                    Image(uiImage: map).resizable().scaledToFill()
                        .frame(width: size.width, height: size.height).clipped()
                    if let youX = pick.youX, let youY = pick.youY {
                        let you = CGPoint(x: originX + CGFloat(youX) * side, y: originY + CGFloat(youY) * side)
                        AdventureRouteLine(from: you, to: place)
                            .stroke(Palette.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [3, 5]))
                        Circle().fill(Palette.accent)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                            .position(you)
                    }
                    AdventurePin(file: pick.imageFile, size: pin, first: pick.isFirst)
                        .position(x: place.x, y: place.y - (pin + 7) / 2)
                }
            }
        } else {
            WidgetPhoto(file: pick.imageFile)
        }
    }
}

/// The place's photo in a round bubble with a white ring and a point.
struct AdventurePin: View {
    var file: String?
    var size: CGFloat
    var first: Bool

    var body: some View {
        VStack(spacing: -1) {
            WidgetPhoto(file: file)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                .overlay(alignment: .topTrailing) {
                    if first {
                        Image(systemName: "star.fill")
                            .font(.system(size: size * 0.18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: size * 0.38, height: size * 0.38)
                            .background(Palette.rare, in: Circle())
                            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                            .offset(x: 4, y: -4)
                    }
                }
            WidgetPointer().fill(.white).frame(width: 12, height: 8)
        }
        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
    }
}

/// A straight dotted walk from you to the place.
nonisolated struct AdventureRouteLine: Shape {
    var from: CGPoint
    var to: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        return path
    }
}

/// "TODAY" on a white pill, pinned to the corner of the map.
struct AdventureMapTag: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "location.north.fill").font(.system(size: 9, weight: .bold))
            Text("TODAY").font(.system(size: 10, weight: .heavy)).tracking(0.5)
        }
        .foregroundStyle(Palette.accent)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(.white, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
    }
}

/// "Be first" in purple, for places nobody on Odyssey has explored.
struct AdventureFirstTag: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill").font(.system(size: 9, weight: .bold))
            Text("Be first").font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(Palette.rare, in: Capsule())
    }
}

/// A backup pick as a small chip with its photo.
struct AdventureBackupChip: View {
    var pick: AdventurePick

    var body: some View {
        HStack(spacing: 7) {
            WidgetPhoto(file: pick.imageFile)
                .frame(width: 30, height: 30)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 0) {
                Text(pick.name).font(.system(size: 11.5, weight: .bold)).lineLimit(1).foregroundStyle(Palette.ink)
                Text(pick.distanceText + ", +\(pick.coins)").font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
