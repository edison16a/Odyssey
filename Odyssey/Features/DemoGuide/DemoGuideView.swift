//
//  DemoGuideView.swift
//  Odyssey
//
//  The demo guide, the panel that sat next to the phone in the mockup, as
//  a screen in settings: the demo location, presenter tools (your photo,
//  coins, unlock everything, streak set ups) and a jump to every flow.
//  Ported from features/demo-panel/demo-panel.js and demo-tools.js.
//

import Foundation
import PhotosUI
import SwiftUI
import UIKit

struct DemoGuideView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toast
    @State private var amount = 5000
    @State private var photo: PhotosPickerItem?
    @State private var bounty: BusinessSheetID?

    private var runner: DemoGuideRunner { DemoGuideRunner(store: store, router: router, toast: toast) }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Demo guide", back: { router.pop() })
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        OdysseyWordmark(size: 28, color: Palette.ink)
                        Text(Brand.motto).font(.system(size: 15, weight: .bold))
                        Text(Brand.tagline).mutedStyle()
                        Text("Every button works and nothing leaves your phone.").mutedStyle()
                    }
                    group("Demo location") { location }
                    group("Demo tools") { tools }
                    group("Streak set ups") { streaks }
                    ForEach(DemoGuideJumps.groups) { g in
                        group(g.title) {
                            VStack(spacing: 0) {
                                ForEach(g.items) { jump in jumpRow(jump) }
                            }
                        }
                    }
                    Button {
                        store.reset()
                        store.update { s in s.session.signedIn = false; s.session.onboarded = false }
                        router.paths = [:]
                        router.tab = .home
                        toast.show("Demo reset", icon: "refresh")
                    } label: { Label("Reset demo", systemImage: "arrow.clockwise") }
                        .buttonStyle(.pill(.outline, height: 36))
                    Color.clear.frame(height: 30)
                }
                .padding(16)
            }
        }
        .background(Palette.surface)
        .sheet(item: $bounty) { item in
            BountySheet(bountyID: item.id, onStart: { place in
                // Push once the sheet has slid away, so the place page is not opened behind it.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.push(.place(place.id)) }
            }).presentationDetents([.large]).presentationCornerRadius(28)
        }
        .onChange(of: photo) { _, item in
            guard item != nil else { return }
            Task {
                await usePhoto(item)
                // Cleared so picking the same photo again still counts.
                photo = nil
            }
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).labelStyle()
            content()
        }
    }

    private var location: some View {
        Segmented(options: [("sf", "YC, San Francisco"), ("berkeley", "Berkeley")], selection: Binding(
            get: { store.home.id },
            set: { id in
                store.update { s in
                    s.demoArea = id
                    s.discoverLocation = nil
                    s.useDeviceLocation = false
                }
                _ = runner.run("home")
                toast.show("You are in \(store.home.city)", icon: "location")
            }))
    }

    private var tools: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AvatarView(person: store.me, size: 34, frame: "none")
                PhotosPicker(selection: $photo, matching: .images) {
                    Label("Upload your photo", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.pill(.outline, height: 36))
            }
            HStack(spacing: 6) {
                CoinIcon(size: 16)
                Text(Format.number(store.state.wallet.coins)).font(.system(size: 15, weight: .bold)).monospacedDigit()
            }
            HStack(spacing: 8) {
                FieldBox {
                    TextField("Coins to add", value: $amount, format: .number)
                        .keyboardType(.numberPad)
                        .onSubmit { addCoins(amount) }
                }
                Button("Add") { addCoins(amount) }.buttonStyle(.pill(.primary, height: 36))
            }
            HStack(spacing: 8) {
                ForEach([1000, 10000, 100000], id: \.self) { n in
                    Chip(label: "+" + Format.compact(n)) { addCoins(n) }
                }
            }
            Button { unlockAll() } label: { Label("Unlock everything", systemImage: "gift") }
                .buttonStyle(.pill(.outline, height: 36))
        }
    }

    private var streaks: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StreakTiers.milestones, id: \.self) { n in
                    Chip(label: "\(n) days") {
                        store.update { s in
                            s.streak.days = max(0, n - 1)
                            s.streak.lastDay = nil
                        }
                        toast.show("Check in once to reach \(n) days", icon: "flame")
                    }
                }
            }
        }
    }

    private func jumpRow(_ jump: DemoGuideJump) -> some View {
        Button {
            if let id = runner.run(jump.id) { bounty = BusinessSheetID(id: id) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: Icon.symbol(jump.icon)).font(.system(size: 14, weight: .semibold)).frame(width: 22)
                Text(jump.label).font(.system(size: 14, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.faint)
            }
            .foregroundStyle(Palette.ink)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }

    private func addCoins(_ n: Int) {
        guard n > 0 else { return }
        store.earn(n)
        toast.show("+" + Format.number(n) + " coins", icon: "coin")
    }

    /// Every frame, banner, effect and title, plus the earned ones.
    private func unlockAll() {
        let seed = store.seed
        let keys: [String] = seed.frames.map { "frame-" + $0.id } + seed.banners.map { "banner-" + $0.id }
            + seed.effects.map { "effect-" + $0.id } + seed.titles.map { "title-" + $0.id }
        store.update { s in
            for key in keys where !s.owned.contains(key) { s.owned.append(key) }
            for badge in ["king", "winter"] where !s.earnedBadges.contains(badge) { s.earnedBadges.append(badge) }
        }
        toast.show("Every cosmetic unlocked", icon: "gift")
    }

    private func usePhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data),
              let file = PhotoStore.save(image, prefix: "avatar", maxSide: 800) else { return }
        store.update { s in s.user.avatar = Avatar(kind: "local", value: file) }
        toast.show("Photo updated", icon: "check")
    }
}
