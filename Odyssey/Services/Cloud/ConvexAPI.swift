//
//  ConvexAPI.swift
//  Odyssey
//
//  A small client for the Convex HTTP API: queries, mutations and actions
//  by name ("adventures:checkIn"), file uploads to Convex storage, and the
//  Convex Auth tokens that sign every call. No SDK needed, just URLSession.
//
//  Calls with no signed-in session still work for public functions.
//

import Foundation
import Security

enum ConvexError: LocalizedError {
    case server(String)
    case badResponse
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        case .badResponse: return "Odyssey's server sent something unexpected."
        case .notSignedIn: return "Sign in to sync with Odyssey."
        }
    }
}

/// Where the backend lives. Set ConvexURL in Info.plist to point at another deployment.
enum ConvexConfig {
    static let url: URL = {
        if let s = Bundle.main.object(forInfoDictionaryKey: "ConvexURL") as? String, let url = URL(string: s), !s.isEmpty {
            return url
        }
        return URL(string: "https://impressive-mosquito-265.convex.cloud")!
    }()
}

/// The access and refresh tokens from Convex Auth, kept in the Keychain.
struct AuthTokens: Codable, Equatable {
    var token: String
    var refreshToken: String

    /// Seconds since 1970 when the access token stops working, read from the JWT.
    var expiresAt: Double {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return 0 }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload += "=" }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? Double else { return 0 }
        return exp
    }
}

enum TokenStore {
    private static let service = "app.odyssey.convex"
    private static let account = "tokens"

    static func load() -> AuthTokens? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(AuthTokens.self, from: data)
    }

    static func save(_ tokens: AuthTokens?) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        guard let tokens, let data = try? JSONEncoder().encode(tokens) else { return }
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
}

final class ConvexAPI {
    enum Kind: String { case query, mutation, action }

    static let shared = ConvexAPI()

    private(set) var tokens: AuthTokens? = TokenStore.load()
    var isSignedIn: Bool { tokens != nil }
    /// Called when the session ends on the server (refresh token gone).
    var onSignedOut: (() -> Void)?

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()
    private var refreshing: Task<Bool, Never>?

    // MARK: Functions

    func query(_ path: String, _ args: [String: Any] = [:]) async throws -> Any {
        try await call(.query, path, args)
    }

    @discardableResult
    func mutation(_ path: String, _ args: [String: Any] = [:]) async throws -> Any {
        try await call(.mutation, path, args)
    }

    @discardableResult
    func action(_ path: String, _ args: [String: Any] = [:], timeout: TimeInterval = 30) async throws -> Any {
        try await call(.action, path, args, timeout: timeout)
    }

