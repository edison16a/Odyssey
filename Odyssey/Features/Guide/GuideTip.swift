//
//  GuideTip.swift
//  Odyssey
//
//  A one-line hint that floats above a control the first time a new
//  explorer meets it, bobbing a little so it gets noticed. It never blocks
//  the control: use the control, tap the hint or just wait, and it is gone
//  for good.
//

import Foundation
import SwiftUI

extension View {
    /// Float a one-time hint above this view while the guide is on.
    func guideTip(_ key: String, _ text: String, icon: String = "hand.tap.fill", when wanted: Bool = true) -> some View {
        modifier(GuideTipModifier(key: key, text: text, icon: icon, wanted: wanted))
    }
}

private struct GuideTipModifier: ViewModifier {
    @Environment(AppStore.self) private var store
    var key: String
    var text: String
    var icon: String
    var wanted: Bool
    @State private var shown = false
    @State private var bob = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if shown {
                    Button(action: dismiss) { label }
                        .buttonStyle(.plain)
                        // Lifted clear of the control, pointer and all.
                        .offset(y: -GuideTipModifier.height - 12 + (bob ? -3 : 3))
                        .transition(.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
                }
            }
            .task {
                guard wanted, store.tipWanted(key) else { return }
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) { shown = true }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { bob = true }
                // Seen once is enough, even if the screen is left with the hint still up.
                store.tipSeen(key)
                try? await Task.sleep(for: .seconds(7))
                guard !Task.isCancelled else { return }
                dismiss()
            }
    }

    private var label: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12, weight: .bold))
            Text(text).font(.system(size: 13, weight: .bold)).lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(height: GuideTipModifier.height)
        .background(Palette.ink, in: Capsule())
        .background(alignment: .bottom) {
            Rectangle().fill(Palette.ink).frame(width: 12, height: 12).rotationEffect(.degrees(45)).offset(y: 5)
        }
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        .fixedSize()
    }

    private static let height: CGFloat = 34

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) { shown = false }
    }
}
