//
//  SettingsCredits.swift
//  Odyssey
//
//  Photo credits. Every real photo in the app is credited to its creator
//  and license, read from the credits list bundled in seed.json.
//

import Foundation
import SwiftUI

struct SettingsCredits: View {
    nonisolated struct Credit: Decodable, Hashable, Sendable {
        var file: String?
        var title: String?
        var creator: String?
        var license: String?
        var url: String?
    }

    private nonisolated struct CreditsFile: Decodable, Sendable { var credits: [Credit]? }

    /// Read once; the seed decoder skips this list, so it is decoded on its own.
    private static let all: [Credit] = {
        guard let url = Bundle.main.url(forResource: "seed", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(CreditsFile.self, from: data) else { return [] }
        return decoded.credits ?? []
    }()

    @State private var expanded = false

    var body: some View {
        let credits = SettingsCredits.all
        VStack(alignment: .leading, spacing: 10) {
            if credits.isEmpty {
                Text("Photo credits are listed in assets/media/CREDITS.md in the mockup.")
                    .font(.system(size: 13)).foregroundStyle(Palette.muted)
            } else {
                Text("Photos from Wikimedia Commons, Flickr and Unsplash, used under their licenses.")
                    .font(.system(size: 13)).foregroundStyle(Palette.muted)
                // Over a hundred rows when expanded, so they are built as they scroll in.
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(expanded ? credits : Array(credits.prefix(5)), id: \.self) { credit in row(credit) }
                }
                if credits.count > 5 {
                    Button(expanded ? "Show fewer" : "Show all \(credits.count)") {
                        withAnimation(.easeOut(duration: 0.2)) { expanded.toggle() }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                }
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder private func row(_ credit: Credit) -> some View {
        let label = VStack(alignment: .leading, spacing: 1) {
            Text(credit.title ?? credit.file ?? "Photo").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(2)
            Text([credit.creator, credit.license].compactMap { $0 }.joined(separator: ", ")).font(.system(size: 11)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        if let link = credit.url.flatMap({ URL(string: $0) }) {
            Link(destination: link) { label }
        } else {
            label
        }
    }
}
