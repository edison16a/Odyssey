//
//  HomeTab.swift
//  Odyssey
//
//  Home answers one question within seconds of opening the app: what
//  adventure can I do today, and what will I earn? Top to bottom: your
//  coins, streak and rank; Today's Adventure, sealed until you reveal it;
//  Today's Quests, which pay automatically as you complete them; your
//  World Map; then places you'll love and hidden gems, with Discover more
//  opening Explore.
//

import Foundation
import MapKit
import SwiftUI

struct HomeTab: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toast
    @State private var preview: Place?
    @State private var bountyOpen: Bounty?
    @State private var paid: [String] = []

    var body: some View {
        ScrollViewReader { reader in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HomeRewardsHeader()
                        .id("top")
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                    HomeAdventureHero()
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                    HomeExploredMapCard()
                        .padding(.horizontal, 20)
                        .padding(.top, 28)
                    HomeTodayQuests(justPaid: paid)
                        .padding(.horizontal, 20)
                        .padding(.top, 28)
                    HomeRecommendations(onPick: { preview = $0 })
                    TabBarSpacer()
                }
            }
            .onChange(of: router.scrollToTop[.home] ?? 0) { _, _ in
                withAnimation { reader.scrollTo("top", anchor: .top) }
            }
        }
        .background(Palette.surface)
        .onAppear { payTasks() }
        // Completing a task anywhere in the app pays it the next time Home sees it.
        .onChange(of: store.state.checkins) { payTasks() }
        .onChange(of: store.state.videos) { payTasks() }
        .onChange(of: store.state.questsDone) { payTasks() }
        .sheet(item: $preview) { place in
            HomePlacePreview(place: place, onBounty: { bounty in
                preview = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { bountyOpen = bounty }
            })
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .background {
            Color.clear.sheet(item: $bountyOpen) { bounty in
                BountySheet(bountyID: bounty.id) { place in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { preview = place }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
            }
        }
    }

    private func payTasks() {
        let done = store.claimDailyTasks()
        guard !done.isEmpty else { return }
        Haptics.success()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { paid = done.map(\.id) }
        let coins = done.reduce(0) { $0 + $1.coins }
        let points = done.reduce(0) { $0 + $1.points }
        let what = done.count == 1 ? done[0].title : "\(done.count) quests done"
        toast.show(coins > 0 ? "+\(coins) coins · \(what)" : "+\(points) points · \(what)", icon: "coin")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation { paid = [] }
        }
    }
}

// MARK: Coins, streak and rank

