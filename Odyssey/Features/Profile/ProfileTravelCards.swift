//
//  ProfileTravelCards.swift
//  Odyssey
//
//  Three entries on the profile tab: the explored map teaser with its lit
//  honeycomb and flags, the Odyssey Globe card, and "Own a business?" which
//  leads to posting a bounty. Ported from exploredCard() in profile-tab.js,
//  globeCard() in profile-view.js and the biz-entry row.
//

import Foundation
import SwiftUI

struct ProfileExploredCard: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        // Walks every trail and the city grid, so it is worked out once per change of state.
        let stats = store.memo("travelStats") { store.travelStats() }
        Button { router.present(.exploredMap(focus: nil)) } label: {
            HStack(spacing: 14) {
                TravelHexBadge(size: 56)
                    .frame(width: 64, height: 64)
                    .background(Color(hex: "#1b2246"), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your explored map").font(.system(size: 11, weight: .bold)).tracking(0.55).textCase(.uppercase).opacity(0.6)
                    Text("\(stats.countries) countries, \(stats.cities) cities").font(.system(size: 17, weight: .bold))
                    Text("\(stats.city)% of \(store.home.city) uncovered").font(.system(size: 13)).opacity(0.7)
                    HStack(spacing: 4) {
                        ForEach(store.travelCountries, id: \.self) { code in
                            TravelFlag(code: store.seed.countries[code]?.flag ?? "us", width: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        }
                    }
                    .padding(.top, 6)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 16, weight: .semibold)).opacity(0.7)
            }
            .foregroundStyle(.white)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#0e1226"), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
        .buttonStyle(PressStyle(scale: 0.98))
    }
}

struct ProfileGlobeCard: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        Button { router.present(.globe) } label: {
            HStack(spacing: 14) {
                GlobeArt(size: 56, mini: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Odyssey Globe 2026").font(.system(size: 11, weight: .bold)).tracking(0.55).textCase(.uppercase).opacity(0.6)
                    Text("Your year in places is ready").font(.system(size: 18, weight: .bold))
                    Text("\(store.state.stats.explored) places, \(Format.number(store.kmWalked)) km, one explorer twin")
                        .font(.system(size: 13)).opacity(0.7)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 18, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.ink, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
        .buttonStyle(PressStyle(scale: 0.98))
    }
}

struct ProfileBusinessEntry: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        Button { router.push(.business) } label: {
            HStack(spacing: 12) {
                Image(systemName: Icon.symbol("store"))
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Own a business?").font(.system(size: 15, weight: .bold))
                    Text("Put a bounty on walkthroughs of your place").font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.muted)
            }
            .foregroundStyle(Palette.ink)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
        .buttonStyle(PressStyle(scale: 0.98))
    }
}
