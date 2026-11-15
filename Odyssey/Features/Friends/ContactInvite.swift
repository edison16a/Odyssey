//
//  ContactInvite.swift
//  Odyssey
//
//  Inviting a contact: the Messages composer addressed to them when the
//  phone can text, otherwise the share sheet. Plus the small avatar used for
//  address book people.
//

import MessageUI
import SwiftUI
import UIKit

/// What an invite sheet is showing.
struct InviteRequest: Identifiable {
    enum Kind { case message, share }
    var contact: DeviceContact
    var kind: Kind
    var text: String
    var link: URL

    var id: String { contact.id }
}

/// Builds and presents the right invite for a contact.
struct InviteSheet: View {
    var request: InviteRequest
    var done: (_ sent: Bool) -> Void

    var body: some View {
        switch request.kind {
        case .message:
            MessageComposer(recipients: [request.contact.phone].compactMap { $0 },
                            body: "\(request.text) \(request.link.absoluteString)", done: done)
                .ignoresSafeArea()
        case .share:
            ShareSheet(items: [request.text, request.link], done: done)
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
        }
    }
}

struct MessageComposer: UIViewControllerRepresentable {
    var recipients: [String]
    var body: String
    var done: (_ sent: Bool) -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = recipients
        vc.body = body
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let done: (Bool) -> Void
        init(done: @escaping (Bool) -> Void) { self.done = done }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            done(result == .sent)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    var done: (_ sent: Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, completed, _, _ in done(completed) }
        return vc
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

/// A contact's photo, or their initials on grey.
struct ContactAvatar: View {
    var contact: DeviceContact
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let data = contact.thumbnail, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(contact.initials)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.surface2)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
