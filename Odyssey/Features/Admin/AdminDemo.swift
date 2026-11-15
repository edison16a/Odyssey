//
//  AdminDemo.swift
//  Odyssey
//
//  The demo mode card at the top of Admin. One tap sets up the hackathon
//  story: Y Combinator goes back to unclaimed, you sit just under the next
//  rank and just outside the city's top 100, and the photo check-in at YC
//  ranks you up and puts you in the top 10.
//

import Foundation
import SwiftUI

struct AdminDemoCard: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toast

    var body: some View {
        let on = store.state.demoMode
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: on ? "sparkles" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(on ? Palette.ink : .white)
                    .frame(width: 44, height: 44)
                    .background(on ? Palette.gold : .white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Demo mode").font(.system(size: 17, weight: .bold))
                    Text(on ? "On. Check in at Y Combinator to see it play out." : "Sets up the YC claim, rank up and top 10 moment.")
                        .font(.system(size: 13)).opacity(0.75)
                }
                Spacer(minLength: 0)
            }
            if on { status }
            Button(on ? "Turn off demo mode" : "Activate demo mode") { toggle(!on) }
                .buttonStyle(.pill(on ? .glass : .light, fill: true))
            if on {
                Button { router.present(.checkIn(placeID: "yc")) } label: {
                    Label("Check in at Y Combinator", systemImage: "camera.fill")
                }
                .buttonStyle(.pill(.light, fill: true))
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(Palette.ink, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
    }

    private var status: some View {
        let rank = store.rank()
        let city = store.standings().first { $0.scope.id == "city" }
        let claimed = store.place("yc").map { store.status(of: $0).status == .mine } ?? false
        return VStack(alignment: .leading, spacing: 8) {
            line(claimed ? "checkmark.seal.fill" : "star.fill", claimed ? "Y Combinator is yours" : "Y Combinator is unclaimed")
            if let next = rank.next {
                line("bolt.fill", "\(rank.current.name), \(rank.toNext) XP to \(next.name)")
            }
            if let city { line("trophy.fill", "Number \(Format.number(city.position)) in \(city.scope.label)") }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func line(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.gold).frame(width: 16)
            Text(text).font(.system(size: 13, weight: .semibold))
        }
    }

    /// Turning it on starts the demo from the top: back to the home map with onboarding
    /// over it, so the app is already loaded underneath when the last question is answered.
    private func toggle(_ on: Bool) {
        store.setDemoMode(on)
        Haptics.success()
        guard on else {
            toast.show("Demo mode is off", icon: "check")
            return
        }
        router.cover = nil
        router.paths = [:]
        router.tab = .home
        store.update { s in s.session.onboarded = false }
    }
}