struct HomeRewardsHeader: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let rank = store.rank()
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                IconButton(icon: "users", kind: .white, label: "Friends") { router.push(.friends) }
                IconButton(icon: "bell", kind: .white, badge: store.unreadNotifications, label: "Notifications") { router.push(.notifications) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.muted)
                    Text(store.state.user.name.split(separator: " ").first.map(String.init) ?? "Explorer")
                        .font(.system(size: 26, weight: .heavy)).tracking(-0.6).foregroundStyle(Palette.ink)
                }
                Spacer()
            }
            HStack(spacing: 8) {
                pill(action: { router.push(.shop(nil)) }) {
                    CoinIcon(size: 18)
                    Text("\(store.state.wallet.coins)").contentTransition(.numericText())
                }
                pill(action: { router.push(.streak) }) {
                    Image(systemName: "flame.fill").foregroundStyle(store.streakClaimedToday ? Palette.flame : Palette.faint)
                    Text("\(store.state.streak.days)").contentTransition(.numericText())
                }
                Button { router.push(.ranks) } label: {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle().stroke(Palette.surface3, lineWidth: 2.5)
                            Circle().trim(from: 0, to: rank.progress)
                                .stroke(Color(hex: rank.current.color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            RankEmblem(tier: rank.tier, size: 22)
                        }
                        .frame(width: 32, height: 32)
                        .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(rank.current.name).font(.system(size: 13, weight: .heavy)).lineLimit(1)
                            Text(rank.next.map { _ in "\(rank.toNext) XP to next" } ?? "Top rank")
                                .font(.system(size: 10, weight: .semibold)).foregroundStyle(Palette.muted).lineLimit(1)
                        }
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 46)
                    .background(.white, in: Capsule())
                    .overlay(Capsule().strokeBorder(Palette.line))
                }
                .buttonStyle(PressStyle())
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: store.state.wallet.coins)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
    }

    private func pill<Content: View>(action: @escaping () -> Void, @ViewBuilder _ content: () -> Content) -> some View {
        Button(action: action) {
            HStack(spacing: 6) { content() }
                .font(.system(size: 17, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(.white, in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.line))
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: Today's Adventure

struct HomeAdventureHero: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var glow = false

    var body: some View {
        if store.dailyRevealed {
            revealed
                .transition(.asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity), removal: .opacity))
        } else {
            sealed
                .transition(.opacity)
        }
    }

    /// Today's pick stays hidden until you open it: a small daily moment.
    private var sealed: some View {
        let pick = store.dailyPick()
        return Button(action: reveal) {
            ZStack {
                PlacePhoto(place: pick.place)
                    .blur(radius: 28)
                    .scaleEffect(1.2)
                    .overlay(Color.black.opacity(0.55))
                VStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 26, weight: .semibold))
                        .frame(width: 60, height: 60)
                        .background(.white.opacity(0.14), in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.25)))
                        .scaleEffect(glow ? 1.06 : 1)
                    VStack(spacing: 6) {
                        Text("Today's Adventure").font(.system(size: 24, weight: .heavy)).tracking(-0.5)
                        Text("A new place picked for your taste, every day.")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    Text("Tap to reveal")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 22)
                        .frame(height: 44)
                        .background(.white, in: Capsule())
                        .padding(.top, 4)
                }
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(20)
            }
            .frame(height: 316)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        }
        .buttonStyle(PressStyle(scale: 0.98))
        .accessibilityLabel("Reveal today's adventure")
        .loops($glow, .easeInOut(duration: 1.4))
    }

    private func reveal() {
        Haptics.success()
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { store.revealDaily() }
    }

    private var revealed: some View {
        let pick = store.dailyPick()
        let done = store.checkedInTodayIDs.contains(pick.place.id)
        let rewards = store.checkInRewards(for: pick.place)
        return VStack(spacing: 0) {
            Button { router.push(.place(pick.place.id)) } label: {
                ZStack(alignment: .bottomLeading) {
                    PlacePhoto(place: pick.place)
                    LinearGradient(stops: [.init(color: .black.opacity(0.25), location: 0), .init(color: .clear, location: 0.3),
                                           .init(color: .black.opacity(0.85), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Tag(text: "Today's Adventure", icon: "sparkle", tone: .dark)
                            if pick.rare { Tag(text: "Be first", icon: "star-fill", tone: .rare) }
                            Spacer()
                            Tag(text: Format.distance(store.metres(to: pick.place)), tone: .dark)
                        }
                        Spacer()
                        Text(pick.place.name).font(.system(size: 28, weight: .heavy)).tracking(-0.6).lineLimit(2)
                        Text(pick.reason).font(.system(size: 13)).foregroundStyle(.white.opacity(0.85)).lineLimit(2)
                    }
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .padding(16)
                }
                .frame(height: 250)
                .clipped()
            }
            .buttonStyle(.plain)
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    if done {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.success)
                        Text("Adventure complete. Nice work!").font(.system(size: 16, weight: .heavy))
                    } else {
                        Text("You'll earn").font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.muted)
                        CoinIcon(size: 18)
                        Text("+\(rewards.coins) coins").font(.system(size: 17, weight: .heavy)).monospacedDigit()
                        Spacer()
                        Text("+\(rewards.totalXp) XP").font(.system(size: 13, weight: .heavy)).foregroundStyle(Palette.rare)
                    }
                }
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    Haptics.tap()
                    if done { router.push(.place(pick.place.id)) } else { router.present(.checkIn(placeID: pick.place.id)) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: done ? "map" : "play.fill").font(.system(size: 15, weight: .bold))
                        Text(done ? "View place" : "Start Today's Adventure").font(.system(size: 17, weight: .heavy))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(done ? Palette.ink2 : Palette.accent, in: Capsule())
                    .shadow(color: Palette.accent.opacity(done ? 0 : (glow ? 0.45 : 0.15)), radius: glow ? 14 : 6, y: 4)
                }
                .buttonStyle(PressStyle(scale: 0.97))
            }
            .padding(14)
            .background(.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(Palette.line))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
        .loops($glow, .easeInOut(duration: 1.4))
    }
}

// MARK: Today's Quests

