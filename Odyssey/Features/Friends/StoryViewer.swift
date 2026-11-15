//
//  StoryViewer.swift
//  Odyssey
//
//  Full screen story viewer. Plays each friend's posts in order with
//  progress bars, then rolls into the next friend. Tap the right side to
//  skip, the left side to go back, hold to pause, swipe down to close.
//  Opening a single post (from a notification or the feed) plays just that
//  post. Ported from story-viewer.js.
//

import Combine
import Foundation
import SwiftUI

struct StoryViewer: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var startPersonID: String
    var postID: String?

    private struct Frame {
        var person: String
        var post: Post
    }

    @State private var frames: [Frame] = []
    @State private var index = 0
    @State private var progress: Double = 0
    @State private var paused = false
    @State private var dragY: CGFloat = 0

    /// Each story plays for five seconds.
    private let duration = 5.0
    private let ticker = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if index < frames.count {
                content(frames[index])
            }
        }
        .offset(y: dragY)
        .opacity(1 - Double(dragY / 600))
        .simultaneousGesture(closeGesture)
        .statusBarHidden()
        .onAppear(perform: build)
        .onReceive(ticker) { _ in tick() }
        .onChange(of: index) { _, _ in markSeen() }
    }

    private func content(_ frame: Frame) -> some View {
        ZStack {
            media(frame)
            tapZones
            VStack(spacing: 0) {
                bars
                top(frame)
                Spacer()
                FriendsStoryCaption(post: frame.post)
                FriendsStoryBar(post: frame.post, paused: $paused) { openPlace(frame.post.placeId) }
            }
        }
    }

    private func media(_ frame: Frame) -> some View {
        Color.clear
            .overlay {
                FriendsPostMedia(post: frame.post, selfieSize: CGSize(width: 96, height: 128), selfieInset: 16, selfieTop: 118)
            }
            .overlay {
                LinearGradient(stops: [
                    .init(color: .black.opacity(0.5), location: 0),
                    .init(color: .clear, location: 0.22),
                    .init(color: .clear, location: 0.55),
                    .init(color: .black.opacity(0.75), location: 1),
                ], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()
            .id(frame.post.id)
            .transition(.opacity)
    }

    private var bars: some View {
        HStack(spacing: 4) {
            ForEach(frames.indices, id: \.self) { i in
                ProgressBar(value: i < index ? 1 : i == index ? progress : 0, color: .white,
                            track: .white.opacity(0.35), height: 3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private func top(_ frame: Frame) -> some View {
        let who = store.person(frame.person)
        let place = store.place(frame.post.placeId)?.name ?? "Somewhere new"
        return HStack(spacing: 10) {
            if let who { AvatarView(person: who, size: 34) }
            VStack(alignment: .leading, spacing: 1) {
                Text(frame.person == "me" ? "Your adventure" : (who?.name ?? "Explorer"))
                    .font(.system(size: 13, weight: .bold))
                Text("\(place), \(Format.ago(frame.post.minutesAgo))")
                    .font(.system(size: 11))
                    .opacity(0.75)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            IconButton(icon: "close", kind: .dark, label: "Close") { close() }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }

    /// Left 40 percent goes back, the rest skips ahead; holding pauses.
    private var tapZones: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                zone(width: geo.size.width * 0.4) { previous() }
                zone(width: geo.size.width * 0.6) { next() }
            }
        }
        .padding(.top, 110)
        .padding(.bottom, 100)
    }

    private func zone(width: CGFloat, action: @escaping () -> Void) -> some View {
        Color.clear
            .frame(width: width)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .onLongPressGesture(minimumDuration: 0.2, perform: {}, onPressingChanged: { pressing in paused = pressing })
    }

    private var closeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                if value.translation.height > 0 {
                    dragY = value.translation.height
                    paused = true
                }
            }
            .onEnded { value in
                if value.translation.height > 120 {
                    close()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dragY = 0 }
                    paused = false
                }
            }
    }

    // MARK: Playback

    /// Build the play queue as a flat list of person and post frames.
    private func build() {
        if let postID, let post = store.post(postID) {
            frames = [Frame(person: post.by, post: post)]
        } else {
            let people = startPersonID == "me" ? ["me"] : store.storyPeople
            let start = max(0, people.firstIndex(of: startPersonID) ?? 0)
            frames = people.dropFirst(start).flatMap { id in
                store.posts(by: id).reversed().map { Frame(person: id, post: $0) }
            }
        }
        if frames.isEmpty {
            close()
        } else {
            markSeen()
        }
    }

    private func markSeen() {
        guard index < frames.count, frames[index].person != "me" else { return }
        store.markSeen(frames[index].person)
    }

    private func tick() {
        guard !paused, !frames.isEmpty else { return }
        progress += 0.05 / duration
        if progress >= 1 { next() }
    }

    private func next() {
        if index < frames.count - 1 {
            progress = 0
            withAnimation(.easeOut(duration: 0.2)) { index += 1 }
        } else {
            close()
        }
    }

    private func previous() {
        progress = 0
        withAnimation(.easeOut(duration: 0.2)) { index = max(0, index - 1) }
    }

    private func close() {
        paused = true
        router.dismissCover()
    }

    private func openPlace(_ id: String) {
        close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.push(.place(id)) }
    }
}
