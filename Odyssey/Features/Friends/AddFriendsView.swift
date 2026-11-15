//
//  AddFriendsView.swift
//  Odyssey
//
//  Find friends. Answer requests, search public explorers by handle or
//  name, add people from contacts (matching is pretend, no address book is
//  read) and pick from explorers near you. Ported from add-friends.js.
//

import Foundation
import SwiftUI

struct AddFriendsView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toast
    @Environment(RewardPopCenter.self) private var pop

    @State private var query = ""
    @State private var invited: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Add friends", back: { router.pop() })
            FieldBox(icon: "search") {
                TextField("Search by name or @handle", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, Space.s5)
            .padding(.bottom, 4)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if query.trimmingCharacters(in: .whitespaces).isEmpty {
                        suggestions
                    } else {
                        results
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .background(Palette.surface)
    }

    // MARK: Search

    @ViewBuilder private var results: some View {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        // The field invites "@handle", but handles are stored without the @.
        let handle = q.hasPrefix("@") ? String(q.dropFirst()) : q
        let hits = store.seed.people.filter {
            $0.name.lowercased().contains(q) || (!handle.isEmpty && $0.handle.lowercased().contains(handle))
        }
        if hits.isEmpty {
            Text("No public Explorer matches that.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.s8)
        } else {
            rows(hits).padding(.horizontal, Space.s5)
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
        section("From your contacts", link: "Matched privately") {
            ForEach(store.seed.contacts, id: \.name) { contact in contactRow(contact) }
        }
        section("Explorers near you", link: nil) {
            rows(store.seed.people.filter { !store.isFriend($0.id) && !store.state.requests.contains($0.id) })
        }
        inviteRow.padding(.horizontal, Space.s5).padding(.top, Space.s5)
        Text("Odyssey never stores your address book. Contacts are matched on a protected endpoint and then discarded.")
            .font(.system(size: 11))
            .foregroundStyle(Palette.faint)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Space.s5)
            .padding(.vertical, Space.s3)
    }

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

    private func contactRow(_ contact: Contact) -> some View {
        HStack(spacing: Space.s3) {
            DefaultFace().frame(width: 44, height: 44)
            titles(contact.name, contact.onOdyssey ? "On Odyssey" : "Not on Odyssey yet")
            if invited.contains(contact.name) {
                Tag(text: "Sent")
            } else {
                Button(contact.onOdyssey ? "Add" : "Invite") {
                    invited.insert(contact.name)
                    store.completeFirstStep(.friend)
                    Haptics.tap()
                    toast.show("Request sent to \(contact.name)", icon: "send")
                }
                .buttonStyle(.pill(contact.onOdyssey ? .primary : .soft, height: 36))
            }
        }
        .padding(.vertical, Space.s3)
    }

    private var inviteRow: some View {
        let link = URL(string: "https://pathy.app/invite/\(store.state.user.handle)") ?? URL(string: "https://pathy.app")!
        return ShareLink(item: link, subject: Text("Come explore with me"),
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
