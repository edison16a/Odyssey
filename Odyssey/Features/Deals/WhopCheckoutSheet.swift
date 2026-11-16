//
//  WhopCheckoutSheet.swift
//  Odyssey
//
//  The mock Whop checkout. It reads like a real one: an order summary, a
//  sandbox card for paid deals and a Pay button. Paying waits a moment,
//  claims the deal through Convex and lands on a ticket with the discount
//  code, a QR code of it and a copy button. A deal you already claimed
//  opens straight on its ticket.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import SwiftUI
import UIKit

struct WhopCheckoutSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(ToastCenter.self) private var toast
    @Environment(\.dismiss) private var dismiss
    var deal: Deal

    enum Phase: Equatable { case review, paying, done(String) }
    @State private var phase: Phase = .review
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Palette.line)
            ScrollView(showsIndicators: false) {
                switch phase {
                case .review, .paying: review
                case .done(let code): DealTicket(deal: deal, code: code, place: store.place(deal.placeID))
                }
            }
        }
        .background(Palette.surface)
        .onAppear {
            if let code = store.state.claimedDeals[deal.id] { phase = .done(code) }
        }
        .interactiveDismissDisabled(phase == .paying)
    }

    private var header: some View {
        HStack(spacing: 10) {
            WhopMark(size: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text("Checkout").font(.system(size: 17, weight: .heavy)).foregroundStyle(Palette.ink)
                Text("powered by Whop").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.muted)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold))
                Text("Secure").font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(Palette.success)
            IconButton(icon: "close", kind: .soft, size: 32, label: "Close") { dismiss() }
                .disabled(phase == .paying)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 14)
    }

    private var review: some View {
        let paying = phase == .paying
        return VStack(alignment: .leading, spacing: 16) {
            // Order summary
            VStack(alignment: .leading, spacing: 12) {
                Text("ORDER SUMMARY").font(.system(size: 11, weight: .heavy)).tracking(0.6).foregroundStyle(Palette.muted)
                HStack(alignment: .top, spacing: 12) {
                    if let place = store.place(deal.placeID) {
                        PlacePhoto(place: place)
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(deal.title).font(.system(size: 16, weight: .heavy)).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(deal.placeName.isEmpty ? (store.place(deal.placeID)?.name ?? "") : deal.placeName)
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink2)
                        if !deal.detail.isEmpty {
                            Text(deal.detail).font(.system(size: 12)).foregroundStyle(Palette.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                    if deal.percent > 0 { DealPercentBadge(deal: deal, size: 11) }
                }
                Divider().overlay(Palette.line)
                row("Price", deal.priceText)
                if deal.isFree {
                    row("Your coins", store.state.wallet.coins.formatted())
                    row("After", max(0, store.state.wallet.coins - deal.coinPrice).formatted())
                } else {
                    row("Fees", "$0.00")
                }
                HStack {
                    Text("Total").font(.system(size: 16, weight: .heavy))
                    Spacer()
                    Text(deal.priceText).font(.system(size: 18, weight: .heavy)).monospacedDigit()
                }
                .foregroundStyle(Palette.ink)
                HStack(spacing: 6) {
                    Image(systemName: "flask.fill").font(.system(size: 10, weight: .bold))
                    Text("Sandbox · test mode").font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(Color(hex: "#9a6a00"))
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(Palette.goldSoft, in: Capsule())
            }
            .card(padding: 16, radius: Radius.md)

            if !deal.isFree {
                VStack(alignment: .leading, spacing: 10) {
                    Text("PAYMENT").font(.system(size: 11, weight: .heavy)).tracking(0.6).foregroundStyle(Palette.muted)
                    HStack(spacing: 12) {
                        Text("VISA")
                            .font(.system(size: 11, weight: .black)).italic()
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 28)
                            .background(Color(hex: "#1a1f71"), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Visa •••• 4242 (test)").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                            Text("Expires 12/30").font(.system(size: 12)).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundStyle(Palette.success)
                    }
                    .card(padding: 14, radius: Radius.md)
                }
            }

            Text("\(deal.remaining) left · \(DealStyle.ends(deal.expiresAt)). Your code works once at \(deal.placeName.isEmpty ? "the counter" : deal.placeName).")
                .font(.system(size: 12)).foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)

            if let error {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error).font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Palette.danger)
            }

            if deal.isFree && !canAfford {
                Text("You need \((deal.coinPrice - store.state.wallet.coins).formatted()) more coins. Check in somewhere new to earn them.")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: pay) {
                HStack(spacing: 10) {
                    if paying {
                        ProgressView().tint(.white)
                        Text("Processing…").font(.system(size: 17, weight: .heavy))
                    } else {
                        if deal.isFree { CoinIcon(size: 18) } else { Image(systemName: "lock.fill").font(.system(size: 15, weight: .bold)) }
                        Text(deal.isFree ? "Buy for \(deal.priceText)" : "Pay \(deal.priceText)").font(.system(size: 17, weight: .heavy))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(DealStyle.whop, in: Capsule())
                .shadow(color: DealStyle.whop.opacity(0.35), radius: 10, y: 4)
            }
            .buttonStyle(PressStyle(scale: 0.97))
            .disabled(paying || !canAfford)
            .opacity(canAfford ? 1 : 0.45)

            HStack(spacing: 6) {
                WhopMark(size: 14)
                Text(deal.isFree ? "Coins are taken from your Odyssey balance. Code issued by Whop."
                                 : "Payments by Whop. No real money moves in test mode.")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 14)).foregroundStyle(Palette.muted)
            Spacer()
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink).monospacedDigit()
        }
    }

    private var canAfford: Bool { !deal.isFree || store.state.wallet.coins >= deal.coinPrice }

    private func pay() {
        guard phase == .review, canAfford else { return }
        Haptics.tap()
        error = nil
        withAnimation(.easeOut(duration: 0.2)) { phase = .paying }
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            do {
                let code = try await Cloud.shared.claimDeal(deal)
                if deal.isFree {
                    let price = deal.coinPrice
                    store.update { s in s.wallet.coins = max(0, s.wallet.coins - price) }
                    toast.show("-\(price.formatted()) coins", icon: "check")
                }
                Haptics.success()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { phase = .done(code) }
            } catch {
                Haptics.warning()
                withAnimation { phase = .review }
                self.error = "Checkout didn't go through. Try again."
                toast.show("Couldn't claim the deal. Try again.", icon: "exclamationmark.triangle.fill")
            }
        }
    }
}

