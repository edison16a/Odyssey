//
//  AdventureActivityView.swift
//  Shared by the app and the widgets.
//
//  The Lock Screen face of the adventure Live Activity, plus the small
//  pieces the Dynamic Island reuses. Heading out it shows the place, the
//  distance left and the coins waiting; once you are there it nudges you
//  to check in; after posting it shows what you earned with Globie.
//

import Foundation
import SwiftUI

struct AdventureActivityView: View {
    var attributes: AdventureActivityAttributes
    var state: AdventureActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AdventureActivityBadge(attributes: attributes, state: state, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.stage.title.uppercased())
                        .font(.system(size: 11, weight: .heavy)).tracking(0.5)
                        .foregroundStyle(state.stage == .complete ? Palette.gold : Color(hex: "#8fa8ff"))
                    Text(attributes.placeName).font(.system(size: 17, weight: .bold)).lineLimit(1)
                    Text(state.message).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                }
                Spacer(minLength: 4)
                if state.stage == .complete {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("+\(state.coinsEarned)").font(.system(size: 24, weight: .heavy)).monospacedDigit()
                        Text("coins").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(state.stage == .heading ? state.distanceText : "+\(attributes.reward)")
                            .font(.system(size: 22, weight: .heavy)).monospacedDigit()
                        Text(state.stage == .heading ? "to go" : "waiting").font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            AdventureActivitySteps(state: state)
        }
        .foregroundStyle(.white)
        .padding(16)
    }
}

/// The round badge: the place's symbol on the way, Globie once it is done.
struct AdventureActivityBadge: View {
    var attributes: AdventureActivityAttributes
    var state: AdventureActivityAttributes.ContentState
    var size: CGFloat

    var body: some View {
        if state.stage == .complete {
            GlobieView(mood: .ecstatic, form: attributes.tierID, size: size, animated: false)
        } else {
            ZStack {
                Circle().fill(attributes.isFirst ? Palette.rare : Palette.accent)
                Image(systemName: attributes.symbol)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
        }
    }
}

/// Four steps along a line: on the way, there, photo, done.
struct AdventureActivitySteps: View {
    var state: AdventureActivityAttributes.ContentState

    private let labels = ["On the way", "There", "Photo", "Done"]

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let width = geo.size.width
                let filled = state.stage == .heading ? state.progress / 3 : Double(state.stage.step) / 3
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18)).frame(height: 4)
                    Capsule().fill(Palette.accent).frame(width: max(4, width * filled), height: 4)
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i <= state.stage.step ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 10, height: 10)
                            .offset(x: width * CGFloat(i) / 3 - 5)
                    }
                }
                .frame(height: 10)
            }
            .frame(height: 10)
            HStack {
                ForEach(0..<4, id: \.self) { i in
                    Text(labels[i])
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(i <= state.stage.step ? .white : .white.opacity(0.45))
                        .frame(maxWidth: .infinity, alignment: i == 0 ? .leading : i == 3 ? .trailing : .center)
                }
            }
        }
    }
}
