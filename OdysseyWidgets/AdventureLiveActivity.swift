//
//  AdventureLiveActivity.swift
//  OdysseyWidgets
//
//  The adventure in progress, on the Lock Screen and in the Dynamic Island
//  around the camera. Compact it shows the place's symbol and the distance
//  left (or the coins once you are there); pressed open it shows the place,
//  the reward and the four steps from heading out to done.
//

import Foundation
import ActivityKit
import SwiftUI
import WidgetKit

struct AdventureLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AdventureActivityAttributes.self) { context in
            AdventureActivityView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Palette.ink)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "odyssey://checkin/\(context.attributes.placeID)"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    AdventureActivityBadge(attributes: context.attributes, state: context.state, size: 40)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(trailingValue(context.attributes, context.state))
                            .font(.system(size: 20, weight: .heavy)).monospacedDigit()
                        Text(trailingLabel(context.state)).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 1) {
                        Text(context.state.stage.title.uppercased())
                            .font(.system(size: 10, weight: .heavy)).tracking(0.5)
                            .foregroundStyle(context.state.stage == .complete ? Palette.gold : Color(hex: "#8fa8ff"))
                        Text(context.attributes.placeName).font(.system(size: 15, weight: .bold)).lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        Text(context.state.message).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                        AdventureActivitySteps(state: context.state)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.stage == .complete ? "checkmark.circle.fill" : context.attributes.symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(context.state.stage == .complete ? Palette.success : Color(hex: "#6f8dff"))
            } compactTrailing: {
                Text(compactValue(context.attributes, context.state))
                    .font(.system(size: 13, weight: .bold)).monospacedDigit()
                    .foregroundStyle(context.state.stage == .complete ? Palette.gold : .white)
            } minimal: {
                ZStack {
                    Circle().stroke(.white.opacity(0.25), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: minimalProgress(context.state))
                        .stroke(Color(hex: "#6f8dff"), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: context.attributes.symbol).font(.system(size: 9, weight: .bold))
                }
            }
            .widgetURL(URL(string: "odyssey://checkin/\(context.attributes.placeID)"))
            .keylineTint(Color(hex: "#6f8dff"))
        }
    }

    private func trailingValue(_ attributes: AdventureActivityAttributes, _ state: AdventureActivityAttributes.ContentState) -> String {
        switch state.stage {
        case .heading: return state.distanceText
        case .complete: return "+\(state.coinsEarned)"
        default: return "+\(attributes.reward)"
        }
    }

    private func trailingLabel(_ state: AdventureActivityAttributes.ContentState) -> String {
        switch state.stage {
        case .heading: return "to go"
        case .complete: return "coins"
        default: return "waiting"
        }
    }

    private func compactValue(_ attributes: AdventureActivityAttributes, _ state: AdventureActivityAttributes.ContentState) -> String {
        switch state.stage {
        case .heading: return state.distanceText
        case .complete: return "+\(state.coinsEarned)"
        default: return "+\(attributes.reward)"
        }
    }

    private func minimalProgress(_ state: AdventureActivityAttributes.ContentState) -> CGFloat {
        state.stage == .heading ? CGFloat(state.progress) : CGFloat(state.stage.step) / 3
    }
}
