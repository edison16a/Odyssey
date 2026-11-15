//
//  FriendsStoryBar.swift
//  Odyssey
//
//  The parts of a story that sit over the photo: the walkthrough and first
//  explorer tags with the caption, and the reply field with like and open
//  place buttons along the bottom. Typing a reply pauses the story.
//

import Foundation
import SwiftUI

struct FriendsStoryCaption: View {
    var post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if post.kind == "walk" { Tag(text: "\(post.seconds ?? 30)s walkthrough", icon: "video", tone: .accent) }
                if post.first == true { Tag(text: "First explorer", icon: "star-fill", tone: .rare) }
            }
            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .allowsHitTesting(false)
    }
}

struct FriendsStoryBar: View {
    @Environment(AppStore.self) private var store
    @Environment(ToastCenter.self) private var toast

    var post: Post
    @Binding var paused: Bool
    var onPlace: () -> Void

    @State private var reply = ""
    @FocusState private var typing: Bool

    var body: some View {
        let liked = store.liked(post.id)
        HStack(spacing: 8) {
            TextField("", text: $reply, prompt: Text("Send a message").foregroundColor(.white.opacity(0.7)))
                .focused($typing)
                .foregroundStyle(.white)
                .submitLabel(.send)
                .onSubmit(send)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .overlay(Capsule().strokeBorder(.white.opacity(0.6), lineWidth: 1.5))
                .onChange(of: typing) { _, focused in paused = focused }
            Button {
                let on = store.toggleLike(post.id)
                Haptics.tap()
                if on { toast.show("Liked", icon: "heart") }
            } label: {
                Image(systemName: liked ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(liked ? Palette.danger : .white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.45), in: Circle())
            }
            .buttonStyle(PressStyle(scale: 0.9))
            .accessibilityLabel("Like")
            IconButton(icon: "pin", kind: .dark, size: 44, label: "Open place", action: onPlace)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

    private func send() {
        guard !reply.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        reply = ""
        typing = false
        toast.show("Message sent", icon: "send")
    }
}