/// The success screen: a check, the code on a ticket, its QR and a copy button.
struct DealTicket: View {
    @Environment(ToastCenter.self) private var toast
    var deal: Deal
    var code: String
    var place: Place?
    @State private var pop = false
    @State private var copied = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                DealConfetti()
                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(Palette.success, in: Circle())
                    .overlay(Circle().strokeBorder(.white, lineWidth: 4))
                    .shadow(color: Palette.success.opacity(0.45), radius: 14, y: 6)
                    .scaleEffect(pop ? 1 : 0.3)
                    .opacity(pop ? 1 : 0)
            }
            .frame(height: 120)
            VStack(spacing: 4) {
                Text(deal.isFree ? "Deal bought!" : "Payment complete!")
                    .font(.system(size: 24, weight: .heavy)).tracking(-0.5).foregroundStyle(Palette.ink)
                Text(deal.title + (deal.placeName.isEmpty ? "" : " at \(deal.placeName)"))
                    .font(.system(size: 14)).foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
            }

            // The ticket
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text("DISCOUNT CODE").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(.white.opacity(0.7))
                    Text(code)
                        .font(.system(size: 30, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .textSelection(.enabled)
                    if deal.percent > 0 {
                        Text(deal.percent >= 100 ? "Free" : "\(deal.percent)% off")
                            .font(.system(size: 13, weight: .heavy)).foregroundStyle(DealStyle.whop)
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                TicketPerforation()
                    .stroke(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    .frame(height: 1)
                    .padding(.horizontal, 18)
                VStack(spacing: 10) {
                    if let image = DealQR.image(code) {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                            .padding(10)
                            .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    Text("Show this at the counter").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.ink, in: TicketShape())
            .shadow(color: .black.opacity(0.18), radius: 16, y: 8)

            Button {
                UIPasteboard.general.string = code
                Haptics.success()
                withAnimation { copied = true }
                toast.show("Code copied", icon: "doc.on.doc")
            } label: {
                Label(copied ? "Copied" : "Copy code", systemImage: copied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.pill(.primary, fill: true))

            VStack(spacing: 4) {
                Text("Receipt \(receiptID)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.muted)
                HStack(spacing: 5) {
                    WhopMark(size: 12)
                    Text("Processed by Whop · Sandbox").font(.system(size: 11)).foregroundStyle(Palette.faint)
                }
            }
        }
        .padding(20)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(0.05)) { pop = true }
        }
    }

    /// A stable fake receipt id made from the code.
    private var receiptID: String {
        "whop_rcpt_" + code.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

/// A QR code for the discount code, drawn with CoreImage.
enum DealQR {
    static func image(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// A rounded ticket with a notch on each side at the perforation.
struct TicketShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 20, notch: CGFloat = 12
        // The perforation sits under the code block, about a third of the way down.
        let y = rect.minY + rect.height * 0.335
        var notches = Path()
        notches.addEllipse(in: CGRect(x: rect.minX - notch, y: y - notch, width: notch * 2, height: notch * 2))
        notches.addEllipse(in: CGRect(x: rect.maxX - notch, y: y - notch, width: notch * 2, height: notch * 2))
        return Path(roundedRect: rect, cornerRadius: r, style: .continuous).subtracting(notches)
    }
}

/// The dashed line across the ticket.
struct TicketPerforation: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

/// A one-shot burst of coloured bits behind the check.
struct DealConfetti: View {
    @State private var burst = false
    private let colors: [Color] = [DealStyle.whop, Palette.gold, Palette.accent, Palette.success, Palette.rare, Palette.flame]

    var body: some View {
        ZStack {
            ForEach(0..<22, id: \.self) { i in
                let angle = Double(i) / 22 * 2 * .pi + Double(i % 3) * 0.2
                let distance: CGFloat = burst ? CGFloat(70 + (i * 37) % 50) : 0
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(colors[i % colors.count])
                    .frame(width: i % 2 == 0 ? 7 : 5, height: i % 2 == 0 ? 11 : 6)
                    .rotationEffect(.degrees(burst ? Double(i * 47) : 0))
                    .offset(x: cos(angle) * distance, y: sin(angle) * distance + (burst ? 14 : 0))
                    .opacity(burst ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.3).delay(0.1)) { burst = true }
        }
        .allowsHitTesting(false)
    }
}
