//
//  ProfileShowcase.swift
//  Odyssey
//
//  The profile showcase: display cards for the best of your exploring,
//  laid out like a trophy shelf. Miles traveled, places explored, the
//  streak with Globie, first discoveries, countries and cities,
//  walkthroughs and your best standing. Ported from profile-showcase.js.
//

import Foundation
import SwiftUI

struct ProfileShowcaseGrid: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var onPlaces: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            miles
            HStack(alignment: .top, spacing: 10) {
                photos.frame(height: 246)
                VStack(spacing: 10) {
                    streak
                    tile(background: Palette.rare, foreground: .white, action: onPlaces) {
                        label("star-fill", "First discoveries")
                        Spacer(minLength: 4)
                        big("\(store.state.firsts.count)")
                        sub("Places with your name on them")
                    }
                }
            }
            world
            HStack(spacing: 10) {
                tile(background: Palette.accent, foreground: .white, action: onPlaces) {
                    label("video", "Walkthroughs")
                    Spacer(minLength: 4)
                    big("\(store.state.stats.contributions)")
                    sub("Shared to help explorers")
                }
                standing
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Cards

    private var miles: some View {
        let km = store.kmWalked
        return tile(background: Palette.ink, foreground: .white, minHeight: 132, action: { router.present(.globe) }) {
            label("footprints", "Traveled this year")
            Spacer(minLength: 4)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                big(Format.number(km * 0.621))
                Text("miles").font(.system(size: 15, weight: .bold)).opacity(0.7)
            }
            sub("\(Format.number(km)) km on foot, roughly Berkeley to Monterey")
        }
        .overlay(alignment: .topTrailing) { ProfileTrail().frame(width: 200, height: 80).padding(.top, 10).allowsHitTesting(false) }
    }

    private var photos: some View {
        let recent = Array(store.myPlaces.prefix(3))
        return tile(background: .white, foreground: Palette.ink, action: onPlaces) {
            ZStack(alignment: .topLeading) {
                ForEach(Array(recent.enumerated()), id: \.offset) { index, place in
                    PlacePhoto(place: place)
                        .frame(width: 100, height: 75)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white, lineWidth: 3))
                        .shadow(color: Palette.ink.opacity(0.16), radius: 8, y: 6)
                        .rotationEffect(.degrees(Double(index) * 5 - 5))
                        .offset(x: CGFloat(index) * 17, y: CGFloat(index) * 12)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            Spacer(minLength: 6)
            label("pin", "Places explored")
            big("\(store.state.stats.explored)")
            sub("Latest: " + (recent.first?.name ?? "your next adventure"))
        }
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
    }

    private var streak: some View {
        let mood = store.globieMood
        let background: Color = mood == .ecstatic ? Palette.goldSoft : (mood == .happy ? Color(hex: "#eef3ff") : Palette.surface2)
        return tile(background: background, foreground: Palette.ink, action: { router.push(.streak) }) {
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                GlobieView(mood: mood, form: store.streakTier.id, size: 44)
                big("\(store.state.streak.days)")
            }
            sub("Day streak, best \(max(store.state.streak.best, store.state.streak.days))")
        }
    }

    private var world: some View {
        // Walks every trail and the city grid, so it is worked out once per change of state.
        let stats = store.memo("travelStats") { store.travelStats() }
        return tile(background: Palette.surface2, foreground: Palette.ink, minHeight: 0, action: { router.present(.exploredMap(focus: nil)) }) {
            HStack {
                label("globe", "Your world")
                Spacer()
                HStack(spacing: 4) {
                    ForEach(store.travelCountries, id: \.self) { code in
                        TravelFlag(code: store.seed.countries[code]?.flag ?? "us", width: 22)
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    }
                }
            }
            HStack(alignment: .top) {
                pair("\(stats.countries)", "countries")
                pair("\(stats.cities)", "cities")
                pair("\(stats.city)%", "of " + store.home.city)
            }
            .padding(.top, 10)
        }
    }

    private var standing: some View {
        let best = store.bestStanding
        return tile(background: Palette.goldSoft, foreground: Palette.ink, action: { router.push(.leaderboard) }) {
            label("trophy", best.scope.label).foregroundStyle(Color(hex: "#8a6100"))
            Spacer(minLength: 4)
            big(best.scope.id == "city" ? "#\(best.position)" : "Top \(ProfileTravel.pct(best.pct))%")
            sub("Your best standing")
        }
    }

    // MARK: Pieces

    private func tile<Content: View>(background: Color, foreground: Color, minHeight: CGFloat = 118,
                                     action: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) { content() }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: .infinity, alignment: .topLeading)
                .foregroundStyle(foreground)
                .background(background, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
        .buttonStyle(PressStyle(scale: 0.98))
    }

    private func label(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: Icon.symbol(icon)).font(.system(size: 11, weight: .bold))
            Text(text).font(.system(size: 11, weight: .bold)).tracking(0.55).textCase(.uppercase).lineLimit(1)
        }
        .opacity(0.75)
    }

    private func big(_ text: String) -> some View {
        Text(text).font(.system(size: 34, weight: .heavy)).tracking(-1.3).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
    }

    private func sub(_ text: String) -> some View {
        Text(text).font(.system(size: 11, weight: .semibold)).opacity(0.7).lineLimit(2).multilineTextAlignment(.leading)
    }

    private func pair(_ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.system(size: 22, weight: .heavy)).tracking(-0.4).foregroundStyle(Palette.ink)
            Text(caption).font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.muted).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
