//
//  ExploreSearchSheet.swift
//  Odyssey
//
//  Search and categories, tucked behind the magnifying glass on the feed:
//  type anything ("ramen", "record store") or pick a quick filter or a
//  category, and the feed switches to it.
//

import Foundation
import SwiftUI

struct ExploreSearchSheet: View {
    var filter: ExploreFilter
    var onPick: (ExploreFilter) -> Void

    @State private var typed = ""
    @FocusState private var focused: Bool

    private var active: ExploreQuery? {
        if case .search(let q) = filter { return q }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What are you looking for?").titleStyle(22)
                .padding(.horizontal, Space.s4)
            ExploreSearchBar(text: $typed, active: active, focused: $focused,
                             onPick: { onPick(.search($0)) }, onClear: { onPick(.all) })
                .padding(.horizontal, Space.s4)
            if !typed.isEmpty {
                ScrollView {
                    ExploreSuggestions(typed: typed) { onPick(.search($0)) }
                        .padding(.horizontal, Space.s4)
                        .padding(.bottom, Space.s4)
                }
            } else {
                ExploreFilterBar(filter: filter) { onPick($0) }
                Spacer()
            }
        }
        .padding(.top, 26)
        .onAppear {
            typed = active?.text ?? ""
            focused = true
        }
        .animation(.easeOut(duration: 0.15), value: typed.isEmpty)
    }
}
