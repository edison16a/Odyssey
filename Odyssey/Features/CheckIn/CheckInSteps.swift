//
//  CheckInSteps.swift
//  Odyssey
//
//  The first and last steps of a check-in: "Where are you?" with the
//  places closest to you, and the BeReal style pair with a caption. Tap the
//  small photo to swap which one is big.
//

import Foundation
import SwiftUI
import UIKit

/// Places to check in at, closest first.
struct CheckInPickStep: View {
    @Environment(AppStore.self) private var store
    var onPick: (Place) -> Void

    private var places: [Place] {
        let curated = store.nearbyPlaces.filter { $0.category != "transit" }
        let seen = Set(curated.map(\.id))
        let osm = store.osmPlaces.values.filter { !seen.contains($0.id) }
        // Each distance is worked out once, not twice per comparison of the sort.
        return (curated + osm).map { ($0, store.metres(to: $0)) }.sorted { $0.1 < $1.1 }.prefix(12).map { $0.0 }
    }

    var body: some View {
        let list = places
        return VStack(alignment: .leading, spacing: 4) {
            Text("Where are you?").font(.system(size: 28, weight: .bold)).tracking(-0.6).foregroundStyle(Palette.ink)
            Text("Pick the place in your photo to earn coins and keep your streak.").mutedStyle(13)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(list) { place in
                        if place.id != list.first?.id { Divider().overlay(Palette.line) }
                        row(place, closest: place.id == list.first?.id)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .padding(.top, 12)
        }
    }

    private func row(_ place: Place, closest: Bool) -> some View {
        let isNew = store.status(of: place).status == .new
        return Button { onPick(place) } label: {
            HStack(spacing: 12) {
                PhotoView(path: place.photo)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                    HStack(spacing: 0) {
                        Text(Format.distance(store.metres(to: place)) + " away").foregroundStyle(Palette.muted)
                        if isNew {
                            Text(", ").foregroundStyle(Palette.muted)
                            Text("be the first").fontWeight(.bold).foregroundStyle(Palette.rare)
                        }
                    }
                    .font(.system(size: 13))
                }
                Spacer(minLength: 0)
                if closest {
                    Text("Closest")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.accentInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Palette.accentSoft, in: Capsule())
                }
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.faint)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

/// The photo pair, the caption and Post.
struct CheckInComposeStep: View {
    var place: Place
    var placeImage: UIImage
    var selfieImage: UIImage
    var onPost: (String) -> Void

    @State private var caption = ""
    @State private var swapped = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 16) {
            CheckInDualPhoto(main: swapped ? selfieImage : placeImage, inset: swapped ? placeImage : selfieImage,
                             placeName: place.name) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { swapped.toggle() }
            }
            FieldBox(icon: "edit") {
                TextField("Say something about \(place.name)", text: $caption)
                    .font(.system(size: 15))
                    .focused($focused)
                    .submitLabel(.done)
                    .onChange(of: caption) { _, value in
                        if value.count > 120 { caption = String(value.prefix(120)) }
                    }
            }
            HStack(spacing: 8) {
                Image(systemName: Icon.symbol("users")).font(.system(size: 14))
                Text("Your friends see this at the front of their row")
                Spacer(minLength: 0)
            }
            .mutedStyle(13)
            Button {
                focused = false
                onPost(caption)
            } label: {
                Label("Post and finish", systemImage: "paperplane.fill")
            }
            .buttonStyle(.pill(.accent, fill: true))
        }
    }
}

/// The big photo with the small one tucked in the corner and the place name.
struct CheckInDualPhoto: View {
    var main: UIImage
    var inset: UIImage
    var placeName: String
    var onSwap: () -> Void

    var body: some View {
        Palette.ink
            .overlay { Image(uiImage: main).resizable().scaledToFill() }
            .overlay(alignment: .topLeading) {
                Button(action: onSwap) {
                    GeometryReader { geo in
                        Image(uiImage: inset)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .frame(width: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white, lineWidth: 2.5))
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 6)
                }
                .buttonStyle(PressStyle(scale: 0.95))
                .accessibilityLabel("Swap photos")
                .padding(12)
            }
            .overlay(alignment: .bottomLeading) {
                Label(placeName, systemImage: "location.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .frame(maxHeight: .infinity)
    }
}
