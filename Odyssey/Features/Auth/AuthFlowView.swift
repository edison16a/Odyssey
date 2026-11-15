//
//  AuthFlowView.swift
//  Odyssey
//
//  The signed out stage. The landing montage keeps playing while the
//  foreground steps change: landing, email and the one time code. Keeping
//  the video mounted is what makes signing in feel like one continuous
//  moment. Ported from features/auth/auth-stage.js and landing.js.
//

import Foundation
import SwiftUI

struct AuthFlowView: View {
    enum Step { case landing, email, otp }

    @Environment(AppStore.self) private var store

    @State private var step: Step = .landing
    @State private var returning = false
    @State private var email = ""

    var body: some View {
        ZStack {
            AuthBackdrop(dim: step != .landing)
            Group {
                switch step {
                case .landing:
                    AuthLanding(
                        start: { returning = false; go(.email) },
                        skip: skipToOnboarding
                    )
                case .email:
                    AuthEmailStep(email: $email, returning: returning, back: { go(.landing) }, send: { go(.otp) })
                case .otp:
                    AuthOTPStep(email: email, back: { go(.email) })
                }
            }
            .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 24)), removal: .opacity))
        }
    }

    /// Skip the email and code and go straight to onboarding.
    private func skipToOnboarding() {
        Haptics.tap()
        store.update { s in s.session.signedIn = true }
    }

    private func go(_ next: Step) {
        withAnimation(.spring(response: 0.46, dampingFraction: 0.9)) { step = next }
    }
}

/// The landing montage playing silently on a loop, with its poster frame
/// underneath until the first frame shows (or if playback is refused), and
/// a shade: light at the top, near black at the bottom so the logo always reads.
struct AuthBackdrop: View {
    var dim = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                PhotoView(path: "assets/media/video/landing-poster.jpg", placeholder: .black)
                    .frame(width: geo.size.width, height: geo.size.height)
                LoopingVideoView(resource: "landing-montage")
                    .frame(width: geo.size.width, height: geo.size.height)
                LinearGradient(stops: shade, startPoint: .top, endPoint: .bottom)
                    .animation(.easeInOut(duration: 0.46), value: dim)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// Darker all over once a step is open, so the form reads.
    private var shade: [Gradient.Stop] {
        if dim {
            return [
                Gradient.Stop(color: Color.black.opacity(0.35), location: 0),
                Gradient.Stop(color: Color.black.opacity(0.6), location: 0.45),
                Gradient.Stop(color: Color.black.opacity(0.92), location: 1),
            ]
        }
        return [
            Gradient.Stop(color: Color.black.opacity(0.05), location: 0),
            Gradient.Stop(color: Color.black.opacity(0.25), location: 0.38),
            Gradient.Stop(color: Color.black.opacity(0.82), location: 0.72),
            Gradient.Stop(color: Color.black, location: 1),
        ]
    }
}

/// Logo, motto and the one call to action.
private struct AuthLanding: View {
    var start: () -> Void
    var skip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 14) {
                OdysseyMark(size: 58)
                OdysseyWordmark(size: 42)
            }
            .padding(.bottom, 18)
            Text(Brand.motto)
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.2)
            Text(Brand.tagline + " Discover places you will love, explore with friends and get rewarded for every discovery.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .padding(.top, 10)
                .padding(.bottom, 34)
            VStack(spacing: 14) {
                Button("Start your adventure", action: start)
                    .buttonStyle(AuthBigButtonStyle())
                Button("Skip", action: skip)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
        .padding(.bottom, 34)
    }
}

/// The tall white pill used on the signed out screens.
struct AuthBigButtonStyle: ButtonStyle {
    var light = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(light ? Palette.ink : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(light ? Color.white : Color.white.opacity(0.16), in: Capsule())
            .opacity(isEnabled ? 1 : 0.35)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
