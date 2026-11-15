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
