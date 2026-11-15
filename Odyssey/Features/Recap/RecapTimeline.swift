//
//  RecapTimeline.swift
//  Odyssey
//
//  The recap's timeline: each stop numbered in order, what you did there
//  (checked in, recorded a walkthrough, discovered it first) and what it
//  paid in coins and XP.
//

import Foundation
import SwiftUI

struct RecapTimeline: View {
    var day: RecapDay
    var open: (Place) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Palette.lineStrong).frame(width: 2)
                .padding(.leading, 13).padding(.vertical, 20)
            VStack(spacing: 0) {
                ForEach(day.stops) { stop in row(stop) }
            }
        }
    }

    private func row(_ stop: RecapDay.Stop) -> some View {
        Button { open(stop.place) } label: {
            HStack(alignment: .top, spacing: 12) {
                Text("\(stop.id + 1)")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(stop.first ? Palette.accent : Palette.ink, in: Circle())
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                PlacePhoto(place: stop.place)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(stop.time).font(.system(size: 11)).foregroundStyle(Palette.muted)
                    Text(stop.place.name).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink).lineLimit(2)
                    FlowLayout(spacing: 4) {
                        Tag(text: "Checked in", icon: "camera")
                        if stop.action == "video" { Tag(text: "\(stop.seconds)s walkthrough", icon: "video", tone: .accent) }
                        if stop.first { Tag(text: "First explorer", icon: "star-fill", tone: .rare) }
                    }
                    .padding(.top, 4)
                    if let note = stop.note {
                        Text(note).font(.system(size: 11)).foregroundStyle(Palette.muted).padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 2) {
                    ShopCoins(amount: stop.coins, size: 13)
                    Text("+\(stop.xp) XP").font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
