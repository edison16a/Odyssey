//
//  BountySheet.swift
//  Odyssey
//
//  The bounty sheet for explorers: who put money up, how much, how it is
//  split and how far along it is, with a small map of the area. "Record a
//  walkthrough" opens the place, or the closest place in the area with the
//  fewest walkthroughs so far. Also the map layer the home map draws: a
//  dashed gold circle per bounty with a money tag in the middle.
//  Ported from features/bounty/bounty-sheet.js and bounty-map.js.
//

import Foundation
import MapKit
import SwiftUI

struct BountySheet: View {
    @Environment(AppStore.self) private var store
    @Environment(ToastCenter.self) private var toast
    @Environment(\.dismiss) private var dismiss
    var bountyID: String
    /// Called with the place to open after the sheet closes.
    var onStart: (Place) -> Void

    var body: some View {
        if let b = store.bounty(bountyID) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    header(b)
                    Text(b.title).font(.system(size: 21, weight: .bold)).tracking(-0.4).foregroundStyle(Palette.ink)
                    hero(b)
                    BountyAreaMap(bounty: b)
                        .frame(height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                    BountyProgressView(bounty: b)
                    crew(b)
                    if let earned = b.earned, earned > 0 {
                        Label("You earned \(Format.money(earned)) here", systemImage: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(hex: "#0f7a43"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#e8f7ee"), in: Capsule())
                    }
                    facts(b)
                    actions(b)
                    Text("This is a funded exploration opportunity. Estimated reward shares are not a payout guarantee. Contribution verification and actual explorer payouts are not yet available. Obtain permission before recording in a private business.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
            // The app's toasts sit under the sheet, so this sheet draws its own.
            .overlay { ToastOverlay() }
        }
    }

    private func header(_ b: Bounty) -> some View {
        HStack(spacing: 10) {
            BountySponsorBadge(bounty: b, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(b.sponsor).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                Label(BountyText.whereText(b, store: store), systemImage: "location")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            Spacer()
            Tag(text: b.isFunded ? "Funded Bounty" : "Demo Bounty", icon: "dollar", tone: .gold)
        }
    }

    private func hero(_ b: Bounty) -> some View {
        HStack(spacing: 12) {
            Text(Format.money(b.pool)).font(.system(size: 30, weight: .bold)).tracking(-0.9).monospacedDigit()
            Text(BountyText.splitLine(b, store: store)).font(.system(size: 13))
        }
        .foregroundStyle(Color(hex: "#5c3d00"))
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.goldSoft, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    @ViewBuilder private func crew(_ b: Bounty) -> some View {
        if b.crew.isEmpty {
            Text("Nobody has started yet. Be the first.").font(.system(size: 13)).foregroundStyle(Palette.muted)
        } else {
            let people = b.crew.compactMap { store.person($0) }
            let names = people.prefix(2).map { $0.id == "me" ? "You" : $0.firstName }
            let more = people.count > 2 ? " and \(people.count - 2) more" : ""
            HStack(spacing: 10) {
                AvatarStack(people: Array(people.prefix(5)), size: 26)
                Text(names.joined(separator: ", ") + more + " recording").font(.system(size: 13))
            }
        }
    }

    private func facts(_ b: Bounty) -> some View {
        HStack(spacing: 16) {
            Label("\(b.daysRemaining) days left", systemImage: "clock")
            Label("Up to \(b.maxExplorers ?? b.videos) explorers", systemImage: "person.2")
        }
        .font(.system(size: 13))
        .foregroundStyle(Palette.muted)
    }

    private func actions(_ b: Bounty) -> some View {
        HStack(spacing: 8) {
            Button {
                guard let place = BountySheet.nextPlace(b, store: store) else {
                    toast.show("Every walkthrough here is in", icon: "check")
                    return
                }
                dismiss()
                onStart(place)
            } label: {
                Label("Record a walkthrough", systemImage: "video")
            }
            .buttonStyle(.pill(.accent, fill: true))
            Button { toast.show("Invite sent to your friends", icon: "users") } label: {
                Image(systemName: "person.2").font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(.pill(.soft))
        }
    }

    /// The best place to send someone: the target, or the place in the area
    /// with the fewest walkthroughs, closest first.
    static func nextPlace(_ b: Bounty, store: AppStore) -> Place? {
        if b.target.kind == "place", let id = b.target.placeId { return store.place(id) }
        let inside = (store.seed.places + Array(store.osmPlaces.values)).filter { b.center.distance(to: $0.coords) <= b.radius }
        return inside.min { a, c in
            let va = store.videoCount(a), vc = store.videoCount(c)
            if va != vc { return va < vc }
            return store.here.distance(to: a.coords) < store.here.distance(to: c.coords)
        }
    }
}

/// A still map of one bounty's area.
struct BountyAreaMap: View {
    var bounty: Bounty

    var body: some View {
        let zoom = bounty.radius > 1200 ? 12 : bounty.radius > 400 ? 14 : 15
        Map(initialPosition: .region(HomeMapZoom.region(center: bounty.center, zoom: zoom, width: 350)), interactionModes: []) {
            BountyMapContent(bounties: [bounty], onPick: nil)
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .allowsHitTesting(false)
    }
}

/// The bounty layer: a soft dashed gold circle for each area and a money tag at its center.
struct BountyMapContent: MapContent {
    var bounties: [Bounty]
    var onPick: ((Bounty) -> Void)?

    var body: some MapContent {
        ForEach(bounties) { b in
            MapCircle(center: b.center.location, radius: b.radius)
                .foregroundStyle(Palette.gold.opacity(0.12))
                .stroke(Palette.gold.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
        }
        ForEach(bounties) { b in
            Annotation(b.sponsor, coordinate: b.center.location, anchor: .center) {
                BountyMapTag(bounty: b)
                    .onTapGesture { onPick?(b) }
            }
            .annotationTitles(.hidden)
        }
    }
}
