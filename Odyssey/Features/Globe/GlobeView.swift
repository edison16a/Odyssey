//
//  GlobeView.swift
//  Odyssey
//
//  The Odyssey Globe player. Plays the recap slides with progress bars,
//  advancing every 4.5 seconds; tap right to skip, left to go back. The
//  last slide waits for you and offers Share and Replay.
//  Ported from features/globe/globe.js and globe.css.
//

import Foundation
import SwiftUI

struct GlobeView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var index = 0
    @State private var progress: Double = 0
    @State private var timer: Task<Void, Never>?

    private static let duration = 4.5
    private let slides = GlobeSlide.allCases

    var body: some View {
        let slide = slides[index]
        let ink: Color = slide.ink ? Palette.ink : .white
        ZStack(alignment: .top) {
            slide.background(store).ignoresSafeArea()
                .animation(.easeInOut(duration: 0.46), value: index)
            GlobeSlideView(slide: slide, replay: replay)
                .id(index)
                .padding(.top, 110)
                .padding(.horizontal, 28)
                .padding(.bottom, 60)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if !slide.final {
                HStack(spacing: 0) {
                    Color.clear.contentShape(Rectangle()).frame(maxWidth: .infinity).onTapGesture { go(index - 1) }
                    Spacer().frame(maxWidth: .infinity)
                    Color.clear.contentShape(Rectangle()).frame(maxWidth: .infinity).onTapGesture { go(index + 1) }
                }
                .padding(.top, 110)
                .padding(.bottom, 100)
            }
            bars(ink: slide.ink)
            HStack {
                Spacer()
                IconButton(icon: "close", kind: .dark, label: "Close") { router.dismissCover() }
            }
            .padding(.trailing, 14)
            .padding(.top, 26)
        }
        .foregroundStyle(ink)
        .onAppear { start() }
        .onDisappear { timer?.cancel() }
    }

    private func bars(ink: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(slides.indices, id: \.self) { i in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(ink ? Color.black.opacity(0.15) : Color.white.opacity(0.35))
                        Capsule().fill(ink ? Palette.ink : Color.white)
                            .frame(width: geo.size.width * fill(i))
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private func fill(_ i: Int) -> CGFloat {
        if i < index { return 1 }
        if i == index { return slides[i].final ? 1 : CGFloat(progress) }
        return 0
    }

    private func go(_ next: Int) {
        index = max(0, min(slides.count - 1, next))
        start()
    }

    private func replay() { go(0) }

    /// Fill the current bar over 4.5 seconds, then move on unless it is the last slide.
    private func start() {
        timer?.cancel()
        progress = 0
        guard !slides[index].final else { return }
        let current = index
        timer = Task {
            // Let the empty bar draw first. Setting 0 then animating to 1 in the same update is no change
            // from the last slide's 1, so every bar after the first showed up already full.
            try? await Task.sleep(for: .milliseconds(30))
            guard !Task.isCancelled, index == current else { return }
            withAnimation(.linear(duration: GlobeView.duration)) { progress = 1 }
            try? await Task.sleep(for: .seconds(GlobeView.duration))
            guard !Task.isCancelled, index == current else { return }
            go(current + 1)
        }
    }
}
