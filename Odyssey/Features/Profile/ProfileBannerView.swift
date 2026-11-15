//
//  ProfileBannerView.swift
//  Odyssey
//
//  Profile banners: a real photo of a city or a landmark that drifts
//  slowly, like a live view, with the place name in the corner. The same
//  view works as the tall profile header and as a small shop tile.
//

import Foundation
import SwiftUI
import UIKit

struct ProfileBannerView: View {
    var id: String
    var showLabel = true
    var animated = true

    @State private var drift = false

    private var banner: Banner? {
        Seed.shared.banner(id) ?? Seed.shared.banner("city-san-francisco")
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color(hex: "#1b1b1f")
            if let banner {
                ProfileFocusedPhoto(path: banner.photo, focus: banner.focus ?? "50% 50%")
                    .scaleEffect(drift ? 1.08 : 1)
                    .offset(x: drift ? 6 : -6, y: drift ? -4 : 2)
            }
            LinearGradient(stops: [
                .init(color: .black.opacity(0.38), location: 0),
                .init(color: .black.opacity(0), location: 0.45),
                .init(color: .black.opacity(0.18), location: 1),
            ], startPoint: .top, endPoint: .bottom)
            if id.hasPrefix("board-") {
                LaurelSeal(label: id == "board-top-10" ? "TOP\n10" : "TOP\n100",
                           color: id == "board-top-10" ? Color(hex: "#f2b21b") : .white)
                    .frame(maxWidth: 92, maxHeight: 92)
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
            if showLabel, let banner {
                HStack(spacing: 3) {
                    Image(systemName: banner.earnedBy?.hasPrefix("top-") == true ? "trophy.fill"
                          : (banner.streak != nil ? "flame.fill" : "location.fill"))
                        .font(.system(size: 9, weight: .bold))
                    Text(banner.label).font(.system(size: 10, weight: .bold)).tracking(0.2).lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(.leading, 6)
                .padding(.trailing, 8)
                .padding(.vertical, 3)
                .background(.black.opacity(0.32), in: Capsule())
                .padding(.leading, 10)
                .padding(.bottom, 8)
            }
        }
        .clipped()
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 26).repeatForever(autoreverses: true)) { drift = true }
        }
    }
}

/// A photo filling its box, placed like CSS object-position ("50% 30%"),
/// drawn 116 percent large so the drift never shows an edge.
struct ProfileFocusedPhoto: View {
    var path: String
    var focus: String

    var body: some View {
        GeometryReader { geo in
            if let image = UIImage(named: Media.name(for: path)), image.size.width > 0, image.size.height > 0 {
                let box = CGSize(width: geo.size.width * 1.16, height: geo.size.height * 1.16)
                let scale = max(box.width / image.size.width, box.height / image.size.height)
                let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                let point = ProfileFocusedPhoto.parse(focus)
                let x = -geo.size.width * 0.08 + (box.width - drawn.width) * point.x + drawn.width / 2
                let y = -geo.size.height * 0.08 + (box.height - drawn.height) * point.y + drawn.height / 2
                Image(uiImage: image)
                    .resizable()
                    .frame(width: drawn.width, height: drawn.height)
                    .position(x: x, y: y)
            }
        }
    }

    /// "50% 30%" as fractions.
    static func parse(_ focus: String) -> CGPoint {
        let parts = focus.split(separator: " ").map { Double($0.replacingOccurrences(of: "%", with: "")) ?? 50 }
        let x = parts.first ?? 50
        let y = parts.count > 1 ? parts[1] : 50
        return CGPoint(x: x / 100, y: y / 100)
    }
}
