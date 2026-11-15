//
//  AvatarView.swift
//  Odyssey
//
//  Avatars are always a person: their photo, one they took in the app, or
//  the default head and shoulders silhouette. A shop frame sits around the
//  face and can reach past its edge, and a story ring shows when a friend
//  posted something new.
//

import Foundation
import SwiftUI

struct AvatarView: View {
    enum Ring { case none, new, seen }

    var person: Person
    var size: CGFloat = 40
    /// Frame id to draw; nil uses the person's own, "none" hides it.
    var frame: String? = nil
    var ring: Ring = .none

    var body: some View {
        let frameID = frame ?? person.frame
        ZStack {
            face
                .frame(width: size, height: size)
                .clipShape(Circle())
            if ring != .none {
                Circle()
                    .strokeBorder(ring == .new ? Palette.accent : Palette.lineStrong, lineWidth: max(2, size * 0.045))
                    .frame(width: size + size * 0.16, height: size + size * 0.16)
            }
            if frameID != "none" && !frameID.isEmpty && ring == .none {
                FrameView(id: frameID, size: size, tier: person.rank)
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder private var face: some View {
        switch person.avatar.kind {
        case "photo":
            PhotoView(path: person.avatar.value ?? "", placeholder: Palette.faint)
        case "local", "upload":
            UserPhotoView(file: person.avatar.value, fallback: nil)
        default:
            DefaultFace()
        }
    }
}

/// Head and shoulders on grey, like a phone's empty contact photo.
struct DefaultFace: View {
    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width
            ZStack {
                Palette.faint
                Circle().fill(.white).frame(width: s * 0.36, height: s * 0.36).position(x: s * 0.5, y: s * 0.4)
                Ellipse().fill(.white).frame(width: s * 0.72, height: s * 0.68).position(x: s * 0.5, y: s * 1.0)
            }
        }
        .clipShape(Circle())
    }
}

/// Overlapping small avatars for friend rows.
struct AvatarStack: View {
    var people: [Person]
    var size: CGFloat = 26

    var body: some View {
        HStack(spacing: -size * 0.32) {
            ForEach(people) { person in
                AvatarView(person: person, size: size, frame: "none")
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            }
        }
    }
}
