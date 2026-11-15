//
//  AuthOTPStep.swift
//  Odyssey
//
//  One time code step. Six boxes fill as you type (one hidden field holds
//  the code, so pasting and the keyboard's suggested code both work) and it
//  verifies as soon as the last digit lands. "Paste code from Mail" fills it
//  the way iOS offers a code from an incoming message. Convex Auth checks the code.
//  Ported from features/auth/otp.js.
//

import Foundation
import SwiftUI
import UIKit

struct AuthOTPStep: View {
    @Environment(AppStore.self) private var store
    @Environment(ToastCenter.self) private var toast
    var email: String
    var back: () -> Void

    @State private var code = ""
    @State private var status: Status = .idle
    @State private var resendIn = 30
    @FocusState private var focused: Bool

    enum Status { case idle, verifying, verified }
    @State private var failure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                IconButton(icon: "back", kind: .dark, label: "Back", action: back)
                Spacer()
            }
            Spacer()
            Text("Check your email").font(.system(size: 28, weight: .bold)).tracking(-0.8)
            (Text("Enter the 6 digit code we sent to ") + Text(email).bold() + Text("."))
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.72))
                .padding(.bottom, 8)
            boxes
            statusLine
            HStack {
                Button { fill(UIPasteboard.general.string ?? "") } label: {
                    Label("Paste code from Mail", systemImage: "envelope")
                }
                .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Button(resendIn > 0 ? "Resend in 0:" + String(format: "%02d", resendIn) : "Resend code") {
                    resendIn = 30
                    Task {
                        do {
                            try await Cloud.shared.sendCode(email: email)
                            toast.show("New code sent", icon: "mail")
                        } catch {
                            toast.show(error.localizedDescription, icon: "mail")
                        }
                    }
                }
                .foregroundStyle(.white.opacity(resendIn > 0 ? 0.4 : 0.85))
                .disabled(resendIn > 0)
            }
            .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { focused = true } }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if resendIn > 0 { resendIn -= 1 }
            }
        }
    }

    private var boxes: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .opacity(0.01)
                .disabled(status != .idle)
                .onChange(of: code) { _, value in
                    let digits = String(value.filter(\.isNumber).prefix(6))
                    if digits != value { code = digits }
                    if digits.count == 6 { verify() }
                }
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { i in box(i) }
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }

    private func box(_ i: Int) -> some View {
        let chars = Array(code)
        let active = focused && status == .idle && i == min(chars.count, 5)
        return Text(i < chars.count ? String(chars[i]) : "")
            .font(.system(size: 24, weight: .bold))
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(.white.opacity(active ? 0.18 : 0.12), in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .strokeBorder(.white.opacity(active ? 1 : 0.2), lineWidth: active ? 2 : 1))
    }

    @ViewBuilder private var statusLine: some View {
        HStack(spacing: 8) {
            switch status {
            case .idle:
                if let failure { Text(failure).foregroundStyle(Color(hex: "#ffb4a8")) }
            case .verifying:
                ProgressView().tint(.white).controlSize(.small)
                Text("Verifying")
            case .verified:
                Image(systemName: "checkmark").font(.system(size: 15, weight: .bold))
                Text("Verified")
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(status == .verified ? Color(hex: "#6ee7a8") : .white.opacity(0.8))
        .frame(minHeight: 22)
    }

    private func fill(_ text: String) {
        code = String(text.filter(\.isNumber).prefix(6))
    }

    private func verify() {
        guard status == .idle else { return }
        focused = false
        failure = nil
        status = .verifying
        Task {
            do {
                try await Cloud.shared.verify(email: email, code: code)
            } catch {
                status = .idle
                failure = error.localizedDescription
                code = ""
                Haptics.warning()
                focused = true
                return
            }
            status = .verified
            Haptics.success()
            try? await Task.sleep(for: .milliseconds(600))
            store.update { s in
                s.session.signedIn = true
                s.session.email = email
            }
        }
    }
}