struct HomeTodayQuests: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var justPaid: [String]

    var body: some View {
        let tasks = store.dailyTasks
        let finished = tasks.filter(\.complete).count
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today's Quests").font(.system(size: 20, weight: .heavy)).tracking(-0.4).foregroundStyle(Palette.ink)
                Spacer()
                Text("\(finished)/\(tasks.count) done").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.muted)
            }
            .padding(.bottom, 4)
            ProgressBar(value: Double(finished) / Double(max(tasks.count, 1)), color: Palette.success)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: finished)
                .padding(.bottom, 12)
            VStack(spacing: 0) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    if index > 0 { Divider().overlay(Palette.line) }
                    row(task, celebrating: justPaid.contains(task.id))
                }
            }
            .card(padding: 4)
        }
    }

    private func row(_ task: DailyTask, celebrating: Bool) -> some View {
        Button { start(task) } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(task.complete ? Palette.successSoft : Palette.surface2)
                    Image(systemName: task.complete ? "checkmark" : task.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(task.complete ? Palette.success : Palette.ink)
                        .scaleEffect(celebrating ? 1.35 : 1)
                }
                .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title).font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .strikethrough(task.complete, color: Palette.faint)
                    HStack(spacing: 8) {
                        ProgressBar(value: task.progress, color: task.complete ? Palette.success : Palette.accent)
                            .frame(width: 70)
                        Text(task.complete ? "Done" : "\(task.done)/\(task.target) · \(task.detail)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.muted)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                HStack(spacing: 4) {
                    if task.coins > 0 && task.reward.hasPrefix("+") { CoinIcon(size: 13) }
                    Text(task.reward).font(.system(size: 13, weight: .heavy)).monospacedDigit()
                }
                .foregroundStyle(task.complete ? Palette.success : Color(hex: "#9a6a00"))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(task.complete ? Palette.successSoft : Palette.goldSoft, in: Capsule())
                .scaleEffect(celebrating ? 1.15 : 1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.98))
        .disabled(task.complete)
    }

    private func start(_ task: DailyTask) {
        Haptics.tap()
        switch task.action {
        case .adventure: router.present(.checkIn(placeID: store.dailyPick().place.id))
        case .capture, .explore: router.present(.checkIn(placeID: nil))
        case .friends: router.push(.quests)
        }
    }
}

// MARK: Recommendations

struct HomeRecommendations: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var onPick: (Place) -> Void

    var body: some View {
        let open = store.nearbyPlaces.filter { store.status(of: $0).status != .mine }
        let loved = Array(store.forYou().filter { store.status(of: $0).status != .mine }.prefix(8))
        let lovedIDs = Set(loved.map(\.id))
        let gems = Array(open.filter { store.status(of: $0).status == .new && !lovedIDs.contains($0.id) }.prefix(8))
        VStack(alignment: .leading, spacing: 0) {
            shelf("Places you'll love", subtitle: "Picked from your taste gem", places: loved)
            shelf("Hidden gems", subtitle: "Nobody on Odyssey has been yet. Be first for +\(Rewards.first.coins) coins", places: gems, star: true)
            Button {
                Haptics.tap()
                router.select(.explore)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "safari").font(.system(size: 15, weight: .semibold))
                    Text("Discover more").font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(.white, in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.line))
            }
            .buttonStyle(PressStyle(scale: 0.98))
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
    }

    @ViewBuilder private func shelf(_ title: String, subtitle: String, places: [Place], star: Bool = false) -> some View {
        if !places.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 20, weight: .heavy)).tracking(-0.4).foregroundStyle(Palette.ink)
                    Text(subtitle).font(.system(size: 13)).foregroundStyle(Palette.muted)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(places) { place in
                            HomeRecCard(place: place, star: star) { onPick(place) }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 28)
        }
    }
}

/// A place a friend explored, with their face on the photo.
struct HomeFriendAdventureCard: View {
    @Environment(AppStore.self) private var store
    var place: Place
    var person: Person
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                PlacePhoto(place: place)
                    .frame(width: 168, height: 126)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .overlay(alignment: .bottomLeading) {
                        AvatarView(person: person, size: 30, frame: "none")
                            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                            .padding(8)
                    }
                Text(place.name).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink).lineLimit(1).padding(.top, 4)
                Text("\(person.name.split(separator: " ").first ?? "") explored it")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            .frame(width: 168, alignment: .leading)
        }
        .buttonStyle(PressStyle())
    }
}

/// A photo card with the reason Odyssey picked it and a thumbs pair.
struct HomeRecCard: View {
    @Environment(AppStore.self) private var store
    var place: Place
    var star = false
    var onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: onTap) {
                PlacePhoto(place: place)
                    .frame(width: 168, height: 126)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if star {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(Palette.rare, in: Circle())
                                .padding(8)
                        }
                    }
            }
            .buttonStyle(PressStyle())
            Button(action: onTap) {
                Text(place.name).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink).lineLimit(1)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            Text(store.why(place)).font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(2, reservesSpace: true)
            HStack {
                Text(Format.distance(store.metres(to: place))).font(.system(size: 11)).foregroundStyle(Palette.muted)
                Spacer()
                ThumbsView(place: place, size: 15)
            }
            .padding(.top, 2)
        }
        .frame(width: 168)
    }
}

// MARK: The 3D explored map

struct HomeExploredMapCard: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Your World in 3D")
            WorldMapView(isPreview: true)
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Palette.line))
            Button { router.openWorldMap() } label: {
                Label("Open Map", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .foregroundStyle(.white)
                    .background(Palette.accent, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(PressStyle())
            .accessibilityIdentifier("home.openWorldMap")
        }
    }
}
