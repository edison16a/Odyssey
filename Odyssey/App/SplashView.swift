//
//  SplashView.swift
//  Odyssey
//
//  The loading screen. The system launch screen is black with the logo in
//  the middle; this picks up from exactly that frame, so the logo never
//  jumps, then brings in the name and "Loading your adventures" while the
//  map and your places get ready underneath.
//

import Foundation
import SwiftUI

struct SplashView: View {
    /// Matches the logo size on the system launch screen.
    static let logoSize: CGFloat = 140

    @State private var showText = false
    @State private var breathe = false
    @State private var dot = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            OdysseyMark(size: Self.logoSize)
                .scaleEffect(breathe ? 1.04 : 1)
            VStack(spacing: 10) {
                OdysseyWordmark(size: 34)
                Text("Loading your adventures" + String(repeating: ".", count: dot))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(width: 240)
            }
            .offset(y: Self.logoSize / 2 + 58)
            .opacity(showText ? 1 : 0)
            .offset(y: showText ? 0 : 10)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.15)) { showText = true }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { breathe = true }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(420))
                dot = (dot + 1) % 4
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Odyssey. Loading your adventures")
    }
}
