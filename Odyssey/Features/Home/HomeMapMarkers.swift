//
//  HomeMapMarkers.swift
//  Odyssey
//
//  Small markers drawn on the home map: the blue dot for where you are
//  standing in the demo, the city and state name pills, the place pins and
//  the gold pin for places you starred.
//

import Foundation
import SwiftUI

/// The blue "you are here" dot for the demo spot.
struct HomeMeDot: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#1a73e8").opacity(0.35))
                .frame(width: 22, height: 22)
                .scaleEffect(pulse ? 2 : 1)
                .opacity(pulse ? 0 : 1)
            Circle()
                .fill(Color(hex: "#1a73e8"))
                .frame(width: 16, height: 16)
                .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 2.2).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}

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
    @Environment(\.animationsPaused) private var paused
    @State private var pulse = false

    var body: some View {
        if pin.kind == .star {
            HomeStarPin()
        } else {
            ZStack {
                if pin.kind == .new && pin.pulses && !paused {
                    Circle()
                        .fill(Palette.rare)
                        .frame(width: 22, height: 22)
                        .scaleEffect(pulse ? 2.1 : 1)
                        .opacity(pulse ? 0 : 0.6)
                        .onAppear {
                            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) { pulse = true }
                        }
                }
                Image(systemName: Icon.symbol(pin.glyph))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(color, in: Circle())
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
            }
            .frame(width: 30, height: 30)
            .contentShape(Circle())
        }
    }

    private var color: Color {
        switch pin.kind {
        case .new: return Palette.rare
        case .mine: return Palette.ink
        case .explored, .star: return Palette.accent
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
