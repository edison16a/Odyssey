import MapKit
import SafariServices
import SwiftUI

enum BountyScope: String, CaseIterable, Identifiable {
    case place, street, city
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var radius: Double {
        switch self { case .place: return 120; case .street: return 350; case .city: return 3000 }
    }
}

/// One creation flow for map, place details, and business dashboard entry points.
struct SetBountyFlow: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var placeID: String?
    @State private var selected: Place?
    @State private var search = LocationSearch()
    @State private var amount = "100"
    @State private var scope: BountyScope = .place
    @State private var duration = 14
    @State private var maximum = 5
    @State private var requestID = UUID().uuidString
    @State private var checkout: Cloud.BountyCheckout?
    @State private var showPay = false
    @State private var showInfo = false
    @State private var working = false
    @State private var error: String?
    @State private var live: Bounty?
    @State private var checking = false
    @State private var initialLoad = false
    @State private var quote: Cloud.BountyQuote?

    private var pool: Double {
        guard let value = Double(amount), value.isFinite else { return 0 }
        return value
    }
    private var fee: Double { quote?.pool == pool ? (quote?.platformFee ?? 0) : (pool * 10).rounded() / 100 }
    private var total: Double { quote?.pool == pool ? (quote?.totalAmount ?? pool + fee) : pool + fee }
    private var valid: Bool { selected != nil && pool.isFinite && pool >= 5 && pool <= 5000 && abs(pool * 100 - (pool * 100).rounded()) < 0.00001 && (1...20).contains(maximum) }
    private var estimate: Double { floor(pool * 100 / Double(maximum)) / 100 }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: live == nil ? "Create a Bounty" : "Bounty Funded", back: { router.dismissCover() }) {
                Button { showInfo = true } label: { Image(systemName: "info.circle").frame(width: 44, height: 44) }
                    .accessibilityLabel("What are bounties?")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let live { success(live) } else { form }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Palette.surface)
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .sheet(isPresented: $showPay, onDismiss: { Task { await check(sync: true) } }) {
            if let url = checkout?.url { SafariView(url: url).ignoresSafeArea() }
        }
        .sheet(isPresented: $showInfo) { BountyInfoSheet() }
        .onAppear {
            guard !initialLoad else { return }
            initialLoad = true
            // Favour places around you (or wherever the map is looking) in the location search.
            search.region = store.worldMap.region
                ?? MKCoordinateRegion(center: store.here.location, latitudinalMeters: 40_000, longitudinalMeters: 40_000)
            selected = placeID.flatMap { store.place($0) }
            store.worldMap.bountyTarget = selected
        }
        .task(id: amount) {
            guard pool >= 5, pool <= 5000 else { quote = nil; return }
            let value = pool
            let result = await Cloud.shared.bountyQuote(value)
            if !Task.isCancelled, value == pool { quote = result }
        }
        .onChange(of: amount) { _, _ in if checkout == nil { requestID = UUID().uuidString } }
        .onChange(of: scope) { _, _ in if checkout == nil { requestID = UUID().uuidString } }
        .onChange(of: duration) { _, _ in if checkout == nil { requestID = UUID().uuidString } }
        .onChange(of: maximum) { _, _ in if checkout == nil { requestID = UUID().uuidString } }
        .task(id: checkout?.bountyID) { await watch() }
        .onChange(of: router.paidBountyID) { _, id in
            if id == checkout?.bountyID { Task { await check(sync: true) } }
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Fund exploration anywhere. Choose a location and invite explorers after payment confirmation.")
                .font(.subheadline).foregroundStyle(Palette.muted)
            locationSection
            amountSection
            durationSection
            explorersSection
            summarySection
            paymentNotice
        }
        .disabled(working || checkout != nil)
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            section("Bounty Location", icon: "mappin.and.ellipse")
            LocationSearchField(search: search) { place in
                selected = place
                store.worldMap.bountyTarget = place
                requestID = UUID().uuidString
            }
            Picker("Target type", selection: $scope) {
                ForEach(BountyScope.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented)
            if let selected {
                Text(selected.name).font(.headline)
                if let address = selected.address { Text(address).font(.caption).foregroundStyle(Palette.muted) }
                Text(String(format: "%.5f, %.5f · %@", selected.coords.lat, selected.coords.lng, scope.title))
                    .font(.caption.monospaced()).foregroundStyle(Palette.muted)
                Map(initialPosition: .region(MKCoordinateRegion(center: selected.coords.location,
                        latitudinalMeters: scope.radius * 4, longitudinalMeters: scope.radius * 4)), interactionModes: []) {
                    MapCircle(center: selected.coords.location, radius: scope.radius)
                        .foregroundStyle(Palette.accent.opacity(0.15)).stroke(Palette.accent, lineWidth: 2)
                    Marker(selected.name, coordinate: selected.coords.location).tint(Palette.accent)
                }
                .id("\(selected.id)-\(scope.rawValue)")
                .frame(height: 160).clipShape(RoundedRectangle(cornerRadius: 16))
                if scope != .place {
                    Text("Approximate coverage: \(Int(scope.radius)) m radius around this location. Search for the street or city center you want to cover.")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
            } else {
                Text("Search for a business, address, street, or city. You can fund a remote location without GPS.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            }
        }
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            section("Bounty Amount", icon: "dollarsign.circle")
            HStack {
                Text("$").font(.title2.bold())
                TextField("5–5,000", text: $amount).keyboardType(.decimalPad)
                    .font(.title2.bold()).accessibilityLabel("Bounty reward pool in dollars")
            }
            .padding(14).background(Palette.surface2, in: RoundedRectangle(cornerRadius: 14))
            HStack {
                ForEach([25, 50, 100, 250], id: \.self) { n in
                    Button("$\(n)") { amount = String(n) }
                        .font(.subheadline.bold()).frame(maxWidth: .infinity, minHeight: 44)
                        .background(amount == String(n) ? Palette.accent.opacity(0.12) : Palette.surface2, in: Capsule())
                }
            }
            Text("$5 to $5,000 reward pool, plus Odyssey's 10% platform fee.").font(.caption).foregroundStyle(Palette.muted)
            if pool < 5 || pool > 5000 { Text("Choose a pool between $5 and $5,000.").font(.caption).foregroundStyle(Palette.danger) }
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            section("Bounty Duration", icon: "clock")
            Picker("Duration", selection: $duration) {
                ForEach([1, 7, 14, 30], id: \.self) { Text("\($0) \($0 == 1 ? "day" : "days")").tag($0) }
            }.pickerStyle(.segmented)
            Text("Starts after payment is verified.").font(.caption).foregroundStyle(Palette.muted)
        }
    }

    private var explorersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            section("Maximum Explorers Rewarded", icon: "person.2")
            Stepper("\(maximum) \(maximum == 1 ? "explorer" : "explorers")", value: $maximum, in: 1...20)
            Text("Estimated reward: \(Format.money(estimate)) per explorer")
                .font(.subheadline.bold()).foregroundStyle(Palette.accent)
            Text("An estimated allocation of the funded pool. Contribution verification and actual explorer payouts are not yet available.")
                .font(.caption).foregroundStyle(Palette.muted)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            section("Create Your Bounty", icon: "checklist")
            row("Location", selected?.name ?? "Choose a location")
            row("Coverage", scope.title)
            row("Duration", "\(duration) \(duration == 1 ? "day" : "days")")
            row("Maximum explorers rewarded", "\(maximum)")
            Divider()
            row("Bounty pool", Format.money(pool))
            row("Platform fee (10%)", Format.money(fee))
            row("Total payment", Format.money(checkout?.amount ?? total))
            Text((checkout?.sandbox ?? quote?.sandbox) == true ? "Test payment · Whop sandbox" : "Payment total is verified by the server before checkout.")
                .font(.caption).foregroundStyle(Palette.muted).padding(.top, 6)
        }.card(padding: 16)
    }

    @ViewBuilder
    private var paymentNotice: some View {
        if let checkout {
            VStack(alignment: .leading, spacing: 10) {
                Text(checkout.sandbox ? "Test payment · Whop sandbox" : "Awaiting payment confirmation")
                    .font(.headline)
                Text("This bounty stays unpublished until Whop verifies payment. Closing checkout does not publish it.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            }
        }
    }

    private func success(_ bounty: Bounty) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Your bounty is live", systemImage: "checkmark.seal.fill").font(.title2.bold()).foregroundStyle(Palette.success)
            Text("Payment confirmed. The community can now discover this opportunity.")
            BountyCard(bounty: bounty) {
                store.worldMap.selectedPlace = bounty.target.place
                store.worldMap.fly(to: bounty.center, distance: max(1500, bounty.radius * 4))
                router.openWorldMap()
            }
            Text("Funding does not grant recording permission. Explorer verification and real-money payouts are future stages.")
                .font(.caption).foregroundStyle(Palette.muted)
        }
    }

    private func section(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon).font(.system(size: 17, weight: .bold)).foregroundStyle(Palette.ink)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(Palette.muted)
            Spacer(minLength: 12)
            Text(value).bold().multilineTextAlignment(.trailing)
        }.font(.subheadline).padding(.vertical, 5)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if let error { Text(error).font(.caption).foregroundStyle(Palette.danger) }
            Button { next() } label: {
                if working { ProgressView().tint(.white) }
                else { Label(live != nil ? "Done" : checkout == nil ? "Fund Bounty with Whop" : "Open Whop Checkout", systemImage: live == nil ? "creditcard" : "checkmark") }
            }
            .buttonStyle(.pill(.accent, fill: true))
            .disabled(working || (live == nil && checkout == nil && !valid))
            .accessibilityIdentifier("bounty.fund")
            if checkout != nil && live == nil {
                Button(checking ? "Checking payment…" : "Check payment status") { Task { await check(sync: true) } }
                    .font(.caption).disabled(checking)
            }
            Button("What are bounties?") { showInfo = true }.font(.caption)
        }
        .padding(.horizontal, 20).padding(.vertical, 10).background(.regularMaterial)
    }

    private func build(_ place: Place) -> Bounty {
        Bounty(id: requestID, sponsor: store.me.name.isEmpty ? "An explorer" : store.me.name,
               logo: "star", color: "#2b59ff", title: "Help document \(place.name)",
               target: BountyTarget(kind: scope.rawValue, placeId: scope == .place ? place.id : nil, name: place.name, place: place),
               center: place.coords, radius: scope.radius, pool: pool, split: "videos", firstBonus: 0,
               videos: maximum, recorded: 0, days: duration, crew: [], durationDays: duration, maxExplorers: maximum)
    }

    private func next() {
        if live != nil { router.dismissCover(); return }
        if checkout != nil { showPay = true; return }
        guard valid, let selected else { return }
        error = nil
        // Guests can pay without an account; their bounty is published without an owner.
        working = true
        Task {
            do {
                checkout = try await Cloud.shared.createBountyCheckout(build(selected))
                showPay = true
            } catch {
                self.error = error.localizedDescription
            }
            working = false
        }
    }

    private func watch() async {
        guard checkout != nil else { return }
        var count = 0
        while live == nil && !Task.isCancelled {
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            guard !Task.isCancelled else { return }
            count += 1
            await check(sync: count % 4 == 0)
        }
    }

    private func check(sync: Bool) async {
        guard !checking, live == nil, let id = checkout?.bountyID else { return }
        checking = true
        defer { checking = false }
        let status = await Cloud.shared.bountyStatus(id, sync: sync)
        guard status == "paid", let canonical = await Cloud.shared.paidBounty(id), live == nil else { return }
        store.addPaidBounty(canonical)
        await Cloud.shared.loadLiveBounties()
        showPay = false
        live = canonical
        Haptics.success()
    }
}

struct SafariView: UIViewControllerRepresentable {
    var url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
