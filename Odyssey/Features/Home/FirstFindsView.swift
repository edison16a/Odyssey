//
//  FirstFindsView.swift
//  Odyssey
//
//  Places with your name on them: everywhere you were the first Odyssey
//  explorer, plus the nearby places still waiting for someone to be first.
//

import Foundation
import SwiftUI

struct FirstFindsView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let mine = store.state.firsts.reversed().compactMap { store.place($0) }
        let waiting = store.nearbyPlaces.filter { store.status(of: $0).status == .new }
        VStack(spacing: 0) {
            NavHeader(title: "First finds", back: { router.pop() })
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    hero(count: mine.count)
                    if !mine.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: "Discovered first by you", link: "\(mine.count)")
                            VStack(spacing: 0) {
                                ForEach(mine) { place in row(place, tag: Tag(text: "Your name", icon: "star-fill", tone: .rare)) }
                            }
                            .card(padding: 12)
                        }
                    }
                    if !waiting.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: "Be the first explorer", link: "+\(Rewards.checkIn.coins + Rewards.first.coins) coins")
                            VStack(spacing: 0) {
                                ForEach(waiting) { place in row(place, tag: Tag(text: "Be first", icon: "star-fill", tone: .rare)) }
                            }
                            .card(padding: 12)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Palette.surface)
    }

    private func hero(count: Int) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "star.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Palette.rare, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("\(count)").font(.system(size: 34, weight: .heavy)).tracking(-1).foregroundStyle(Palette.ink)
                Text("Places on Odyssey with your name on them. Be first somewhere and it stays yours.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
            }
        }
        .padding(16)
        .background(Palette.rareSoft, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    private func row(_ place: Place, tag: Tag) -> some View {
        Button { router.push(.place(place.id)) } label: {
            HStack(spacing: 12) {
                PlacePhoto(place: place)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                    Text([store.placeKind(place).label, Format.distance(store.metres(to: place))].joined(separator: ", "))
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
                tag
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}
