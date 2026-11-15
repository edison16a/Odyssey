//
//  CountrySceneView.swift
//  Odyssey
//
//  Arriving in a new country. A plane crosses the screen, the city rises
//  at dusk, "Welcome to France" lands with the flag, a passport stamp
//  slams down and the Mega quest pays out. The biggest moment in the app,
//  since a new country is the rarest thing you can unlock. Ported from
//  features/travel/country-scene.js, country-art.js and their CSS.
//

import Foundation
import SwiftUI

struct CountrySceneView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var landed = false
    @State private var hero = false
    @State private var stamped = false
    @State private var panel = false
    @State private var flying = 0
    @State private var number = 0
    @State private var wave = false
    @State private var played = false

    private static let mega = (coins: 5000, xp: 250)
    private var trip: DemoTrip { store.extras.demoTrip }
    private var country: Country { store.seed.countries[trip.country] ?? Country(name: trip.country, flag: "fr", first: nil) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                sky(geo.size)
                Text("Landing in \(trip.city)")
                    .font(.system(size: 13, weight: .bold)).tracking(1.3).textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: geo.size.width)
                    .offset(y: geo.size.height * 0.18)
                    .opacity(hero ? 0 : 1)
                    .animation(.easeOut(duration: 0.4), value: hero)
                heroBlock
                    .frame(width: geo.size.width - 40)
                    .offset(x: 20, y: geo.size.height * 0.12)
                stamp
                    .offset(x: geo.size.width - 158, y: geo.size.height * 0.4)
                if hero { ConfettiView(count: 90) }
                CountryPanel(number: number, trip: trip, explore: explore)
                    .padding(.horizontal, 14)
                    .frame(width: geo.size.width, height: geo.size.height - 30, alignment: .bottom)
                    .opacity(panel ? 1 : 0)
                    .offset(y: panel ? 0 : 30)
                    .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.6), value: panel)
            }
        }
        .foregroundStyle(.white)
        .background(Color(hex: "#120a24"))
        .ignoresSafeArea()
        .task { await play() }
    }

    /// The dusk sky with the city rising along the bottom and the plane crossing.
    private func sky(_ size: CGSize) -> some View {
        let artWidth = size.width * 2
        let artHeight = artWidth * 260 / 400
        // The plane's three poses, typed up front so the modifier chain checks quickly.
        let planeScale: CGFloat = flying == 0 ? 1.4 : (flying == 1 ? 0.7 : 0.5)
        let planeTurn: Double = flying == 0 ? -6 : (flying == 1 ? 10 : 14)
        let planeX: CGFloat = flying == 0 ? 0 : (flying == 1 ? 330 : 420)
        let planeY: CGFloat = flying == 0 ? 0 : (flying == 1 ? 120 : 150)
        return ZStack(alignment: .topLeading) {
            LinearGradient(stops: [.init(color: Color(hex: "#120a24"), location: 0),
                                   .init(color: Color(hex: "#2a1b5e"), location: 0.38),
                                   .init(color: Color(hex: "#2a1b5e"), location: 1)],
                           startPoint: .top, endPoint: .bottom)
            SVGArtView(name: "country-scene")
                .frame(width: artWidth, height: artHeight)
                .offset(x: -size.width / 2, y: size.height - artHeight + (landed ? 0 : artHeight * 0.45))
                .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 1.6), value: landed)
            SVGArtView(name: "country-plane")
                .frame(width: 64, height: 32)
                .shadow(color: .black.opacity(0.4), radius: 5, y: 4)
                .scaleEffect(planeScale)
                .rotationEffect(.degrees(planeTurn))
                .offset(x: planeX - 70, y: size.height * 0.3 + planeY)
                .opacity(flying == 2 ? 0 : 1)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private var heroBlock: some View {
        VStack(spacing: 6) {
            TravelFlag(code: country.flag, width: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.white.opacity(0.9), lineWidth: 3))
                .shadow(color: .black.opacity(0.4), radius: 15, y: 10)
                .rotationEffect(.degrees(wave ? 3 : -3))
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: wave)
            Text("New country unlocked")
                .font(.system(size: 11, weight: .black)).tracking(1.1).textCase(.uppercase)
                .foregroundStyle(Color(hex: "#3a2600"))
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Color(hex: "#ffd76a"), in: Capsule())
                .padding(.top, 10)
            Text("Welcome to \(country.name)")
                .font(.system(size: 38, weight: .bold)).tracking(-1.5)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.5), radius: 15, y: 6)
            if number > 0 {
                Text("Country #\(number) on your map").font(.system(size: 15, weight: .semibold)).opacity(0.9)
            }
        }
        .opacity(hero ? 1 : 0)
        .scaleEffect(hero ? 1 : 0.6)
        .animation(.spring(response: 0.6, dampingFraction: 0.55), value: hero)
    }

    private var stamp: some View {
        SVGArtView(markup: CountryStamp.svg(country: country.name, city: trip.city, date: CountryStamp.today()))
            .frame(width: 140, height: 140)
            .opacity(stamped ? 0.92 : 0)
            .rotationEffect(.degrees(stamped ? -14 : -18))
            .scaleEffect(stamped ? 1 : 2.6)
            .animation(.spring(response: 0.42, dampingFraction: 0.55), value: stamped)
    }

    private func play() async {
        guard !played else { return }
        played = true
        let result = store.arrive(trip)
        if result.isNew {
            store.earn(CountrySceneView.mega.coins)
            store.addXp(CountrySceneView.mega.xp, boostable: false)
        }
        number = result.number
        withAnimation(.timingCurve(0.4, 0, 0.3, 1, duration: 1.68)) { flying = 1 }
        try? await Task.sleep(for: .milliseconds(1680))
        withAnimation(.easeOut(duration: 0.72)) { flying = 2 }
        try? await Task.sleep(for: .milliseconds(220))
        landed = true
        try? await Task.sleep(for: .milliseconds(700))
        hero = true
        wave = true
        Haptics.success()
        try? await Task.sleep(for: .milliseconds(1300))
        stamped = true
        Haptics.heavy()
        try? await Task.sleep(for: .milliseconds(900))
        panel = true
    }

    /// Close the scene and open the explored map over the new city.
    private func explore() {
        router.present(.exploredMap(focus: "trip"))
    }
}
