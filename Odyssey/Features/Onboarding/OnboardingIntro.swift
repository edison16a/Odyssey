//
//  OnboardingIntro.swift
//  Odyssey
//
//  The first four screens of onboarding, which say what Odyssey is before
//  asking for anything. Globie says hello, then the whole app in three
//  moves: find a place, go and check in, get rewarded. The middle one is
//  played, not read: the explorer taps record and "checks in" right there.
//

import Foundation
import SwiftUI

// MARK: Hello

struct OnboardingHelloStep: View {
    var start: () -> Void
    var skip: () -> Void
    @State private var shown = false
    @State private var said = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                Text("Hi, I'm Globie!")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(.white, in: Capsule())
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(.white).frame(width: 12, height: 12).rotationEffect(.degrees(45)).offset(y: 5)
                    }
                    .scaleEffect(said ? 1 : 0.4, anchor: .bottom)
                    .opacity(said ? 1 : 0)
                GlobieView(mood: .ecstatic, size: 132)
                    .frame(width: 150, height: 150)
                    .scaleEffect(shown ? 1 : 0.3)
                    .opacity(shown ? 1 : 0)
            }
            .padding(.bottom, 26)
            VStack(spacing: 10) {
                Text("Odyssey turns going out into a game")
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-0.9)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Visit real places. Earn real rewards.")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .multilineTextAlignment(.center)
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .padding(.bottom, 30)
            VStack(spacing: 14) {
                Button("Show me how", action: start)
                    .buttonStyle(AuthBigButtonStyle())
                Button("Skip intro", action: skip)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.62)) { shown = true }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.55)) { said = true }
        }
    }
}

// MARK: How it works

/// One of the three moves. The picture changes; the frame around it stays.
struct OnboardingHowStep: View {
    @Environment(AppStore.self) private var store
    var index: Int
    var next: () -> Void

    /// The check-in on the second page: idle, filming, done.
    @State private var filming = false
    @State private var filmed = false

    private static let moves = ["Find", "Check in", "Earn"]

    var body: some View {
        VStack(spacing: 0) {
            picture
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: 14) {
                stepper
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.8)
                    Text(sub)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)
                Button(button, action: press)
                    .buttonStyle(AuthBigButtonStyle())
                    .disabled(filming)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    @ViewBuilder private var picture: some View {
        switch index {
        case 0: HowFindPicture(places: Self.samples(store))
        case 1: HowCheckInPicture(place: Self.samples(store)[0], filming: filming, filmed: filmed, record: film)
        default: HowEarnPicture()
        }
    }

    /// Find, Check in, Earn: three pills in a row with the current one lit.
    private var stepper: some View {
        HStack(spacing: 6) {
            ForEach(Array(Self.moves.enumerated()), id: \.offset) { i, name in
                if i > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                }
                HStack(spacing: 5) {
                    if i < index {
                        Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy))
                    } else {
                        Text("\(i + 1)").font(.system(size: 11, weight: .heavy)).monospacedDigit()
                    }
                    Text(name).font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(i == index ? Palette.ink : .white.opacity(i < index ? 0.9 : 0.45))
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(i == index ? Color.white : Color.white.opacity(0.12), in: Capsule())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(index + 1) of 3: \(Self.moves[index])")
    }

    private var title: String {
        switch index {
        case 0: return "Find a place you'll love"
        case 1: return "Go there and check in"
        default: return "Get rewarded"
        }
    }

    private var sub: String {
        switch index {
        case 0: return "Every day Odyssey picks an adventure near you."
        case 1: return "Film a quick look around. That is your proof you were there."
        default: return "Coins, a daily streak and ranks. Be first at a place and your name stays on it."
        }
    }

    private var button: String {
        switch index {
        case 0: return "Next"
        case 1: return filming ? "Checking in…" : "Try a check-in"
        default: return "I'm in"
        }
    }

    private func press() {
        Haptics.tap()
        if index == 1 && !filmed { film() } else { next() }
    }

    /// A pretend check-in: the ring fills, the place is yours, on to the rewards.
    private func film() {
        guard !filming, !filmed else { return }
        Haptics.tap()
        withAnimation(.linear(duration: 1.5)) { filming = true }
        Task {
            for _ in 0..<3 {
                try? await Task.sleep(for: .milliseconds(420))
                Haptics.soft()
            }
            try? await Task.sleep(for: .milliseconds(260))
            Haptics.success()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { filmed = true }
            try? await Task.sleep(for: .milliseconds(650))
            next()
        }
    }

    /// Three good looking places for the pictures, in the explorer's demo area when it has them.
    static func samples(_ store: AppStore) -> [Place] {
        let wanted = ["crane-cove", "piccino", "indian-rock", "strada", "bampfa"]
        let found = wanted.compactMap { id in store.seed.places.first { $0.id == id } }
        return Array((found + store.seed.places).prefix(3))
    }
}

// MARK: Pictures

/// A small deck of place cards. The top one leaves every couple of seconds.
private struct HowFindPicture: View {
    @Environment(AppStore.self) private var store
    var places: [Place]
    @State private var front = 0
    @State private var leaving: Int?
    @State private var shown = false

