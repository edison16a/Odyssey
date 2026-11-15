//
//  AuthEmailStep.swift
//  Odyssey
//
//  Email step. Odyssey signs in with a one time code, so there is no password
//  field and the same screen works for new and returning people. Most people
//  use Gmail, so "@gmail.com" trails what they type and they only enter their
//  name. Typing "@" drops the suffix for any other domain, and tapping the
//  suffix turns it into real text. Ported from features/auth/email.js.
//

import Foundation
import SwiftUI
import UIKit

struct AuthEmailStep: View {
    @Binding var email: String
    var returning: Bool
    var back: () -> Void
    var send: () -> Void

    @State private var typed = ""
    @FocusState private var focused: Bool
    private let domain = "@gmail.com"

    /// The full address: what they typed, plus the suffix if they kept it.
    private var full: String {
        let value = typed.trimmingCharacters(in: .whitespaces)
        if value.isEmpty { return "" }
        return value.contains("@") ? value : value + domain
    }

    private var valid: Bool {
        full.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]{2,}$"#, options: .regularExpression) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                IconButton(icon: "back", kind: .dark, label: "Back", action: back)
                Spacer()
            }
            Spacer()
            Text(returning ? "Welcome back" : "Use email to sign in")
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.8)
            Text("We will send a one-time code to your inbox. No passwords to remember.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.72))
                .padding(.bottom, 8)
            field
            Button("Send code") {
                email = full
                send()
            }
            .buttonStyle(AuthBigButtonStyle())
            .disabled(!valid)
            Text("By continuing you agree to the Terms and Privacy Policy.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .onAppear {
            typed = email.hasSuffix(domain) ? String(email.dropLast(domain.count)) : email
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { focused = true }
        }
    }

    private var field: some View {
        HStack(spacing: 10) {
            Image(systemName: "envelope").font(.system(size: 18)).foregroundStyle(.white.opacity(0.6))
            HStack(spacing: 0) {
                TextField("", text: $typed, prompt: Text("yourname").foregroundColor(.white.opacity(0.45)))
                    .font(.system(size: 17))
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .focused($focused)
                    .fixedSize(horizontal: !typed.contains("@"), vertical: false)
                    .onSubmit {
                        if valid {
                            email = full
                            send()
                        }
                    }
                if !typed.contains("@") {
                    Button(domain) {
                        typed = typed.trimmingCharacters(in: .whitespaces) + domain
                    }
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 56)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }
}
