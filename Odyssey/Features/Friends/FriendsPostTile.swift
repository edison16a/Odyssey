//
//  FriendsPostTile.swift
//  Odyssey
//
//  The small square post tile for profile grids, and the one place that
//  decides how a person opens: friends get their page, you get your tab.
//

import Foundation
import SwiftUI

/// Opening people from anywhere in the social screens. You open your own tab.
enum FriendsNav {
    static func person(_ id: String, router: AppRouter) {
        if id == "me" {
            router.dismissCover()
            router.popToRoot()
            router.tab = .profile
            router.popToRoot()
        } else {
            router.push(.person(id))
        }
    }
}

/// Small square tile for profile grids.
struct FriendsPostTile: View {
    @Environment(AppRouter.self) private var router
    var post: Post

    var body: some View {
        Button {
            router.present(.story(personID: post.by, postID: post.id))
        } label: {
            Color.clear
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay { FriendsPostMedia(post: post, tile: true) }
                .overlay(alignment: .topTrailing) {
                    if post.kind == "walk" {
                        Image(systemName: "video.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Palette.accent, in: Circle())
                            .padding(6)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .background(Palette.surface3)
        }
        .buttonStyle(PressStyle(scale: 0.98))
    }
}