    var body: some View {
        ZStack {
            ForEach(Array(places.enumerated()), id: \.element.id) { i, place in
                let depth = (i - front + places.count) % places.count
                let gone = leaving == i
                card(place, top: depth == 0)
                    .scaleEffect(1 - CGFloat(depth) * 0.07)
                    .rotationEffect(.degrees(gone ? 16 : [-2.0, 5, -7][depth % 3]))
                    .offset(x: gone ? 300 : [0.0, 22, -22][depth % 3], y: gone ? -40 : CGFloat(depth) * 12)
                    .opacity(gone ? 0 : 1 - Double(depth) * 0.18)
                    .zIndex(Double(places.count - depth))
            }
        }
        .scaleEffect(shown ? 1 : 0.85)
        .opacity(shown ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) { shown = true }
        }
        .task {
            guard places.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1900))
                if Task.isCancelled { return }
                let top = front
                withAnimation(.easeIn(duration: 0.3)) { leaving = top }
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    front = (top + 1) % places.count
                    leaving = nil
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func card(_ place: Place, top: Bool) -> some View {
        ZStack(alignment: .bottomLeading) {
            PlacePhoto(place: place)
            LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.system(size: 19, weight: .heavy))
                    .tracking(-0.4)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(store.placeKind(place).label)
                    HStack(spacing: 3) {
                        CoinIcon(size: 13)
                        Text("+\(Rewards.checkIn.coins)").monospacedDigit()
                    }
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
            }
            .padding(14)
        }
        .overlay(alignment: .topLeading) {
            if top {
                Tag(text: "Today's Adventure", icon: "sparkle", tone: .dark).padding(10)
            }
        }
        .frame(width: 214, height: 276)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 22, y: 14)
    }
}

/// A camera pointed at a place, with the record button the explorer presses.
private struct HowCheckInPicture: View {
    var place: Place
    var filming: Bool
    var filmed: Bool
    var record: () -> Void
    @State private var pulse = false
    @State private var shown = false

    var body: some View {
        VStack(spacing: -34) {
            ZStack {
                PlacePhoto(place: place)
                    .scaleEffect(filming ? 1.16 : 1.02)
                brackets
                if filmed {
                    Color.black.opacity(0.35)
                    Image(systemName: "checkmark")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 76, height: 76)
                        .background(Palette.success, in: Circle())
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
            }
            .overlay(alignment: .top) {
                HStack(spacing: 6) {
                    Circle().fill(filming && !filmed ? Color(hex: "#ff3b30") : .white.opacity(0.6)).frame(width: 8, height: 8)
                    Text(filmed ? "You were here" : place.name).lineLimit(1)
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 11)
                .frame(height: 26)
                .background(.black.opacity(0.5), in: Capsule())
                .padding(12)
            }
            .frame(width: 214, height: 276)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 22, y: 14)
            recordButton
        }
        .scaleEffect(shown ? 1 : 0.85)
        .opacity(shown ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) { shown = true }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private var recordButton: some View {
        Button(action: record) {
            ZStack {
                // The nudge: a ring that breathes until the button is pressed.
                Circle()
                    .stroke(.white.opacity(pulse ? 0 : 0.6), lineWidth: 3)
                    .scaleEffect(pulse ? 1.5 : 1)
                    .opacity(filming ? 0 : 1)
                Circle().fill(.white)
                Circle()
                    .trim(from: 0, to: filming ? 1 : 0)
                    .stroke(Color(hex: "#ff3b30"), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(2.5)
                RoundedRectangle(cornerRadius: filming ? 7 : 24, style: .continuous)
                    .fill(Color(hex: "#ff3b30"))
                    .padding(filming ? 23 : 11)
            }
            .frame(width: 70, height: 70)
            .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(PressStyle(scale: 0.9))
        .disabled(filming)
        .accessibilityLabel("Record a check-in")
    }

    /// Viewfinder corners.
    private var brackets: some View {
        GeometryReader { geo in
            let inset: CGFloat = 26, arm: CGFloat = 22
            Path { p in
                let r = CGRect(x: inset, y: inset + 22, width: geo.size.width - inset * 2, height: geo.size.height - inset * 2 - 44)
                for (x, y, dx, dy) in [(r.minX, r.minY, 1.0, 1.0), (r.maxX, r.minY, -1.0, 1.0),
                                       (r.minX, r.maxY, 1.0, -1.0), (r.maxX, r.maxY, -1.0, -1.0)] {
                    p.move(to: CGPoint(x: x + arm * dx, y: y))
                    p.addLine(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x, y: y + arm * dy))
                }
            }
            .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }
}

/// What a check-in pays: the coins count up, then streak, XP and first explorer land one by one.
private struct HowEarnPicture: View {
    @State private var shown = false
    @State private var chips = 0

    var body: some View {
        ZStack {
            ConfettiView(count: 60)
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Palette.gold.opacity(0.55), .clear], center: .center, startRadius: 10, endRadius: 110))
                        .frame(width: 220, height: 220)
                    VStack(spacing: 6) {
                        CoinIcon(size: 84)
                            .shadow(color: Palette.gold.opacity(0.6), radius: 18)
                        CountUpText(value: Rewards.checkIn.coins, duration: 1, prefix: "+")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                        Text("coins per check-in")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(height: 190)
                .scaleEffect(shown ? 1 : 0.5)
                .opacity(shown ? 1 : 0)
                HStack(spacing: 8) {
                    chip(0, "flame.fill", "Day 1 streak", Palette.flame)
                    chip(1, "bolt.fill", "+\(Rewards.checkIn.xp) XP", Palette.rare)
                }
                chip(2, "star.fill", "First explorer +\(Rewards.first.coins)", Palette.gold)
            }
        }
        .task {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) { shown = true }
            for i in 1...3 {
                try? await Task.sleep(for: .milliseconds(380))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { chips = i }
                Haptics.soft()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Plus \(Rewards.checkIn.coins) coins per check-in, a daily streak, XP and a first explorer bonus")
    }

    private func chip(_ i: Int, _ symbol: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 12, weight: .bold)).foregroundStyle(color)
            Text(text).font(.system(size: 13, weight: .bold))
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(.white.opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1))
        .scaleEffect(chips > i ? 1 : 0.5)
        .opacity(chips > i ? 1 : 0)
    }
}
