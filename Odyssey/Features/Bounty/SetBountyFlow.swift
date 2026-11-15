//
//  SetBountyFlow.swift
//  Odyssey
//
//  "Set bounty" from a place: pick an amount, pick how wide it reaches (just
//  this restaurant, its street, or the whole city), then pay with Whop. Once
//  Whop confirms the payment (webhook, or a direct check if the webhook is
//  slow) the bounty is live on the map for every explorer.
//

import SafariServices
import SwiftUI

/// How far a bounty reaches.
enum BountyScope: String, CaseIterable, Identifiable {
    case place, street, city
    var id: String { rawValue }
}

struct SetBountyFlow: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var placeID: String

    @State private var step = 0
    @State private var amount = 50
    @State private var custom = ""
    @State private var scope: BountyScope = .place
    @State private var checkout: Cloud.BountyCheckout?
    @State private var showPay = false
    @State private var working = false
    @State private var error: String?
    @State private var live: Bounty?
    @State private var draft: Bounty?

    private let presets = [25, 50, 100, 250]
    private let titles = ["Amount", "Where", "Pay"]

    private var place: Place? { store.place(placeID) }
    private var pool: Int { Int(custom) ?? amount }
    private var total: Double { (Double(pool) * 1.1 * 100).rounded() / 100 }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: live == nil ? titles[step] : "Live", back: back) {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule().fill(i <= step || live != nil ? Palette.ink : Palette.lineStrong).frame(width: 16, height: 4)
                    }
                }
                .frame(width: 60, alignment: .trailing)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let live {
                        done(live)
                    } else if step == 0 {
                        amountStep
                    } else if step == 1 {
                        scopeStep
                    } else {
                        payStep
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .overlay(alignment: .bottom) { foot }
        .background(Palette.surface)
        .animation(.easeOut(duration: 0.2), value: step)
        .sheet(isPresented: $showPay) {
            if let url = checkout?.url { SafariView(url: url).ignoresSafeArea() }
        }
        .task(id: checkout?.bountyID) { await watch() }
        .onChange(of: router.paidBountyID) { _, id in
            guard let id, id == checkout?.bountyID else { return }
            Task { await check(sync: true) }
        }
    }

    // MARK: Steps

    private var amountStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            header("Put a bounty on \(place?.name ?? "this place")",
                   "Explorers who record a walkthrough here split it. You pay once with Whop.")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(presets, id: \.self) { n in
                    let on = custom.isEmpty && amount == n
                    Button {
                        custom = ""
                        amount = n
                        Haptics.tap()
                    } label: {
                        Text(Format.money(Double(n)))
                            .font(.system(size: 24, weight: .bold)).tracking(-0.5)
                            .foregroundStyle(on ? .white : Palette.ink)
                            .frame(maxWidth: .infinity).frame(height: 72)
                            .background(on ? Palette.ink : Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                    }
                    .buttonStyle(PressStyle())
                }
            }
            HStack(spacing: 8) {
                Text("$").font(.system(size: 17, weight: .bold)).foregroundStyle(Palette.muted)
                TextField("Custom amount", text: $custom)
                    .keyboardType(.numberPad)
                    .font(.system(size: 17, weight: .semibold))
                    .onChange(of: custom) { _, v in custom = String(v.filter(\.isNumber).prefix(4)) }
            }
            .padding(14)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            if pool < 5 || pool > 5000 {
                Text("Pick between $5 and $5,000.").font(.system(size: 13)).foregroundStyle(Palette.danger)
            }
        }
    }

    private var scopeStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            header("How far should it reach?", "Walkthroughs anywhere inside count toward your bounty.")
            ForEach(BountyScope.allCases) { s in
                let info = scopeInfo(s)
                Button {
                    scope = s
                    Haptics.tap()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: info.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(scope == s ? .white : Palette.ink)
                            .frame(width: 44, height: 44)
                            .background(scope == s ? Palette.accent : Palette.surface3, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(info.title).font(.system(size: 16, weight: .bold)).foregroundStyle(Palette.ink)
                            Text(info.detail).font(.system(size: 13)).foregroundStyle(Palette.muted)
                        }
                        .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: scope == s ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22)).foregroundStyle(scope == s ? Palette.accent : Palette.lineStrong)
                    }
                    .padding(14)
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .stroke(scope == s ? Palette.accent : .clear, lineWidth: 2))
                }
                .buttonStyle(PressStyle())
            }
        }
    }

    private var payStep: some View {
        let b = build()
        return VStack(alignment: .leading, spacing: 14) {
            header("Review and pay", "Your bounty goes live as soon as Whop confirms the payment.")
            VStack(spacing: 0) {
                row("Bounty", Format.money(Double(pool)))
                Divider()
                row("Where", scopeInfo(scope).title)
                Divider()
                row("Walkthroughs", "\(b.videos), \(Format.money(store.bountySlice(b))) each")
                Divider()
                row("Odyssey fee (10%)", Format.money(total - Double(pool)))
                Divider()
                row("Total", Format.money(total), bold: true)
            }
            .card(padding: 14)
            HStack(spacing: 8) {
                WhopMark(size: 18)
                Text("Paid securely with Whop. Sandbox: use card 4242 4242 4242 4242.")
                    .font(.system(size: 12)).foregroundStyle(Palette.muted)
            }
            if checkout != nil && live == nil {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Waiting for Whop to confirm the payment...").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            }
            if let error {
                Text(error).font(.system(size: 13)).foregroundStyle(Palette.danger)
            }
        }
    }

    private func done(_ b: Bounty) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark").font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
                .frame(width: 72, height: 72).background(Palette.success, in: Circle())
            Text("Your bounty is live").font(.system(size: 24, weight: .bold)).tracking(-0.7)
            Text("\(Format.money(b.pool)) on \(scopeInfo(scope).title). Every explorer nearby can see it on the map now.")
                .font(.system(size: 13)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
            BountyCard(bounty: store.bounty(b.id) ?? b, action: {})
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    // MARK: Pieces

    private func header(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 24, weight: .bold)).tracking(-0.6).foregroundStyle(Palette.ink)
            Text(sub).font(.system(size: 14)).foregroundStyle(Palette.muted)
        }
    }

    private func row(_ label: String, _ value: String, bold: Bool = false) -> some View {
        HStack {
            Text(label).font(.system(size: 14, weight: bold ? .bold : .regular)).foregroundStyle(bold ? Palette.ink : Palette.muted)
            Spacer()
            Text(value).font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.ink)
        }
        .padding(.vertical, 10)
    }

    private var foot: some View {
        Button(action: next) {
            if working {
                ProgressView().tint(.white)
            } else if live != nil {
                Text("Done")
            } else if step == 2 {
                Label(checkout == nil ? "Pay \(Format.money(total)) with Whop" : "Open checkout again", systemImage: "creditcard")
            } else {
                Text("Continue")
            }
        }
        .buttonStyle(.pill(.primary, fill: true))
        .disabled(working || (step == 0 && (pool < 5 || pool > 5000)))
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(
            LinearGradient(stops: [.init(color: Palette.surface.opacity(0), location: 0), .init(color: Palette.surface, location: 0.3)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    // MARK: Scope

    /// The street part of the address: "1234 Valencia St, San Francisco" gives "Valencia St".
    private var street: String? {
        guard let first = place?.address?.split(separator: ",").first else { return nil }
        let words = first.split(separator: " ").drop { $0.first?.isNumber == true }
        let name = words.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    private func scopeInfo(_ s: BountyScope) -> (title: String, detail: String, icon: String) {
        switch s {
        case .place: return (place?.name ?? "This place", "Only walkthroughs of this spot", "fork.knife")
        case .street: return (street ?? "\(store.home.neighborhood) block", "Anywhere along the street, about 350 m", "road.lanes")
        case .city: return ("All of \(store.home.city)", "Any walkthrough in the city", "building.2.fill")
        }
    }

    private func build() -> Bounty {
        let center = place?.coords ?? store.home.center
        let name = store.me.name.isEmpty ? "An explorer" : store.me.name
        let videos = max(3, min(20, pool / 10))
        let target: BountyTarget
        let radius: Double
        let title: String
        switch scope {
        case .place:
            target = BountyTarget(kind: "place", placeId: placeID, name: nil)
            radius = 120
            title = "Show everyone the inside of \(place?.name ?? "this place")"
        case .street:
            target = BountyTarget(kind: "area", placeId: nil, name: scopeInfo(.street).title)
            radius = 350
            title = "Walkthroughs along \(scopeInfo(.street).title)"
        case .city:
            target = BountyTarget(kind: "area", placeId: nil, name: store.home.city)
            radius = 3000
            title = "Walkthroughs anywhere in \(store.home.city)"
        }
        return Bounty(id: "draft", sponsor: name, logo: "star", color: "#2b59ff", title: title, target: target,
                      center: scope == .city ? store.home.center : center, radius: radius,
                      pool: Double(pool), split: "videos", firstBonus: 0, videos: videos, recorded: 0, days: 14,
                      crew: [], mine: nil, earned: nil)
    }

    // MARK: Actions

    private func back() {
        if live == nil && step > 0 && checkout == nil { step -= 1 } else { router.dismissCover() }
    }

    private func next() {
        if live != nil { return router.dismissCover() }
        if step < 2 {
            step += 1
            return
        }
        if checkout != nil {
            showPay = true
            return
        }
        working = true
        error = nil
        let b = build()
        Task {
            do {
                let made = try await Cloud.shared.createBountyCheckout(b)
                var stored = b
                stored.id = made.bountyID
                draft = stored
                checkout = made
                showPay = true
            } catch {
                self.error = error.localizedDescription
            }
            working = false
        }
    }

    /// While checkout is open, watch for the payment. Every few checks, ask Whop directly too.
    private func watch() async {
        guard checkout != nil else { return }
        var n = 0
        while live == nil && !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2))
            n += 1
            await check(sync: n % 3 == 0)
        }
    }

    private func check(sync: Bool) async {
        guard live == nil, let id = checkout?.bountyID, var b = draft else { return }
        let status = await Cloud.shared.bountyStatus(id, sync: sync)
        guard status == "paid", live == nil else { return }
        b.id = id
        store.addPaidBounty(b)
        await Cloud.shared.loadLiveBounties()
        showPay = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { live = b }
        Haptics.success()
    }
}

/// Whop's checkout page, inside the app.
struct SafariView: UIViewControllerRepresentable {
    var url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
