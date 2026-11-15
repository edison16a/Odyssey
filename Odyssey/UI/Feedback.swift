//
//  Feedback.swift
//  Odyssey
//
//  Small pieces of feedback used everywhere: the thumbs pair that teaches
//  Odyssey your taste, toasts, haptics, a count up for reward numbers and a
//  burst of confetti.
//

import Foundation
import Observation
import SwiftUI
import UIKit

/// Thumbs up and down. Tapping the same thumb again clears the vote.
struct ThumbsView: View {
    @Environment(AppStore.self) private var store
    @Environment(ToastCenter.self) private var toast
    var place: Place
    var size: CGFloat = 17
    var dark = false

    var body: some View {
        let vote = store.voteOf(place)
        HStack(spacing: 6) {
            thumb("thumb-up", on: vote == 1, value: 1)
            thumb("thumb-down", on: vote == -1, value: -1)
        }
    }

    private func thumb(_ icon: String, on: Bool, value: Int) -> some View {
        Button {
            Haptics.tap()
            let result = store.vote(place, value)
            if result == 1 { toast.show("Odyssey will find more like this", icon: "thumb-up") }
            if result == -1 { toast.show("Got it, fewer like this", icon: "thumb-down") }
        } label: {
            Image(systemName: Icon.symbol(on ? icon + "-fill" : icon))
                .font(.system(size: size * 0.8, weight: .semibold))
                .frame(width: size * 1.9, height: size * 1.9)
                .foregroundStyle(on ? .white : (dark ? .white : Palette.ink))
                .background(on ? (value == 1 ? Palette.accent : Palette.ink) : (dark ? .white.opacity(0.18) : Palette.surface2), in: Circle())
        }
        .buttonStyle(PressStyle(scale: 0.88))
        .accessibilityLabel(value == 1 ? "More like this" : "Less like this")
    }
}

@Observable
final class ToastCenter {
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        var text: String
        var icon: String?
    }

    var current: Toast?
    @ObservationIgnored private var hideWork: DispatchWorkItem?

    func show(_ text: String, icon: String? = nil) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { current = Toast(text: text, icon: icon) }
        hideWork?.cancel()
        // A work item's block is not main actor isolated, but it runs on the main queue.
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                withAnimation(.easeOut(duration: 0.25)) { self?.current = nil }
            }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: work)
    }
}

/// The black pill toasts slide in from the top.
struct ToastOverlay: View {
    @Environment(ToastCenter.self) private var center

    var body: some View {
        VStack {
            if let toast = center.current {
                HStack(spacing: 8) {
                    if let icon = toast.icon {
                        Image(systemName: Icon.symbol(icon)).font(.system(size: 14, weight: .semibold))
                    }
                    Text(toast.text).font(.system(size: 14, weight: .semibold)).lineLimit(2)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Palette.ink, in: Capsule())
                .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(toast.id)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .allowsHitTesting(false)
    }
}

/// Haptics reuse prepared generators, so a tap never waits for the engine to start.
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let softer = UIImpactFeedbackGenerator(style: .soft)
    private static let strong = UIImpactFeedbackGenerator(style: .heavy)
    private static let notice = UINotificationFeedbackGenerator()

    static func tap() { light.impactOccurred(); light.prepare() }
    static func soft() { softer.impactOccurred(); softer.prepare() }
    static func heavy() { strong.impactOccurred(); strong.prepare() }
    static func success() { notice.notificationOccurred(.success); notice.prepare() }
    static func warning() { notice.notificationOccurred(.warning); notice.prepare() }
}

/// A number that counts up from a start value when it appears.
struct CountUpText: View {
    var value: Int
    var from: Int = 0
    var duration: Double = 0.9
    var prefix = ""
    var suffix = ""
    @State private var shown: Double = 0

    var body: some View {
        Text(prefix + Format.number(shown) + suffix)
            .monospacedDigit()
            .contentTransition(.numericText(value: shown))
            .onAppear {
                shown = Double(from)
                withAnimation(.easeOut(duration: duration)) { shown = Double(value) }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(.easeOut(duration: duration)) { shown = Double(newValue) }
            }
    }
}

/// A short burst of paper confetti, flat colors from the palette.
struct ConfettiView: View {
    struct Piece { var spread: Double; var vx: Double; var vy: Double; var spin: Double }

    /// Each piece's path, worked out once instead of every frame.
    private static var cache: [Int: [Piece]] = [:]
    static func pieces(_ count: Int) -> [Piece] {
        if let hit = cache[count] { return hit }
        let made = (0..<count).map { i -> Piece in
            let rand = StableHash.generator("confetti\(i)")
            return Piece(spread: 0.2 + rand() * 0.6, vx: (rand() - 0.5) * 420, vy: -380 - rand() * 360, spin: rand() * 8 - 4)
        }
        cache[count] = made
        return made
    }

    var count = 70
    @State private var start = Date()
    /// Once the burst has fallen, the clock stops and the view draws nothing.
    @State private var finished = false
    private let colors: [Color] = [Palette.accent, Palette.gold, Palette.flame, Palette.success, Palette.rare, .white]

    var body: some View {
        TimelineView(OdysseyMotion.schedule(paused: finished)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                guard t < 3.2 else { return }
                for (i, piece0) in ConfettiView.pieces(count).enumerated() {
                    let x: Double = Double(size.width) * piece0.spread + piece0.vx * t
                    let fall: Double = piece0.vy * t + 520 * t * t
                    let y: Double = Double(size.height) * 0.35 + fall
                    let spin: Double = piece0.spin * t
                    var piece = context
                    piece.opacity = max(0, 1 - t / 3.2)
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .radians(spin))
                    piece.fill(Path(roundedRect: CGRect(x: -4, y: -2.5, width: 8, height: 5), cornerRadius: 1.2),
                               with: .color(colors[i % colors.count]))
                }
            }
        }
        .allowsHitTesting(false)
        .opacity(finished ? 0 : 1)
        .onAppear { start = Date() }
        .task {
            try? await Task.sleep(for: .seconds(3.3))
            finished = true
        }
    }
}
