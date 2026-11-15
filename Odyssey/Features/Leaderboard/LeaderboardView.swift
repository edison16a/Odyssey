//
//  LeaderboardView.swift
//  Odyssey
//
//  Leaderboards by scope: your city, the state, the country and the world,
//  this week or all time. The top of each board is the explorers you know,
//  scaled to the size of the scope, and your own row comes from your real
//  points, so exploring somewhere visibly moves you. The cohort size shows
//  under the board so ranks are never ambiguous. Once you reach the top 10
//  your row moves up into the board at your real position, wearing your
//  leaderboard badge. From leaderboard.js.
//

import Foundation
import SwiftUI

struct LeaderboardView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var scope = "city"
    @State private var period = "all"

    private struct Row: Identifiable {
        var person: Person
        var points: Int
        var me = false
        var id: String { me ? "me" : person.id }
    }

    /// The top ten of the board: the people you know ranked by XP, with you at your
    /// real position once you are in it. Points follow the same curve as standings,
    /// so the numbers agree with your own row.
    private func rows(_ scope: Scope, mine: Standing) -> [Row] {
        let multiplier = period == "week" ? 1.6 : 1
        func points(_ position: Int) -> Int {
            Int((scope.spread * log(scope.population * 0.5 / Double(position)) / multiplier).rounded())
        }
        var people = store.seed.people.sorted { $0.xp > $1.xp }.prefix(10).map { $0 }
        var out: [Row] = []
        for position in 1...10 {
            if position == mine.position {
                out.append(Row(person: store.me, points: store.state.wallet.points, me: true))
            } else if !people.isEmpty {
                out.append(Row(person: people.removeFirst(), points: points(position)))
            }
        }
        return out
    }

    var body: some View {
        let standings = store.standings()
        let current = standings.first { $0.scope.id == scope } ?? standings[0]
        let multiplier = period == "week" ? 1.6 : 1
        let mine = store.standing(current.scope, points: Int(Double(store.state.wallet.points) * multiplier))
        VStack(spacing: 0) {
            NavHeader(title: "Leaderboards", back: { router.pop() })
            VStack(spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(standings) { s in
                            Chip(label: s.scope.label, isOn: scope == s.scope.id) { scope = s.scope.id }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                Segmented(options: [("week", "This week"), ("all", "All time")], selection: $period)
                    .padding(.horizontal, 20)
            }
            ScrollView {
                VStack(spacing: 0) {
                    let top = rows(current.scope, mine: mine)
                    podium(top)
                    board(top, mine: mine)
                    Text("Out of \(Format.number(current.scope.population)) explorers in \(current.scope.label)")
                        .font(.system(size: 11)).foregroundStyle(Palette.faint).padding(.top, 10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .animation(.easeOut(duration: 0.2), value: scope + period)
            }
        }
        .background(Palette.surface)
    }

    private func podium(_ rows: [Row]) -> some View {
        let top = Array(rows.prefix(3))
        return HStack(alignment: .bottom, spacing: 8) {
            if top.count == 3 {
                spot(top[1], place: 2, size: 56, block: 46)
                spot(top[0], place: 1, size: 72, block: 72).layoutPriority(1)
                spot(top[2], place: 3, size: 56, block: 32)
            }
        }
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private func spot(_ row: Row, place: Int, size: CGFloat, block: CGFloat) -> some View {
        Button { if !row.me { router.push(.person(row.person.id)) } } label: {
            VStack(spacing: 4) {
                AvatarView(person: row.person, size: size)
                    .frame(width: size * 1.2, height: size * 1.2)
                ZStack {
                    Circle().fill(place == 1 ? Palette.gold : Palette.ink)
                    if place == 1 {
                        Image(systemName: "crown.fill").font(.system(size: 11, weight: .bold))
                    } else {
                        Text("\(place)").font(.system(size: 11, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .padding(.top, -14)
                Text(row.me ? "You" : row.person.firstName).font(.system(size: 13, weight: .bold))
                    .foregroundStyle(row.me ? Palette.accentInk : Palette.ink).lineLimit(1)
                Text(Format.number(row.points)).font(.system(size: 11)).monospacedDigit().foregroundStyle(Palette.muted)
                UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 4, bottomTrailingRadius: 4, topTrailingRadius: 14, style: .continuous)
                    .fill(place == 1 ? Palette.goldSoft : Palette.surface2)
                    .frame(height: block)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressStyle())
    }

    private func board(_ rows: [Row], mine: Standing) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()).dropFirst(3), id: \.element.id) { index, row in
                if row.me {
                    meLine(mine).padding(.horizontal, 16).background(Palette.accentSoft).padding(.horizontal, -16)
                } else {
                    Button { router.push(.person(row.person.id)) } label: {
                        line(rank: "\(index + 1)", person: row.person, title: row.person.name, sub: nil, points: row.points)
                    }
                    .buttonStyle(.plain)
                }
                Divider().overlay(Palette.line)
            }
            if mine.position > 10 {
                meLine(mine)
                    .padding(.horizontal, 16)
                    .background(Palette.accentSoft)
                    .padding(.horizontal, -16)
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
    }

    private func meLine(_ mine: Standing) -> some View {
        line(rank: Format.number(mine.position), person: store.me, title: "You",
             sub: "Top \(ProfileTravel.pct(mine.pct))%", points: store.state.wallet.points, me: true)
    }

    private func line(rank: String, person: Person, title: String, sub: String?, points: Int, me: Bool = false) -> some View {
        HStack(spacing: Space.s3) {
            Text(rank).font(.system(size: 13, weight: .bold)).monospacedDigit().foregroundStyle(Palette.muted)
                .frame(minWidth: 26, alignment: .leading)
            AvatarView(person: person, size: 36)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(me ? Palette.accentInk : Palette.ink).lineLimit(1)
                if let sub { Text(sub).font(.system(size: 13)).foregroundStyle(Palette.muted) }
            }
            if me, let badge = store.boardBadge { LeaderBadgeChip(badge: badge) }
            Spacer(minLength: 0)
            Text(Format.number(points)).font(.system(size: 13, weight: .bold)).monospacedDigit().foregroundStyle(Palette.ink)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
