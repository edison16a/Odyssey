//
//  OnboardingFlowView.swift
//  Odyssey
//
//  The first run after signing in: a welcome, five quick questions that
//  seed what Odyssey thinks you will love, an honest ask for your location,
//  then connecting photos (and optionally Google and Yelp), watching your
//  taste gem get cut from them, meeting your first adventure, and the
//  opening moment that hands off to the app. The same backdrop
//  as sign in keeps playing underneath.
//  Ported from features/onboarding/welcome.js and question.js.
//

import Foundation
import SwiftUI

struct OnboardingFlowView: View {
    enum Step: Equatable { case welcome, question(Int), location, connect, compile, reveal, opening }

    @Environment(AppStore.self) private var store
    @State private var step: Step = .welcome
    @State private var answers: [String: Bool] = [:]
    /// Thumbnails from the photo library (or bundled place photos) that feed the gem animation.
    @State private var photos: [UIImage] = []
    @State private var scan = PhotoScan()

    var body: some View {
        ZStack {
            AuthBackdrop(dim: true)
            Group {
                switch step {
                case .welcome:
                    welcome
                case .question(let index):
                    OnboardingQuestionStep(
                        index: index,
                        back: { go(index == 0 ? .welcome : .question(index - 1)) },
                        answer: { yes in answer(index, yes) }
                    )
                    .id(index)
                case .location:
                    OnboardingLocationStep(done: { go(.connect) })
                case .connect:
                    OnboardingConnectStep(photos: $photos, scan: $scan, done: { go(.compile) })
                case .compile:
                    OnboardingCompileStep(photos: photos, scan: scan, done: { go(.reveal) })
                case .reveal:
                    OnboardingRevealStep(done: { go(.opening) })
                case .opening:
                    OnboardingOpeningStep()
                }
            }
            .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 24)), removal: .opacity))
        }
    }

    private func go(_ next: Step) {
        withAnimation(.spring(response: 0.46, dampingFraction: 0.9)) { step = next }
    }

    /// Answers are saved as interests the moment the last one lands.
    private func answer(_ index: Int, _ yes: Bool) {
        let questions = store.seed.questions
        answers[questions[index].id] = yes
        if index + 1 < questions.count {
            go(.question(index + 1))
        } else {
            let chosen = answers
            store.update { s in s.interests = chosen }
            go(.location)
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer()
            OdysseyMark(size: 52).padding(.bottom, 6)
            Text("Welcome to Odyssey").font(.system(size: 28, weight: .bold)).tracking(-0.8)
            Text("Odyssey helps you find places you'll love and rewards you for making them easier to explore.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.72))
            VStack(alignment: .leading, spacing: 10) {
                loopStep(1, "heart.fill", "Find places you'll love")
                loopStep(2, "video.fill", "Go there and film it")
                loopStep(3, "gift.fill", "Get rewarded for helping the next person")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(.white.opacity(0.16), lineWidth: 1))
            Text("First, five quick taps so we know what you like.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.bottom, 8)
            Button("Let's go") { go(.question(0)) }
                .buttonStyle(AuthBigButtonStyle())
            Button("Skip for now") { go(.location) }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

/// One question per screen with a big photo card and two answers.
private struct OnboardingQuestionStep: View {
    @Environment(AppStore.self) private var store
    var index: Int
    var back: () -> Void
    var answer: (Bool) -> Void
    @State private var shown = false

    var body: some View {
        let questions = store.seed.questions
        let q = questions[index]
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                IconButton(icon: "back", kind: .dark, label: "Back", action: back)
                HStack(spacing: 6) {
                    ForEach(0..<questions.count, id: \.self) { i in
                        Capsule().fill(.white.opacity(i <= index ? 1 : 0.22)).frame(height: 4)
                    }
                }
                Text("\(index + 1) of \(questions.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.7))
            }
            PhotoView(path: q.photo)
                .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    Image(systemName: Icon.symbol(q.icon))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 44, height: 44)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(16)
                }
                .shadow(color: .black.opacity(0.4), radius: 25, y: 20)
                .scaleEffect(shown ? 1 : 0.92)
                .opacity(shown ? 1 : 0)
            VStack(alignment: .leading, spacing: 6) {
                Text(q.prompt).font(.system(size: 26, weight: .bold)).tracking(-0.8)
                Text(q.sub).font(.system(size: 15)).foregroundStyle(.white.opacity(0.72))
            }
            HStack(spacing: 12) {
                Button("No") { Haptics.tap(); answer(false) }
                    .buttonStyle(OnboardingAnswerStyle(light: false))
                Button("Yes") { Haptics.tap(); answer(true) }
                    .buttonStyle(OnboardingAnswerStyle(light: true))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .onAppear {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.8)) { shown = true }
        }
    }
}

private struct OnboardingAnswerStyle: ButtonStyle {
    var light: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(light ? Palette.ink : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(light ? Color.white : Color.white.opacity(0.16), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }

}

/// One row of the find, film, get rewarded loop on the welcome screen.
private func loopStep(_ n: Int, _ icon: String, _ text: String) -> some View {
    HStack(spacing: 12) {
        Image(systemName: icon)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Palette.ink)
            .frame(width: 30, height: 30)
            .background(.white, in: Circle())
        Text(text).font(.system(size: 15, weight: .semibold))
    }
}
