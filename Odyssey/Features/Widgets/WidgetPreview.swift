//
//  WidgetPreview.swift
//  Odyssey
//
//  A widget drawn inside the app at its real home screen size, from the
//  same views the widget extension uses. Lock Screen sizes are drawn white
//  on a dark wallpaper the way iOS shows them.
//

import Foundation
import SwiftUI

struct WidgetPreview: View {
    var kind: OdysseyWidgetKind
    var size: WidgetSize
    var snapshot: WidgetSnapshot
    var prefs: WidgetPrefs
    var scale: CGFloat = 1

    var body: some View {
        let box = size.previewSize
        Group {
            if size.isAccessory {
                accessory
            } else {
                OdysseyWidgetContent(kind: kind, size: size, snapshot: snapshot, prefs: prefs)
                    .padding(kind == .adventure ? 0 : 16)
                    .frame(width: box.width, height: box.height)
                    .background(OdysseyWidgetBackground(kind: kind, style: prefs.style(for: kind), snapshot: snapshot))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.16), radius: 9, y: 6)
            }
        }
        .scaleEffect(scale)
        .frame(width: box.width * scale, height: box.height * scale)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var accessory: some View {
        let box = size.previewSize
        switch size {
        case .circular:
            OdysseyWidgetContent(kind: kind, size: size, snapshot: snapshot, prefs: prefs)
                .frame(width: box.width, height: box.height)
                .background(.white.opacity(0.2), in: Circle())
                .foregroundStyle(.white)
                .tint(.white)
                .environment(\.colorScheme, .dark)
        case .rectangular:
            OdysseyWidgetContent(kind: kind, size: size, snapshot: snapshot, prefs: prefs)
                .padding(.horizontal, 12)
                .frame(width: box.width, height: box.height)
                .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)
                .environment(\.colorScheme, .dark)
        default:
            OdysseyWidgetContent(kind: kind, size: size, snapshot: snapshot, prefs: prefs)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: box.width, height: box.height)
        }
    }
}

/// A slice of wallpaper to set previews on, like a real home screen.
struct WidgetWallpaper<Content: View>: View {
    var photo: String = "assets/media/cities/san-francisco.jpg"
    var dim: Double = 0.08
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .background {
                PhotoView(path: photo).overlay(Color.black.opacity(dim))
            }
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).strokeBorder(Palette.ink, lineWidth: 6))
            .shadow(color: .black.opacity(0.18), radius: 20, y: 12)
    }
}

/// How to put a widget on the Home Screen or Lock Screen. iOS only lets
/// people place widgets themselves, so this walks through it.
struct AddWidgetSheet: View {
    var kind: OdysseyWidgetKind
    @Environment(\.dismiss) private var dismiss
    @State private var lock = false

    private var homeSteps: [(String, String)] {
        [("hand.tap", "Touch and hold an empty spot on your Home Screen until the apps jiggle."),
         ("plus.circle", "Tap Edit in the top corner, then Add Widget."),
         ("magnifyingglass", "Search for Odyssey."),
         ("square.grid.2x2", "Pick \(kind.title), swipe to the size you like and tap Add Widget.")]
    }

    private var lockSteps: [(String, String)] {
        [("lock", "Touch and hold your Lock Screen, then tap Customize."),
         ("rectangle.on.rectangle", "Choose Lock Screen and tap the area under the clock."),
         ("magnifyingglass", "Find Odyssey in the list."),
         ("checkmark.circle", "Tap \(kind.title) to add it, then Done.")]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add \(kind.title)").font(.system(size: 22, weight: .bold)).tracking(-0.4)
            Segmented(options: [(false, "Home Screen"), (true, "Lock Screen")], selection: $lock)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array((lock ? lockSteps : homeSteps).enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Palette.ink, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Image(systemName: step.0).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.accent)
                            Text(step.1).font(.system(size: 15)).foregroundStyle(Palette.ink)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            Text("Your style choices from Odyssey carry over to the widget right away.")
                .mutedStyle()
            Button("Got it") { dismiss() }
                .buttonStyle(.pill(.primary, fill: true))
        }
        .padding(24)
    }
}
