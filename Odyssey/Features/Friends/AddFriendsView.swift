//
//  AddFriendsView.swift
//  Odyssey
//
//  Find friends. Answer requests, connect your contacts to see who is
//  already on Odyssey (numbers and emails are hashed on the phone before
//  matching, see ContactsService) and invite everyone else, search public
//  explorers by handle or name and pick from explorers near you.
//

import Foundation
import MessageUI
import SwiftUI

struct AddFriendsView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toast
    @Environment(RewardPopCenter.self) private var pop
    @Environment(\.scenePhase) private var scenePhase

    @State private var contacts = ContactsService.shared
    @State private var query = ""
    @State private var invited: Set<String> = []
    @State private var inviting: InviteRequest?

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Add friends", back: { router.pop() })
            FieldBox(icon: "search") {
                TextField("Search names, @handles or contacts", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, Space.s5)
            .padding(.bottom, 4)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if searching {
                        results
                    } else {
                        suggestions
                    }
                }
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .background(Palette.surface)
        .task {
            contacts.refreshAccess()
            if contacts.access == .authorized && !contacts.loaded { await contacts.load() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            let before = contacts.access
            contacts.refreshAccess()
            if contacts.access == .authorized && before != .authorized { Task { await contacts.load() } }
        }
        .sheet(item: $inviting) { request in
            InviteSheet(request: request) { sent in
                inviting = nil
                guard sent else { return }
                invited.insert(request.contact.id)
                Haptics.tap()
                toast.show("Invite sent to \(request.contact.firstName)", icon: "send")
            }
        }
    }

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces).lowercased() }
    private var searching: Bool { !trimmed.isEmpty }

    // MARK: Search

    @ViewBuilder private var results: some View {
        let q = trimmed
        // The field invites "@handle", but handles are stored without the @.
        let handle = q.hasPrefix("@") ? String(q.dropFirst()) : q
        let hits = store.seed.people.filter {
            $0.name.lowercased().contains(q) || (!handle.isEmpty && $0.handle.lowercased().contains(handle))
        }
        let onOdyssey = visibleMatches
        let toInvite = visibleInvites
        if hits.isEmpty && onOdyssey.isEmpty && toInvite.isEmpty {
            Text("No one matches that.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.s8)
        } else {
            if !onOdyssey.isEmpty {
                section("On Odyssey", link: nil) { matchRows(onOdyssey) }
            }
            if !hits.isEmpty {
                section("Explorers", link: nil) { rows(hits) }
            }
            if !toInvite.isEmpty {
                section("Invite", link: nil) { inviteRows(toInvite) }
            }
        }
    }

    // MARK: Suggestions

    @ViewBuilder private var suggestions: some View {
        let requests = store.state.requests.compactMap { store.seed.person($0) }
        if !requests.isEmpty {
            section("Friend requests", link: "\(requests.count) waiting") {
                ForEach(requests) { person in requestRow(person) }
            }
        }
        contactsBlock
        section("Explorers near you", link: nil) {
            rows(store.seed.people.filter { !store.isFriend($0.id) && !store.state.requests.contains($0.id) })
        }
        if contacts.access == .authorized && !visibleInvites.isEmpty {
            section("Invite", link: "\(visibleInvites.count) contacts") { inviteRows(visibleInvites) }
        }
        inviteRow.padding(.horizontal, Space.s5).padding(.top, Space.s5)
        Text("Odyssey never stores your address book. Phone numbers and emails are scrambled on your phone before matching, then discarded.")
            .font(.system(size: 11))
            .foregroundStyle(Palette.faint)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Space.s5)
            .padding(.vertical, Space.s3)
    }

    // MARK: Contacts

    @ViewBuilder private var contactsBlock: some View {
        switch contacts.access {
        case .notDetermined:
            permissionCard(
                title: "Find your friends",
                sub: "See who from your contacts is already exploring on Odyssey.",
                button: "Connect contacts", kind: .primary
            ) {
                Task { await contacts.connect() }
            }
        case .denied:
            permissionCard(
                title: "Contacts are off",
                sub: "Turn on Contacts for Odyssey in Settings to find friends you already know.",
                button: "Open Settings", kind: .soft
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
        case .authorized:
            section("On Odyssey", link: contacts.matches.isEmpty ? nil : "\(visibleMatches.count) found") {
                if contacts.loading && !contacts.loaded {
                    HStack(spacing: Space.s3) {
                        ProgressView()
                        Text("Looking through your contacts").font(.system(size: 13)).foregroundStyle(Palette.muted)
                    }
                    .padding(.vertical, Space.s4)
                } else if !visibleMatches.isEmpty {
                    matchRows(visibleMatches)
                } else {
                    Text(emptyMatchesText)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.muted)
                        .padding(.vertical, Space.s3)
                }
            }
        }
    }

    private var emptyMatchesText: String {
        if contacts.contacts.isEmpty { return "No contacts with a phone number or email yet." }
        if !Cloud.shared.signedIn { return "Sign in to see which of your contacts are on Odyssey." }
        if !contacts.matchingRan { return "Could not check your contacts right now. Try again in a bit." }
        return "None of your contacts are on Odyssey yet. Invite them below."
    }

    private func permissionCard(title: String, sub: String, button: String, kind: PillButtonStyle.Kind,
                                action: @escaping () -> Void) -> some View {
        VStack(spacing: Space.s3) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: 52, height: 52)
                .background(Palette.surface, in: Circle())
            VStack(spacing: 4) {
                Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(sub)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(button, action: action)
                .buttonStyle(.pill(kind, height: 44, fill: true))
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .softCard(padding: Space.s5)
        .padding(.horizontal, Space.s5)
        .padding(.top, Space.s5)
    }

    /// Matched explorers, filtered by the search.
    private var visibleMatches: [ContactMatch] {
        let q = trimmed
        guard !q.isEmpty else { return contacts.matches }
        let handle = q.hasPrefix("@") ? String(q.dropFirst()) : q
        return contacts.matches.filter { m in
            m.name.lowercased().contains(q) || m.handle.lowercased().contains(handle)
                || (contacts.contact(for: m)?.name.lowercased().contains(q) ?? false)
        }
    }

    /// Contacts not on Odyssey, sorted by name, filtered by the search.
    private var visibleInvites: [DeviceContact] {
        guard contacts.access == .authorized else { return [] }
        let q = trimmed
        let digits = q.filter(\.isNumber)
        return contacts.contacts.filter { c in
            guard !contacts.matchedContactIDs.contains(c.id) else { return false }
            guard !q.isEmpty else { return true }
            return c.name.lowercased().contains(q)
                || c.emails.contains { $0.contains(q) }
                || (digits.count >= 3 && c.phones.contains { $0.contains(digits) })
        }
    }

    private func matchRows(_ matches: [ContactMatch]) -> some View {
        VStack(spacing: 0) {
            ForEach(matches, id: \.userId) { match in matchRow(match) }
        }
    }

    private func matchRow(_ match: ContactMatch) -> some View {
        let person = match.demoId.flatMap { store.person($0) }
        let contact = contacts.contact(for: match)
        let sub = contact.map { $0.name == match.name ? "@\(match.handle)" : "@\(match.handle), \($0.name) in contacts" } ?? "@\(match.handle)"
        return HStack(spacing: Space.s3) {
            Button {
                if let person { router.push(.person(person.id)) }
            } label: {
                HStack(spacing: Space.s3) {
                    matchAvatar(match, person: person, contact: contact)
                    titles(match.name, sub)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(person == nil)
            if store.isFriend(match.friendKey) {
                Tag(text: "Added", icon: "check", tone: .success)
            } else {
                Button("Add") { add(match) }.buttonStyle(.pill(.primary, height: 36))
            }
        }
        .padding(.vertical, Space.s3)
    }

    @ViewBuilder
    private func matchAvatar(_ match: ContactMatch, person: Person?, contact: DeviceContact?) -> some View {
        if let person {
            AvatarView(person: person, size: 44)
        } else if let url = match.avatarURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Palette.surface2
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
        } else if let contact {
            ContactAvatar(contact: contact)
        } else {
            DefaultFace().frame(width: 44, height: 44).clipShape(Circle())
        }
    }

    private func inviteRows(_ people: [DeviceContact]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(people) { contact in contactRow(contact) }
        }
    }

    private func contactRow(_ contact: DeviceContact) -> some View {
        HStack(spacing: Space.s3) {
            ContactAvatar(contact: contact)
            titles(contact.name, contact.detail)
            if invited.contains(contact.id) {
                Tag(text: "Invited", icon: "check")
            } else {
                Button("Invite") { invite(contact) }
                    .buttonStyle(.pill(.soft, height: 36))
            }
        }
        .padding(.vertical, Space.s3)
    }

    private var inviteLink: URL {
        URL(string: "https://pathy.app/invite/\(store.state.user.handle)") ?? URL(string: "https://pathy.app")!
    }

    private func invite(_ contact: DeviceContact) {
        let text = "Come explore with me on Odyssey. Check in somewhere new and we both earn coins."
        let canText = contact.phone != nil && MFMessageComposeViewController.canSendText()
        inviting = InviteRequest(contact: contact, kind: canText ? .message : .share, text: text, link: inviteLink)
    }

    private func add(_ match: ContactMatch) {
        if let person = match.demoId.flatMap({ store.person($0) }) {
            add(person)
            return
        }
        store.addFriend(match.friendKey)
        Haptics.tap()
        toast.show("You and \(match.name.split(separator: " ").first.map(String.init) ?? match.name) are friends", icon: "check")
    }

    // MARK: Explorers

    private func section<Content: View>(_ title: String, link: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: title, link: link)
            content()
        }
        .padding(.horizontal, Space.s5)
        .padding(.top, Space.s5)
    }

    private func rows(_ people: [Person]) -> some View {
        VStack(spacing: 0) {
            ForEach(people) { person in personRow(person) }
        }
    }

    private func personRow(_ person: Person) -> some View {
        HStack(spacing: Space.s3) {
            Button { router.push(.person(person.id)) } label: {
                HStack(spacing: Space.s3) {
                    AvatarView(person: person, size: 44)
                    titles(person.name, "@\(person.handle), \(person.contributions) walkthroughs")
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if store.isFriend(person.id) {
                Tag(text: "Friends", icon: "check", tone: .success)
            } else {
                Button("Add") { add(person) }.buttonStyle(.pill(.primary, height: 36))
            }
        }
        .padding(.vertical, Space.s3)
    }

    private func requestRow(_ person: Person) -> some View {
        HStack(spacing: Space.s3) {
            AvatarView(person: person, size: 44)
            titles(person.name, "@\(person.handle) wants to explore with you")
            Button {
                store.declineRequest(person.id)
            } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).frame(width: 36, height: 36)
                    .foregroundStyle(Palette.ink).background(Palette.surface2, in: Circle())
            }
            .buttonStyle(PressStyle(scale: 0.9))
            .accessibilityLabel("Decline")
            Button("Accept") { add(person) }.buttonStyle(.pill(.accent, height: 36))
        }
        .padding(.vertical, Space.s3)
    }

    private var inviteRow: some View {
        ShareLink(item: inviteLink, subject: Text("Come explore with me"),
                  message: Text("I'm on Odyssey. Check in somewhere new and we both earn coins.")) {
            HStack(spacing: Space.s3) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                titles("Invite friends to Odyssey", "Send your link anywhere")
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.faint)
            }
            .foregroundStyle(Palette.ink)
        }
        .buttonStyle(PressStyle())
    }

    private func titles(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
            Text(sub).font(.system(size: 13)).foregroundStyle(Palette.muted).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Add a friend, then the reward moment the mockup shows for it.
    private func add(_ person: Person) {
        store.addFriend(person.id)
        pop.friendAdded(person.id, store: store)
    }
}
