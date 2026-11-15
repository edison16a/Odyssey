//
//  FriendsWidgetView.swift
//  Shared by the app and the widgets.
//
//  Friends Exploring: who is out right now. Medium groups their faces in
//  bright bubbles next to a line saying who is where; large lists each one
//  on its own tile with the place and how long ago. The Color style sits on
//  Odyssey blue.
//

import Foundation
import SwiftUI

struct FriendsWidgetView: View {
    var size: WidgetSize
    var snapshot: WidgetSnapshot
    var prefs: WidgetPrefs

    private var style: WidgetStyle { prefs.style(for: .friends) }
    private var colors: WidgetColors { WidgetLook.colors(.friends, style, snapshot) }
    private static let tints = ["#ff6a2b", "#f2b21b", "#17a35a", "#8a5cff", "#ff4fa3"]

    private func tint(_ index: Int) -> Color { Color(hex: FriendsWidgetView.tints[index % FriendsWidgetView.tints.count]) }

    var body: some View {
        if snapshot.friends.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                WidgetLabel(text: "Friends exploring", symbol: "person.2.fill", color: colors.secondary)
                Spacer()
                Text("Add friends to see where they explore").font(.system(size: 14, weight: .heavy)).foregroundStyle(colors.text)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else if size == .large {
            large
        } else {
            medium
        }
    }

    private var headline: String {
        let names = snapshot.friends.prefix(3).map(\.firstName)
        switch names.count {
        case 1: return "\(names[0]) is out exploring"
        case 2: return "\(names[0]) and \(names[1]) are out exploring"
        default: return "\(names[0]), \(names[1]) and \(names[2]) are out exploring"
        }
    }

    private var medium: some View {
        let shown = Array(snapshot.friends.prefix(min(3, max(1, prefs.friendCount))))
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 5) {
                WidgetLabel(text: "Friends exploring", symbol: "person.2.fill", color: colors.secondary)
                Spacer(minLength: 0)
                Text(headline).font(.system(size: 16, weight: .heavy)).tracking(-0.3).lineLimit(3).foregroundStyle(colors.text)
                if let latest = snapshot.friends.first {
                    HStack(spacing: 5) {
                        Circle().fill(tint(0)).frame(width: 7, height: 7)
                        Text("\(latest.firstName) at \(latest.place)").font(.system(size: 11, weight: .semibold)).lineLimit(1)
                    }
                    .foregroundStyle(colors.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            cluster(shown)
                .frame(width: 128, height: 126)
        }
    }

    /// Up to three faces in overlapping bubbles, the newest biggest, with how long ago.
    private func cluster(_ friends: [FriendActivity]) -> some View {
        let spots: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [(46, 50, 62), (98, 38, 48), (84, 98, 44)]
        return ZStack {
            ForEach(Array(friends.enumerated().reversed()), id: \.offset) { index, friend in
                let spot = spots[index % spots.count]
                WidgetFace(name: friend.name, file: friend.imageFile, size: spot.size)
                    .overlay(Circle().strokeBorder(tint(index), lineWidth: 3.5))
                    .overlay(Circle().strokeBorder(.white, lineWidth: 1).padding(3.5))
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                    .overlay(alignment: .bottom) {
                        Text(friend.agoText)
                            .font(.system(size: 9.5, weight: .heavy)).monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).frame(height: 16)
                            .background(tint(index), in: Capsule())
                            .overlay(Capsule().strokeBorder(.white, lineWidth: 1.5))
                            .offset(y: 7)
                    }
                    .position(x: spot.x, y: spot.y)
            }
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                WidgetLabel(text: "Friends exploring", symbol: "person.2.fill", color: colors.secondary)
                Spacer()
                Text("\(snapshot.friends.count) out now").font(.system(size: 11, weight: .bold)).foregroundStyle(colors.secondary)
            }
            ForEach(Array(snapshot.friends.prefix(5).enumerated()), id: \.offset) { index, friend in
                HStack(spacing: 10) {
                    WidgetFace(name: friend.name, file: friend.imageFile, size: 36)
                        .overlay(Circle().strokeBorder(tint(index), lineWidth: 3))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(friend.name).font(.system(size: 13.5, weight: .bold)).lineLimit(1).foregroundStyle(colors.text)
                        HStack(spacing: 3) {
                            Image(systemName: "mappin").font(.system(size: 9, weight: .bold))
                            Text(friend.place).font(.system(size: 11.5, weight: .medium)).lineLimit(1)
                        }
                        .foregroundStyle(colors.secondary)
                    }
                    Spacer(minLength: 4)
                    Text(friend.agoText)
                        .font(.system(size: 10.5, weight: .heavy)).monospacedDigit().foregroundStyle(.white)
                        .padding(.horizontal, 7).frame(height: 20)
                        .background(tint(index), in: Capsule())
                }
                .padding(7)
                .background(colors.chip, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Spacer(minLength: 0)
        }
    }
}
