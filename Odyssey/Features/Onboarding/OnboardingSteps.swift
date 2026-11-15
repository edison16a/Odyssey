//
//  OnboardingSteps.swift
//  Odyssey
//
//  The location and closing onboarding steps. First an honest card about location:
//  what Odyssey uses it for and what it never does, with the system prompt
//  behind one button. Then the opening moment from the mockup: a short
//  checklist runs while the mark grows, the app takes over, and the guide
//  starts its tour.
//

import Foundation
import CoreLocation
import SwiftUI

struct OnboardingLocationStep: View {
    @Environment(LocationService.self) private var location
    var done: () -> Void
    @State private var asked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer()
            Image(systemName: "location.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: 56, height: 56)
                .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.bottom, 6)
            Text("Adventures near you").font(.system(size: 28, weight: .bold)).tracking(-0.8)
            Text("Odyssey needs to know where you are to find them.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.72))
            VStack(alignment: .leading, spacing: 10) {
                point("map", "Shows places around you")
                point("camera", "Proves your check-ins")
                point("lock.fill", "Private unless you post")
            }
            .padding(16)
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(.white.opacity(0.16), lineWidth: 1))
            .padding(.vertical, 8)
            Button(location.isAuthorized ? "Continue" : "Allow location") {
                if location.isAuthorized || location.isDenied {
                    done()
                } else {
                    asked = true
                    location.request()
                }
            }
            .buttonStyle(AuthBigButtonStyle())
            Button("Not now", action: done)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .onChange(of: location.authorization) { _, status in
            if asked && status != .notDetermined { done() }
        }
    }

    private func point(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).frame(width: 22)
            Text(text).font(.system(size: 15))
        }
    }
}

struct OnboardingOpeningStep: View {
    @Environment(AppStore.self) private var store
    @State private var done = 0
    @State private var appeared = false
    @State private var bounce = false
    @State private var leaving = false

    private let lines = ["Saving your taste gem", "Pinning your first adventure", "Lining up your first steps"]

    var body: some View {
        VStack(spacing: 18) {
            OdysseyMark(size: 72)
                .scaleEffect(appeared ? 1 : 0.6)
                .offset(y: bounce ? -6 : 0)
                .opacity(appeared ? 1 : 0)
            OdysseyWordmark(size: 34)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().strokeBorder(.white.opacity(i < done ? 0 : 0.35), lineWidth: 1.5)
                            Circle().fill(.white).opacity(i < done ? 1 : 0)
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.black).opacity(i < done ? 1 : 0)
                        }
                        .frame(width: 22, height: 22)
                        Text(line).font(.system(size: 15)).foregroundStyle(.white.opacity(i < done ? 1 : 0.45))
                    }
                }
            }
            .padding(.top, 26)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(leaving ? 0 : 1)
        .scaleEffect(leaving ? 1.06 : 1)
        .task { await run() }
    }

    private func run() async {
        // The home map's explored layer builds in the background while this plays.
        HomeExploredLayer.prewarm(store)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { appeared = true }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.5)) { bounce = true }
        for i in 1...lines.count {
            try? await Task.sleep(for: .milliseconds(240))
            withAnimation(.easeOut(duration: 0.2)) { done = i }
            Haptics.soft()
        }
        try? await Task.sleep(for: .milliseconds(250))
        withAnimation(.easeOut(duration: 0.3)) { leaving = true }
        try? await Task.sleep(for: .milliseconds(280))
        // The guide takes over inside the app: a short tour, then the first steps on Home.
        store.beginGuide()
        store.update { s in s.session.onboarded = true }
    }
}
