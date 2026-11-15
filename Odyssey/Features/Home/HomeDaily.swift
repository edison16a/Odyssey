//
//  HomeDaily.swift
//  Odyssey
//
//  Today's Adventure on the home panel. Until it is opened it is a sealed
//  black card that invites a reveal; afterwards it is the place's photo with
//  why Odyssey picked it, the coins waiting there and a thumbs pair.
//

import Foundation
import SwiftUI

struct HomeDailySection: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var onReveal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.dailyRevealed {
                SectionHeader(title: "Today's Adventure", link: Format.shortDate())
                revealed
            } else {
                SectionHeader(title: "Today's Adventure", link: "New pick")
                HomeSealedCard(onReveal: onReveal)
            }
        }
    }

    private var revealed: some View {
        let pick = store.dailyPick()
        let info = store.status(of: pick.place)
        let reward = Rewards.checkIn.coins + (pick.rare ? Rewards.first.coins : 0)
        return ZStack(alignment: .topTrailing) {
            Button { router.push(.place(pick.place.id)) } label: {
                ZStack(alignment: .bottomLeading) {
                    PlacePhoto(place: pick.place)
                    LinearGradient(stops: [.init(color: .clear, location: 0.35), .init(color: .black.opacity(0.78), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            flag(pick.rare, info)
                            Tag(text: Format.distance(store.metres(to: pick.place)), tone: .dark)
                        }
                        Spacer()
                        Text(pick.place.name).font(.system(size: 22, weight: .heavy)).tracking(-0.4)
                        Text(pick.reason).font(.system(size: 13)).foregroundStyle(.white.opacity(0.82)).lineLimit(2)
                        HStack(spacing: 6) {
                            CoinIcon(size: 15)
                            Text("\(reward) for checking in").font(.system(size: 13))
                        }
                        .padding(.top, 4)
                    }
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
                }
                .frame(height: 230)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            }
            .buttonStyle(PressStyle(scale: 0.98))
            ThumbsView(place: pick.place, size: 17, dark: true)
                .padding(12)
        }
    }

    @ViewBuilder private func flag(_ rare: Bool, _ info: (status: PlaceStatus, explorers: Int)) -> some View {
        if rare {
            Tag(text: "Be first", icon: "star-fill", tone: .rare)
        } else if info.status == .mine {
            Tag(text: "Explored", icon: "check", tone: .success)
        } else {
            Tag(text: "\(info.explorers) explorers", tone: .dark)
        }
    }
}

/// The sealed card: a breathing black tile with a shine sweeping across it.
struct HomeSealedCard: View {
    var onReveal: () -> Void
    @State private var breathe = false
    @State private var shine = false

    var body: some View {
        Button(action: onReveal) {
            ZStack {
                Palette.ink
                GeometryReader { geo in
                    LinearGradient(colors: [.clear, .white.opacity(0.12), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.5)
                        .rotationEffect(.degrees(20))
                        .offset(x: shine ? geo.size.width * 1.3 : -geo.size.width * 0.8)
                }
                VStack(spacing: 8) {
                    OdysseyMark(size: 46)
                    Text("Your adventure for today is ready").font(.system(size: 17, weight: .heavy))
                    Text("Picked from what you love. Press and hold to reveal.")
                        .font(.system(size: 13))
                        .opacity(0.8)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 6) {
                        Image(systemName: "eye").font(.system(size: 12, weight: .bold))
                        Text("Reveal").font(.system(size: 13, weight: .heavy))
                    }
                    .foregroundStyle(Palette.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white, in: Capsule())
                    .padding(.top, 4)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .scaleEffect(breathe ? 1.012 : 1)
            .shadow(color: Palette.ink.opacity(breathe ? 0.22 : 0), radius: 13, y: 10)
        }
        .buttonStyle(PressStyle(scale: 0.98))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { breathe = true }
            withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) { shine = true }
        }
    }
}
