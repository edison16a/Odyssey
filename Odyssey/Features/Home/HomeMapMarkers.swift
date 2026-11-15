//
//  HomeMapMarkers.swift
//  Odyssey
//
//  Small markers drawn on the home map: the city and state name pills, the
//  place pins and the gold pin for places you starred. The map shows them
//  as cached pictures (HomeMapEngine.swift), so they must draw from their
//  own values only.
//

import Foundation
import SwiftUI

/// City and state name pills: blue with a check once explored, white with a lock before.
struct HomeRegionPill: View {
    var name: String
    var explored: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: explored ? "checkmark" : "lock.fill").font(.system(size: 9, weight: .bold))
            Text(name).font(.system(size: 11, weight: .bold))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .foregroundStyle(explored ? .white : Palette.muted)
        .background(explored ? Palette.accent : .white.opacity(0.92), in: Capsule())
        .shadow(color: Palette.ink.opacity(0.12), radius: 2, y: 1)
    }
}

/// A place pin: blue for explored, black for yours, purple for brand new, gold for starred.
/// It draws only from the precomputed pin, so a redraw never reaches the store.
struct HomePinView: View {
    var pin: HomePin

    var body: some View {
        Image(systemName: Icon.symbol(pin.kind == .star ? "star-fill" : pin.glyph))
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(color, in: Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .frame(width: 30, height: 30)
            .contentShape(Circle())
            // The name sits beside the pin like Google Maps, without moving the pin's anchor.
            .overlay(alignment: .leading) {
                if pin.label {
                    Text(pin.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .frame(width: 130, alignment: .leading)
                        .shadow(color: .white, radius: 0, x: 1, y: 1)
                        .shadow(color: .white, radius: 0, x: -1, y: -1)
                        .shadow(color: .white, radius: 1.5)
                        .offset(x: 32)
                        .allowsHitTesting(false)
                }
            }
    }

    private var color: Color {
        switch pin.kind {
        case .new: return Palette.rare
        case .mine: return Palette.ink
        case .star: return Palette.gold
        case .explored, .destination: return Palette.accent
        }
    }
}

/// A gold teardrop pin for a starred place, standing above the regular pin.
struct HomeStarPin: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "star.fill")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Palette.gold, in: Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
            Triangle()
                .fill(Palette.gold)
                .frame(width: 10, height: 7)
                .offset(y: -1.5)
        }
        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
        .padding(.bottom, 12)
        .contentShape(Rectangle())
        .accessibilityLabel("Starred place")
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
