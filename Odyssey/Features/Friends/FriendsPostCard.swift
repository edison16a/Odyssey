//
//  FriendsPostCard.swift
//  Odyssey
//
//  A friend post: the place shot with a selfie inset, who and where, the
//  caption, a walkthrough tag when they recorded the inside, and the first
//  explorer credit when they were the first on Odyssey. Milestone and day
//  posts show a designed card instead of a photo. Also the small square
//  tile used in profile grids. Ported from post-card.js.
//

import Foundation
import SwiftUI

/// The picture part of a post: the designed card, or the photo with the selfie inset.
struct FriendsPostMedia: View {
    @Environment(AppStore.self) private var store
    var post: Post
    var tile = false
    var selfieSize = CGSize(width: 78, height: 104)
    var selfieInset: CGFloat = 12
    /// The story viewer drops the selfie below its header.
    var selfieTop: CGFloat? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            backdrop
            if !tile && post.milestone == nil && post.day == nil && hasSelfie {
                selfie
                    .frame(width: selfieSize.width, height: selfieSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: selfieSize.width > 90 ? 16 : 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: selfieSize.width > 90 ? 16 : 14, style: .continuous).strokeBorder(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
                    .padding(.leading, selfieInset)
                    .padding(.top, selfieTop ?? selfieInset)
            }
        }
    }

    @ViewBuilder private var backdrop: some View {
        if let milestone = post.milestone {
            FriendsMilestoneArt(post: post, milestone: milestone, tile: tile)
        } else if let day = post.day {
            FriendsDayArt(day: day, tile: tile)
        } else if post.by == "me" {
            UserPhotoView(file: post.photoFile, fallback: store.place(post.placeId)?.photo)
        } else {
            PhotoView(path: store.place(post.placeId)?.photo ?? "")
        }
    }

    private var hasSelfie: Bool { post.selfie != nil || post.selfieFile != nil }

    @ViewBuilder private var selfie: some View {
        if post.by == "me" {
            UserPhotoView(file: post.selfieFile, fallback: post.selfie ?? store.state.user.sampleSelfie)
        } else {
            PhotoView(path: post.selfie ?? "")
        }
    }
}

struct FriendsPostCard: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toast
    var post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            head.padding(.bottom, 10)
            Button {
                router.present(.story(personID: post.by, postID: post.id))
            } label: {
                Color.clear
                    .aspectRatio(4.0 / 5.0, contentMode: .fit)
                    .overlay { FriendsPostMedia(post: post) }
                    .overlay(alignment: .bottomLeading) { walkTag }
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                    .background(Palette.surface3, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            }
            .buttonStyle(PressStyle(scale: 0.99))
            foot
            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.ink2)
                    .padding(.horizontal, 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, Space.s5)
    }

    private var person: Person? { store.person(post.by) }
    private var placeName: String { store.place(post.placeId)?.name ?? "Somewhere new" }

    private var head: some View {
        HStack(spacing: 10) {
            Button { FriendsNav.person(post.by, router: router) } label: {
                HStack(spacing: 10) {
                    if let person { AvatarView(person: person, size: 36) }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(post.by == "me" ? "You" : (person?.name ?? "Explorer"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Palette.ink)
                        Text("\(placeName), \(Format.ago(post.minutesAgo))")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.muted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if post.first == true {
                Tag(text: "First explorer", icon: "star-fill", tone: .rare)
            }
        }
    }

    @ViewBuilder private var walkTag: some View {
        if post.kind == "walk" {
            HStack(spacing: 5) {
                Image(systemName: "video.fill").font(.system(size: 10, weight: .bold))
                Text("\(post.seconds ?? 30)s walkthrough").font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Palette.accent, in: Capsule())
            .padding(12)
        }
    }

    private var foot: some View {
        let liked = store.liked(post.id)
        return HStack(spacing: 14) {
            Button {
                Haptics.tap()
                store.toggleLike(post.id)
            } label: {
                action(liked ? "heart.fill" : "heart", "\(post.likes + (liked ? 1 : 0))")
                    .foregroundStyle(liked ? Palette.danger : Palette.ink)
            }
            .buttonStyle(PressStyle(scale: 0.9))
            Button { toast.show("Comments open in the full app", icon: "chat") } label: {
                action("bubble.left", "\(post.comments)").foregroundStyle(Palette.ink)
            }
            .buttonStyle(PressStyle(scale: 0.9))
            Spacer()
            Button { router.push(.place(post.placeId)) } label: {
                action("mappin", "View place").foregroundStyle(Palette.ink)
            }
            .buttonStyle(PressStyle())
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
        .padding(.horizontal, 2)
    }

    private func action(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 19))
            Text(text).font(.system(size: 13, weight: .semibold))
        }
    }
}
