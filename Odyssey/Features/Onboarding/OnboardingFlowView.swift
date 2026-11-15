//
//  OnboardingFlowView.swift
//  Odyssey
//
//  The first run after signing in. It starts by saying what Odyssey is:
//  Globie says hello, then the app in three moves (find a place, check in,
//  get rewarded), with a check-in to try on the spot. Only then does it
//  ask for things: five quick taste questions, your location, and your
//  photos (and optionally Google and Yelp), which get cut into your taste
//  gem. It ends on your first adventure and hands off to the app, where
//  the guide in Features/Guide carries on with spotlights and first steps.
//  One progress bar runs along the top the whole way, and the same
//  backdrop as sign in keeps playing underneath.
//

import Foundation
import SwiftUI

struct OnboardingFlowView: View {
    enum Step: Equatable { case hello, how(Int), question(Int), location, connect, compile, reveal, opening }

    @Environment(AppStore.self) private var store
    @State private var step: Step = .hello
    @State private var answers: [String: Bool] = [:]
    /// Thumbnails from the photo library (or bundled place photos) that feed the gem animation.
    @State private var photos: [UIImage] = []
    @State private var scan = PhotoScan()

    private static let moves = 3

    var body: some View {
        ZStack {
            AuthBackdrop(dim: true)
            VStack(spacing: 0) {
                if let progress {
                    topBar(progress)
                        .transition(.opacity)
                }
                Group {
                    switch step {
                    case .hello:
                        OnboardingHelloStep(start: { go(.how(0)) }, skip: { go(.question(0)) })
                    case .how(let index):
                        OnboardingHowStep(index: index, next: { go(index + 1 < Self.moves ? .how(index + 1) : .question(0)) })
                            .id(index)
                    case .question(let index):
                        OnboardingQuestionStep(index: index, answer: { yes in answer(index, yes) })
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 24)), removal: .opacity))
            }
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

    // MARK: Progress

    /// How far along the flow is, 0...1. Nil on the screens that play by themselves.
    private var progress: Double? {
        let questions = store.seed.questions.count
        let total = Double(Self.moves + questions + 2)
        switch step {
        case .how(let i): return Double(i + 1) / total
        case .question(let i): return Double(Self.moves + i + 1) / total
        case .location: return Double(Self.moves + questions + 1) / total
        case .connect: return 1
        default: return nil
        }
    }

    private var previous: Step {
        let questions = store.seed.questions.count
        switch step {
        case .how(let i): return i == 0 ? .hello : .how(i - 1)
        case .question(let i): return i == 0 ? .how(Self.moves - 1) : .question(i - 1)
        case .location: return questions > 0 ? .question(questions - 1) : .how(Self.moves - 1)
        case .connect: return .location
        default: return .hello
        }
    }

    private var isQuestion: Bool {
        if case .question = step { return true }
        return false
    }

    /// Back, the bar, and a way past the questions.
    private func topBar(_ value: Double) -> some View {
        HStack(spacing: 14) {
            IconButton(icon: "back", kind: .dark, label: "Back") { go(previous) }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.22))
                    Capsule().fill(.white).frame(width: max(8, geo.size.width * value))
                }
            }
            .frame(height: 8)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: value)
            .accessibilityLabel("Progress")
            .accessibilityValue("\(Int(value * 100)) percent")
            Button("Skip") { go(.location) }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .opacity(isQuestion ? 1 : 0)
                .disabled(!isQuestion)
                .accessibilityHidden(!isQuestion)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

/// One question per screen with a big photo card and two answers.
private struct OnboardingQuestionStep: View {
    @Environment(AppStore.self) private var store
    var index: Int
    var answer: (Bool) -> Void
    @State private var shown = false

    var body: some View {
        let questions = store.seed.questions
        let q = questions[index]
        VStack(alignment: .leading, spacing: 20) {
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
                Text("YOUR TASTE · \(index + 1) OF \(questions.count)")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.6))
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
