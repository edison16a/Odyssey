//
//  Motion.swift
//  Shared by the app and the widgets.
//
//  Continuous animations (Globie, frames, effects, banners) pause when the
//  screen they are on is not showing, such as a tab in the background or the
//  app under a full screen flow, and never run faster than 30 frames a
//  second. That keeps the phone cool and taps instant.
//

import Foundation
import SwiftUI

extension EnvironmentValues {
    /// True while the view is off screen; animated views stop their clocks.
    @Entry var animationsPaused: Bool = false
}

nonisolated enum OdysseyMotion {
    /// The schedule every continuous animation uses.
    static func schedule(paused: Bool) -> AnimationTimelineSchedule {
        .animation(minimumInterval: 1.0 / 30, paused: paused)
    }
}

/// Runs a repeating animation only while the screen is showing. A plain
/// repeatForever keeps ticking on tabs you are not looking at, which costs
/// frames on the one you are.
private struct LoopWhileShowing: ViewModifier {
    @Environment(\.animationsPaused) private var paused
    @Binding var flag: Bool
    var animation: Animation

    func body(content: Content) -> some View {
        content
            .onAppear { run(!paused) }
            .onChange(of: paused) { _, paused in run(!paused) }
    }

    private func run(_ on: Bool) {
        if on {
            withAnimation(animation.repeatForever(autoreverses: true)) { flag = true }
        } else {
            // A plain change replaces the repeating animation and holds still.
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) { flag = false }
        }
    }
}

extension View {
    /// Swing flag back and forth with this animation while the screen is showing.
    func loops(_ flag: Binding<Bool>, _ animation: Animation, enabled: Bool = true) -> some View {
        modifier(LoopWhileShowing(flag: enabled ? flag : .constant(false), animation: animation))
    }
}
