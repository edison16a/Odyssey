//
//  BountyWizardView.swift
//  Odyssey
//
//  Post a bounty in three steps: where explorers should record, the reward
//  and split, then review and pay. The map on the first step shows the
//  place or area as you pick it. Payment is simulated and the bounty shows
//  on the home map straight away. Ported from bounty-wizard.js.
//

import Foundation
import SwiftUI

/// The bounty being written, before it is posted.
struct BountyWizardDraft {
    var business: String
    var kind = "place"
    var placeId: String
    var areaId: String
    var pool = 100
    var split = "videos"
    var videos = 8
    var firstBonus = false
    var days = 14

    static let fee = 0.1

    init(homeID: String) {
        let sf = homeID == "sf"
        business = sf ? "Dogpatch Coffee Co" : "Hillside Coffee"
        placeId = sf ? "paper-son" : "strada"
        areaId = sf ? "dogpatch" : "downtown"
    }

    var bonusAmount: Double { firstBonus ? (Double(pool) * 0.2).rounded() : 0 }

    var perVideo: Double { ((Double(pool) - bonusAmount) / Double(max(1, videos)) * 100).rounded() / 100 }

    /// The bounty as it would be stored.
    func build(store: AppStore) -> Bounty {
        let place = store.place(placeId)
        let area = store.extras.bountyAreas.first { $0.id == areaId }
        let name = business.trimmingCharacters(in: .whitespaces).isEmpty ? "Your business" : business.trimmingCharacters(in: .whitespaces)
        let isPlace = kind == "place"
        return Bounty(
            id: "preview", sponsor: name, logo: "store", color: "#2b59ff",
            title: isPlace ? "Show explorers the inside of \(place?.name ?? "your place")" : "Walkthroughs of \(area?.name ?? "the area") for \(name)",
            target: isPlace ? BountyTarget(kind: "place", placeId: placeId, name: nil) : BountyTarget(kind: "area", placeId: nil, name: area?.name),
            center: isPlace ? (place?.coords ?? store.home.center) : (area?.center ?? store.home.center),
            radius: isPlace ? 120 : (area?.radius ?? 400),
            pool: Double(pool), split: split, firstBonus: bonusAmount, videos: videos, recorded: 0, days: days,
            crew: [], mine: nil, earned: nil)
    }
}

struct BountyWizardView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toast
    @State private var draft = BountyWizardDraft(homeID: "sf")
    @State private var step = 0
    @State private var posted: Bounty?
    @State private var started = false
    @State private var openBounty: BusinessSheetID?

    private let titles = ["Where", "Reward", "Review"]

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                Group {
                    if let posted {
                        BountyWizardDone(bounty: posted) { openBounty = BusinessSheetID(id: posted.id) }
                    } else if step == 0 {
                        BountyWizardTarget(draft: $draft)
                    } else if step == 1 {
                        BountyWizardReward(draft: $draft)
                    } else {
                        BountyWizardReview(draft: draft)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 110)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .overlay(alignment: .bottom) { foot }
        .background(Palette.surface)
        .onAppear {
            guard !started else { return }
            started = true
            draft = BountyWizardDraft(homeID: store.home.id)
        }
        .sheet(item: $openBounty) { item in
            BountySheet(bountyID: item.id, onStart: { place in
                router.dismissCover()
                // Push once the cover is gone; a push made while it is still up lands behind it.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.push(.place(place.id)) }
            }).presentationDetents([.large]).presentationCornerRadius(28)
        }
        .animation(.easeOut(duration: 0.2), value: step)
    }

    private var header: some View {
        NavHeader(title: posted == nil ? titles[step] : "Posted", back: back) {
            if posted == nil {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule().fill(i <= step ? Palette.ink : Palette.lineStrong).frame(width: 16, height: 4)
                    }
                }
                .frame(width: 60, alignment: .trailing)
            } else {
                Color.clear.frame(width: 40, height: 40)
            }
        }
    }

    private var foot: some View {
        Button(action: next) {
            if posted != nil {
                Text("Done")
            } else if step == 2 {
                Label("Pay \(Format.money(Double(draft.pool) * (1 + BountyWizardDraft.fee))) and post", systemImage: "creditcard")
            } else {
                Text("Continue")
            }
        }
        .buttonStyle(.pill(.primary, fill: true))
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(
            LinearGradient(stops: [.init(color: .white.opacity(0), location: 0), .init(color: .white, location: 0.3)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private func back() {
        if step > 0 && posted == nil { step -= 1 } else { router.dismissCover() }
    }

    private func next() {
        if posted != nil { return router.dismissCover() }
        if step < 2 {
            step += 1
            return
        }
        draft.pool = max(20, draft.pool)
        posted = store.postBounty(draft.build(store: store))
        Haptics.success()
        toast.show("Bounty posted", icon: "check")
    }
}
