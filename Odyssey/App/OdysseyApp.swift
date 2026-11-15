//
//  OdysseyApp.swift
//  Odyssey
//
//  Go Explore. Get Rewarded.
//
//  Builds the shared objects (state, navigation, location, toasts), hands
//  them to every screen through the environment, and routes odyssey:// links
//  from the widgets and the Live Activity.
//

import Foundation
import SwiftUI
import UIKit

@main
struct OdysseyApp: App {
    @State private var store = AppStore()
    @State private var router = AppRouter()
    @State private var location = LocationService()
    @State private var toast = ToastCenter()
    @State private var rewardPop = RewardPopCenter()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
                .environment(location)
                .environment(toast)
                .environment(rewardPop)
                .preferredColorScheme(.light)
                .tint(Palette.ink)
                .onAppear {
                    location.attach(store)
                    WidgetBridge.publish(from: store)
                }
                .onOpenURL { router.open($0, store: store) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background {
                        location.flushSteps()
                        store.flush()
                        WidgetBridge.publish(from: store)
                    }
                }
        }
    }
}

/// Signed out, or the app with onboarding over it until it is done, behind the
/// loading screen at launch.
struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var loading = true

    var body: some View {
        ZStack {
            Palette.surface.ignoresSafeArea()
            if !store.state.session.signedIn {
                AuthFlowView()
                    .transition(.opacity)
            } else {
                // The app is built as soon as you are signed in. Onboarding sits on top of it,
                // so by the time you answer the last question the map and tabs are ready.
                let onboarding = !store.state.session.onboarded
                MainShell()
                    .environment(\.animationsPaused, onboarding)
                    .allowsHitTesting(!onboarding)
                    .accessibilityHidden(onboarding)
                    .transition(.opacity)
                if onboarding {
                    OnboardingFlowView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            RewardPopOverlay()
            ToastOverlay()
            if loading {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .task { await finishLoading() }
        .animation(.easeInOut(duration: 0.35), value: store.state.session.signedIn)
        .animation(.easeInOut(duration: 0.35), value: store.state.session.onboarded)
    }
}

extension RootView {
    /// Build the map layer while the logo shows, staying up at least long enough to read
    /// and never longer than a few seconds, so a slow phone still gets in.
    private func finishLoading() async {
        let start = Date()
        if store.state.session.signedIn {
            let key = HomeExploredLayer.signature(store)
            HomeExploredLayer.prewarm(store)
            while !HomeExploredLayer.isReady(key), Date().timeIntervalSince(start) < 3 {
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        let shown = Date().timeIntervalSince(start)
        if shown < 1.3 { try? await Task.sleep(for: .seconds(1.3 - shown)) }
        withAnimation(.easeOut(duration: 0.45)) { loading = false }
    }
}

/// Our screens draw their own headers, so the system bar is hidden. This keeps
/// the edge swipe back gesture working anyway.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