    func call(_ kind: Kind, _ path: String, _ args: [String: Any], timeout: TimeInterval = 20, retried: Bool = false) async throws -> Any {
        if let tokens, tokens.expiresAt > 0, tokens.expiresAt < Date().timeIntervalSince1970 + 30 {
            _ = await refresh()
        }
        var request = URLRequest(url: ConvexConfig.url.appendingPathComponent("api/\(kind.rawValue)"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = tokens?.token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let body: [String: Any] = ["path": path, "args": Self.clean(args), "format": "json"]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [String: Any] else {
            throw ConvexError.server("HTTP \(status): \(String(data: data, encoding: .utf8)?.prefix(200) ?? "")")
        }
        if json["status"] as? String == "success" { return json["value"] ?? NSNull() }
        let message = json["errorMessage"] as? String ?? json["message"] as? String ?? "HTTP \(status)"
        // An expired or revoked access token: refresh once and try again.
        if !retried, tokens != nil, Self.looksUnauthenticated(message, status: status), await refresh() {
            return try await call(kind, path, args, timeout: timeout, retried: true)
        }
        throw ConvexError.server(Self.friendly(message))
    }

    // MARK: Files

    /// Upload bytes to Convex storage and return the storage id.
    func upload(_ data: Data, contentType: String) async throws -> String {
        guard let uploadURL = try await mutation("files:generateUploadUrl") as? String, let url = URL(string: uploadURL) else {
            throw ConvexError.badResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        let (body, response) = try await session.upload(for: request, from: data)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: body) as? [String: Any],
              let storageId = json["storageId"] as? String else { throw ConvexError.badResponse }
        return storageId
    }

    // MARK: Auth (Convex Auth's auth:signIn action)

    /// Step one: email a one-time code.
    func sendCode(email: String) async throws {
        _ = try await call(.action, "auth:signIn", ["provider": "email-otp", "params": ["email": email]])
    }

    /// Step two: trade the code for a session.
    func verify(email: String, code: String) async throws {
        try await signIn(provider: "email-otp", params: ["email": email, "code": code],
                         failure: "That code did not work. Check it and try again.")
    }

    /// Text-in sign-in: the server already knows the number that texted the code.
    func verifyTextIn(nonce: String) async throws {
        try await signIn(provider: "phone-text", params: ["nonce": nonce],
                         failure: "That sign-in expired. Get a new code and try again.")
    }

    private func signIn(provider: String, params: [String: Any], failure: String) async throws {
        let value = try await call(.action, "auth:signIn", ["provider": provider, "params": params])
        guard let dict = value as? [String: Any], let t = dict["tokens"] as? [String: Any],
              let token = t["token"] as? String, let refreshToken = t["refreshToken"] as? String else {
            throw ConvexError.server(failure)
        }
        setTokens(AuthTokens(token: token, refreshToken: refreshToken))
    }

    func signOut() async {
        if tokens != nil { _ = try? await call(.action, "auth:signOut", [:], retried: true) }
        setTokens(nil)
    }

    private func setTokens(_ next: AuthTokens?) {
        tokens = next
        TokenStore.save(next)
    }

    /// Swap the refresh token for a fresh access token. One refresh at a time.
    private func refresh() async -> Bool {
        if let refreshing { return await refreshing.value }
        guard let refreshToken = tokens?.refreshToken else { return false }
        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }
            var request = URLRequest(url: ConvexConfig.url.appendingPathComponent("api/action"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: [
                "path": "auth:signIn", "args": ["refreshToken": refreshToken], "format": "json",
            ])
            guard let (data, _) = try? await self.session.data(for: request),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
            if json["status"] as? String == "success",
               let value = json["value"] as? [String: Any], let t = value["tokens"] as? [String: Any],
               let token = t["token"] as? String, let next = t["refreshToken"] as? String {
                self.setTokens(AuthTokens(token: token, refreshToken: next))
                return true
            }
            // The server answered and said no: the session is over.
            if json["status"] as? String == "success" || json["status"] as? String == "error" {
                self.setTokens(nil)
                self.onSignedOut?()
            }
            return false
        }
        refreshing = task
        let ok = await task.value
        refreshing = nil
        return ok
    }

    // MARK: Helpers

    private static func looksUnauthenticated(_ message: String, status: Int) -> Bool {
        status == 401 || message.contains("Not signed in") || message.localizedCaseInsensitiveContains("unauthenticated")
            || message.localizedCaseInsensitiveContains("token")
    }

    /// Convex error messages carry a request id and stack prefix; keep the human part.
    private static func friendly(_ message: String) -> String {
        if let range = message.range(of: "Uncaught Error: ") {
            let rest = message[range.upperBound...]
            return String(rest.split(separator: "\n").first ?? Substring(rest))
        }
        return message
    }

    /// Convex rejects nulls for optional fields and NaN numbers; drop them.
    static func clean(_ value: Any) -> Any {
        switch value {
        case let dict as [String: Any]:
            var out: [String: Any] = [:]
            for (k, v) in dict {
                if v is NSNull { continue }
                if let d = v as? Double, !d.isFinite { continue }
                out[k] = clean(v)
            }
            return out
        case let array as [Any]:
            return array.map(clean)
        default:
            return value
        }
    }
}
