//
//  ExploreFilterBar.swift
//  Odyssey
//
//  The controls above the deck. A row of chips (All, Be first, Close by and
//  a Categories menu with the ones you like most on top), then a search bar
//  that suggests from about a thousand things as you type: "ramen", "record
//  store", "quiet study spot". Picking one filters the deck right away.
//

import Foundation
import SwiftUI

struct ExploreFilterBar: View {
    @Environment(AppStore.self) private var store
    var filter: ExploreFilter
    var onPick: (ExploreFilter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(label: "All", icon: "sparkle", isOn: filter == .all) { onPick(.all) }
                Chip(label: "Be first", icon: "star-fill", isOn: filter == .beFirst) { onPick(.beFirst) }
                Chip(label: "Close by", icon: "footprints", isOn: filter == .close) { onPick(.close) }
                categoryMenu
            }
            .padding(.horizontal, Space.s4)
            .padding(.vertical, 2)
        }
    }

    private var chosen: DiscoverCategory? {
        if case .category(let id) = filter { return store.seed.discoverCategory(id) }
        return nil
    }

    /// Every category, the ones your taste leans toward first.
    private var ranked: [DiscoverCategory] {
        let w = store.state.taste.weights
        return store.seed.discoverCategories.sorted { (w["cat:" + $0.id] ?? 0) > (w["cat:" + $1.id] ?? 0) }
    }

    private var categoryMenu: some View {
        Menu {
            ForEach(ranked) { cat in
                Button {
                    onPick(.category(cat.id))
                } label: {
                    Label(cat.label, systemImage: Icon.symbol(cat.icon))
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: Icon.symbol(chosen?.icon ?? "grid")).font(.system(size: 13, weight: .semibold))
                Text(chosen?.label ?? "Categories").font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
            }
            .padding(.horizontal, 14)
            .frame(height: 34)
            .foregroundStyle(chosen == nil ? Palette.ink : .white)
            .background(chosen == nil ? Palette.surface2 : Palette.ink, in: Capsule())
        }
        .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
    }
}

/// The search bar with live suggestions underneath.
struct ExploreSearchBar: View {
    @Binding var text: String
    var active: ExploreQuery?
    var focused: FocusState<Bool>.Binding
    var onPick: (ExploreQuery) -> Void
    var onClear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.muted)
            TextField("What are you in the mood for?", text: $text)
                .font(.system(size: 15, weight: .medium))
                .focused(focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit {
                    guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    onPick(ExploreSearchTerms.query(for: text))
                }
            if !text.isEmpty || active != nil {
                Button {
                    text = ""
                    onClear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Palette.faint)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(focused.wrappedValue ? Palette.ink.opacity(0.85) : .clear, lineWidth: 1.5)
        }
        .animation(.easeOut(duration: 0.15), value: focused.wrappedValue)
    }
}

/// Up to eight matches, the typed part in bold.
struct ExploreSuggestions: View {
    var typed: String
    var onPick: (ExploreQuery) -> Void

    var body: some View {
        let items = ExploreSearchTerms.suggestions(typed)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items, id: \.text) { item in
                Button { onPick(item) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.faint)
                        highlighted(item.text)
                        Spacer()
                        Image(systemName: "arrow.up.left").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.faint)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if items.isEmpty {
                Text("Search for \u{201C}\(typed)\u{201D} nearby")
                    .font(.system(size: 14)).foregroundStyle(Palette.muted)
                    .padding(14)
            }
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
    }

    private func highlighted(_ text: String) -> Text {
        let q = typed.lowercased().trimmingCharacters(in: .whitespaces)
        guard let range = text.range(of: q), !q.isEmpty else {
            return Text(text).font(.system(size: 15)).foregroundColor(Palette.ink)
        }
        let before = Text(text[..<range.lowerBound]).foregroundColor(Palette.ink2)
        let match = Text(text[range]).fontWeight(.bold).foregroundColor(Palette.ink)
        let after = Text(text[range.upperBound...]).foregroundColor(Palette.ink2)
        return Text("\(before)\(match)\(after)").font(.system(size: 15))
    }
}
