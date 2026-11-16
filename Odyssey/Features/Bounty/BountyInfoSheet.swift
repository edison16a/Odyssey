import SwiftUI

struct BountyInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Bounties are rewards people fund to encourage others to explore and document real-world locations.")
                    Text("Anyone can fund a bounty for a place, street, or city. Explorers can discover these opportunities and contribute useful walkthroughs of permitted locations.")
                    stage("1. Choose a location", "Select somewhere you want better documented.")
                    stage("2. Fund a reward", "Set the amount, duration, and maximum number of eligible explorers.")
                    stage("3. Invite explorers", "After payment confirmation, the bounty becomes visible to the community.")
                    Text("A café owner can fund a $100 bounty for their business, giving explorers an incentive to document its seating, entrances, and useful amenities.")
                        .padding(16).background(Palette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    Text("Funding and publication are supported. Contribution verification and actual explorer payouts are not yet available; estimated shares are not a payout guarantee.")
                    Text("A bounty does not grant permission to record inside a private business. Always obtain permission and respect privacy and local rules.")
                }.font(.subheadline).padding(20)
            }
            .navigationTitle("What are bounties?").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
    private func stage(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline); Text(text).foregroundStyle(.secondary) }
    }
}
