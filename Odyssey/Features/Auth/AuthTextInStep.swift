//
//  AuthTextInStep.swift
//  Odyssey
//
//  Phone sign-in by texting. Odyssey shows a 6 digit code and you text it to
//  Odyssey's iMessage line; Keiki tells Convex which number sent it, and the
//  app signs you in as that number. No code ever has to be typed back.
//  The server side is convex/phoneAuth.ts.
//

import Foundation
import SwiftUI
import UIKit

struct AuthTextInStep: View {
    @Environment(AppStore.self) private var store
    var back: () -> Void
    var useEmail: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var login: Cloud.TextInLogin?
    @State private var state: Phase = .starting
    @State private var failure: String?

    enum Phase { case starting, waiting, verifying, verified, expired }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                IconButton(icon: "back", kind: .dark, label: "Back", action: back)
                Spacer()
            }
            Spacer()
            Text("Sign in with your phone").font(.system(size: 28, weight: .bold)).tracking(-0.8)
            Text("Text this code to Odyssey. We sign you in as the number it comes from, so there is nothing to type back.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.72))
                .padding(.bottom, 8)
            codeCard
            statusLine
            Button(state == .expired ? "Get a new code" : "Text code to Odyssey") {
                if state == .expired { Task { await begin() } } else { textIt() }
            }
            .buttonStyle(AuthBigButtonStyle())
            .disabled(state == .starting || state == .verifying || state == .verified
                      || (state == .waiting && login?.line == nil))
            Button("Use email instead", action: useEmail)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .task { await begin() }
        .task(id: login?.nonce) { await watch() }
    }

    private var codeCard: some View {
        Text(login.map { spaced($0.code) } ?? "••• •••")
            .font(.system(size: 34, weight: .bold, design: .monospaced))
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).strokeBorder(.white.opacity(0.2)))
            .opacity(state == .expired ? 0.4 : 1)
    }

    @ViewBuilder private var statusLine: some View {
        HStack(spacing: 8) {
            switch state {
            case .starting:
                ProgressView().tint(.white).controlSize(.small)
                Text("Getting your code")
            case .waiting:
                if let failure {
                    Text(failure).foregroundStyle(Color(hex: "#ffb4a8"))
                } else if login?.line == nil {
                    Text("Phone sign-in is not switched on yet. Use email for now.").foregroundStyle(Color(hex: "#ffb4a8"))
                } else {
                    ProgressView().tint(.white).controlSize(.small)
                    Text("Waiting for your text")
                }
            case .verifying:
                ProgressView().tint(.white).controlSize(.small)
                Text("Signing you in")
            case .verified:
                Image(systemName: "checkmark").font(.system(size: 15, weight: .bold))
                Text("Signed in")
            case .expired:
                Text(failure ?? "That code expired.").foregroundStyle(Color(hex: "#ffb4a8"))
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(state == .verified ? Color(hex: "#6ee7a8") : .white.opacity(0.8))
        .frame(minHeight: 22)
    }

    private func spaced(_ code: String) -> String {
        code.count == 6 ? String(code.prefix(3)) + " " + String(code.suffix(3)) : code
    }

    private func begin() async {
        state = .starting
        failure = nil
        do {
            login = try await Cloud.shared.startTextIn()
            state = .waiting
        } catch {
            failure = error.localizedDescription
            state = .expired
        }
    }

    /// Open Messages with the code already written to Odyssey's line.
    private func textIt() {
        guard let login, let line = login.line else { return }
        // The (K-Y6BRV2) tag routes the first text on Keiki's shared line to the Odyssey agent.
        let text = "Odyssey sign-in code \(login.code) (K-Y6BRV2)"
        let body = text.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? text
        if let url = URL(string: "sms:\(line)&body=\(body)") { openURL(url) }
    }

    /// Check every two seconds until the text arrives or the code expires.
    private func watch() async {
        guard let nonce = login?.nonce else { return }
        while !Task.isCancelled, state == .waiting {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, state == .waiting else { return }
            switch await Cloud.shared.textInStatus(nonce: nonce) {
            case "confirmed": await finish(nonce)
            case "expired", "used": state = .expired
            default: break
            }
        }
    }

    private func finish(_ nonce: String) async {
        state = .verifying
        do {
            try await Cloud.shared.verifyTextIn(nonce: nonce)
        } catch {
            failure = error.localizedDescription
            state = .expired
            Haptics.warning()
            return
        }
        state = .verified
        Haptics.success()
        try? await Task.sleep(for: .milliseconds(600))
        store.update { s in s.session.signedIn = true }
    }
}
