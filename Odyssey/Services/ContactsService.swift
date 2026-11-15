//
//  ContactsService.swift
//  Odyssey
//
//  Reads the address book (only after you allow it) to find friends.
//  Phone numbers are cut to digits (the last 10, so "+1 (555) 564-8583" and
//  "555-564-8583" agree) and emails are lowercased, then each one is hashed
//  with SHA-256 on the phone. Only those hashes go to Convex
//  (contacts:match), which answers with the explorers they belong to.
//  Contacts are kept in memory for this screen and never uploaded.
//

import Contacts
import CryptoKit
import Foundation
import Observation
import UIKit

/// One person from the address book.
nonisolated struct DeviceContact: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    /// What to show under the name: their first phone number or email.
    var detail: String
    /// Their first phone number as written, for the Messages composer.
    var phone: String?
    var phones: [String]
    var emails: [String]
    var thumbnail: Data?
    var hashes: [String]

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }.joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }
}

/// An Odyssey explorer that one or more of your contacts turned out to be.
nonisolated struct ContactMatch: Hashable, Sendable {
    var userId: String
    /// Set for the seeded demo explorers ("nina"), so the app's own people list applies.
    var demoId: String?
    var name: String
    var handle: String
    var city: String
    var avatarPath: String?
    var avatarURL: URL?
    var hashes: [String]

    /// The id friendships use: a demo explorer's seed id, otherwise the user id.
    var friendKey: String { demoId ?? userId }

    init?(_ row: [String: Any]) {
        guard let userId = row["userId"] as? String, let name = row["name"] as? String else { return nil }
        self.userId = userId
        demoId = row["demoId"] as? String
        self.name = name
        handle = row["handle"] as? String ?? ""
        city = row["city"] as? String ?? ""
        avatarPath = row["avatarPath"] as? String
        avatarURL = (row["avatarUrl"] as? String).flatMap(URL.init(string:))
        hashes = row["hashes"] as? [String] ?? []
    }
}

@Observable
final class ContactsService {
    static let shared = ContactsService()

    enum Access { case notDetermined, denied, authorized }

    private(set) var access: Access = ContactsService.currentAccess()
    private(set) var contacts: [DeviceContact] = []
    /// Explorers found among your contacts, keyed by friend key.
    private(set) var matches: [ContactMatch] = []
    /// Contact ids that belong to a matched explorer.
    private(set) var matchedContactIDs: Set<String> = []
    private(set) var loading = false
    private(set) var loaded = false
    /// False when matching could not run (signed out or offline).
    private(set) var matchingRan = false

    @ObservationIgnored private let store = CNContactStore()

    private init() {}

    /// Ask for access, then load. Shows the system prompt the first time only.
    func connect() async {
        do {
            _ = try await store.requestAccess(for: .contacts)
        } catch {
            // Denied or restricted: the access check below says which.
        }
        refreshAccess()
        if access == .authorized { await load() }
    }

    /// Pick up a change made in Settings.
    func refreshAccess() {
        access = Self.currentAccess()
    }

    /// Read the address book and match it. Safe to call again to refresh.
    func load() async {
        refreshAccess()
        guard access == .authorized, !loading else { return }
        loading = true
        defer { loading = false }
        let read = await Task.detached(priority: .userInitiated) { Self.readAll() }.value
        contacts = read
        loaded = true
        await match()
    }

    private func match() async {
        var owners: [String: [String]] = [:]
        for contact in contacts {
            for hash in contact.hashes { owners[hash, default: []].append(contact.id) }
        }
        guard Cloud.shared.signedIn, !owners.isEmpty else {
            matches = []
            matchedContactIDs = []
            matchingRan = false
            return
        }
        do {
            let found = try await Cloud.shared.matchContacts(hashes: Array(owners.keys))
            matches = found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            matchedContactIDs = Set(found.flatMap { $0.hashes.flatMap { owners[$0] ?? [] } })
            matchingRan = true
        } catch {
            matchingRan = false
        }
    }

    /// The contact a match came from, for their photo and name in your book.
    func contact(for match: ContactMatch) -> DeviceContact? {
        let hashes = Set(match.hashes)
        return contacts.first { !hashes.isDisjoint(with: $0.hashes) }
    }

    // MARK: Reading

    private nonisolated static func currentAccess() -> Access {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined: return .notDetermined
        case .authorized, .limited: return .authorized
        default: return .denied
        }
    }

    private nonisolated static func readAll() -> [DeviceContact] {
        let keys: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .userDefault
        var out: [DeviceContact] = []
        try? CNContactStore().enumerateContacts(with: request) { c, _ in
            let rawPhones = c.phoneNumbers.map(\.value.stringValue)
            let rawEmails = c.emailAddresses.map { $0.value as String }
            let phones = unique(rawPhones.compactMap(normalizePhone))
            let emails = unique(rawEmails.compactMap(normalizeEmail))
            guard !phones.isEmpty || !emails.isEmpty else { return }
            let full = CNContactFormatter.string(from: c, style: .fullName)?.trimmingCharacters(in: .whitespaces) ?? ""
            let name = !full.isEmpty ? full : (!c.organizationName.isEmpty ? c.organizationName : (rawEmails.first ?? rawPhones.first ?? ""))
            guard !name.isEmpty else { return }
            out.append(DeviceContact(
                id: c.identifier, name: name, detail: rawPhones.first ?? rawEmails.first ?? "",
                phone: rawPhones.first, phones: phones, emails: emails, thumbnail: c.thumbnailImageData,
                hashes: phones.map(sha256) + emails.map(sha256)))
        }
        return out.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // MARK: Normalizing and hashing (the server does the same, see convex/contacts.ts)

    /// Digits only, the last 10 of longer numbers (drops a +1 country code). Too short to be a phone: nil.
    nonisolated static func normalizePhone(_ raw: String) -> String? {
        let digits = raw.filter(\.isASCII).filter(\.isNumber)
        guard digits.count >= 7 else { return nil }
        return String(digits.suffix(10))
    }

    nonisolated static func normalizeEmail(_ raw: String) -> String? {
        let email = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return email.contains("@") ? email : nil
    }

    nonisolated static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private nonisolated static func unique(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.filter { seen.insert($0).inserted }
    }
}
