//
//  ProfileHeader.swift
//  Odyssey
//
//  The top of your profile, laid out like a creator profile: banner photo,
//  framed avatar, name and title lettering, handle, rank chip, bio, four
//  stats, then Edit profile, Share and Shop. Ported from profile-view.js.
//

import Foundation
import SwiftUI

struct ProfileHeader: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var onPlaces: () -> Void

    var body: some View {
        let me = store.me
        VStack(spacing: 0) {
            ProfileBannerView(id: store.state.equipped.banner)
                .frame(height: 170)
                .frame(maxWidth: .infinity)
            VStack(spacing: 0) {
                Button { router.push(.editProfile) } label: {
                    AvatarView(person: me, size: 96)
                        .padding(5)
                        .background(Palette.surface, in: Circle())
                }
                .buttonStyle(PressStyle())
                .padding(.bottom, 10)
                Text(me.name).font(.system(size: 24, weight: .heavy)).tracking(-0.5).foregroundStyle(Palette.ink)
                if let title = ProfileTitleText(titleID: store.state.equipped.title) {
                    title.padding(.top, 2).padding(.bottom, 4)
                }
                Text("@" + me.handle).font(.system(size: 13)).foregroundStyle(Palette.muted)
                rankChip(me)
                Text(me.bio)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .padding(.top, 8)
                    .padding(.bottom, 14)
                stats(me)
                actions(me)
            }
            .padding(.horizontal, 20)
            .padding(.top, -52)
        }
    }

    private func rankChip(_ me: Person) -> some View {
        let rank = store.rank()
        return Button { router.push(.ranks) } label: {
            HStack(spacing: 6) {
                RankEmblem(tier: rank.tier, size: 18, inverse: true)
                Text(rank.current.name).font(.system(size: 11, weight: .bold))
                Rectangle().fill(.white.opacity(0.35)).frame(width: 1, height: 14)
                Text("\(me.xp) XP").font(.system(size: 11, weight: .semibold)).opacity(0.85)
            }
            .foregroundStyle(.white)
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .frame(height: 30)
            .background(Color(hex: rank.current.color), in: Capsule())
        }
        .buttonStyle(PressStyle())
        .overlay(alignment: .topTrailing) {
            if let badge = store.boardBadge {
                Button { router.push(.leaderboard) } label: { LeaderBadgeChip(badge: badge, compact: true) }
                    .buttonStyle(PressStyle())
                    .offset(x: 14, y: -12)
            }
        }
        .padding(.top, 10)
    }

    private func stats(_ me: Person) -> some View {
        let city = store.standings().first
        return HStack(spacing: 0) {
            stat(Format.compact(store.state.stats.friends), "Friends") { router.select(.friends) }
            divider
            stat("\(me.explored)", "Explored", action: onPlaces)
            divider
            stat("\(me.contributions)", "Walkthroughs", action: onPlaces)
            divider
            stat("#\(Format.number(city?.position ?? 0))", city?.scope.label ?? store.home.city) { router.push(.leaderboard) }
        }
        .padding(.bottom, 14)
    }

    private var divider: some View {
        Rectangle().fill(Palette.line).frame(width: 1, height: 30)
    }

    private func stat(_ value: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(value).font(.system(size: 19, weight: .bold)).tracking(-0.4).monospacedDigit().foregroundStyle(Palette.ink)
                Text(label).font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func actions(_ me: Person) -> some View {
        HStack(spacing: Space.s2) {
            Button("Edit profile") { router.push(.editProfile) }
                .buttonStyle(.pill(.primary, height: 44, fill: true))
            ShareLink(item: URL(string: "https://pathy.app/explorers/\(me.handle)")!,
                      subject: Text("\(me.name) on Odyssey"),
                      message: Text("Explore with me on Odyssey")) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(.pill(.soft, height: 44))
            Button { router.push(.shop(nil)) } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bag").font(.system(size: 16, weight: .semibold))
                    Text("Shop")
                }
            }
            .buttonStyle(.pill(.soft, height: 44))
        }
    }
}
