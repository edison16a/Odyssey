//
//  AdventureMoments.swift
//  Odyssey
//
//  Plays the big moments over Adventure Complete, one after another: the
//  rank up screen when the check-in crossed into a new rank, then the
//  leaderboard moment when it carried you into the top 100 or top 10.
//

import Foundation
import SwiftUI

private struct AdventureMoments: ViewModifier {
    @Environment(AppRouter.self) private var router
    var result: CheckInResult

    private enum Stage { case none, rankUp, board }
    @State private var stage = Stage.none
    @State private var started = false

    private var rankedUp: Bool { result.fresh && result.rankAfter.tier > result.rankBefore.tier }

    func body(content: Content) -> some View {
        content
            .overlay {
                ZStack {
                    if stage == .rankUp {
                        RankUpMoment(before: result.rankBefore, after: result.rankAfter, close: next)
                            .transition(.opacity.combined(with: .scale(scale: 1.04)))
                    }
                    if stage == .board, let board = result.board {
                        BoardMomentView(moment: board, close: { show(.none) }, openBoard: openBoard)
                            .transition(.opacity)
                    }
                }
                .environment(\.animationsPaused, false)
            }
            .onAppear {
                guard !started else { return }
                started = true
                let first: Stage = rankedUp ? .rankUp : (result.board != nil ? .board : .none)
                guard first != .none else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { show(first) }
            }
    }

    private func show(_ next: Stage) {
        withAnimation(.easeInOut(duration: 0.35)) { stage = next }
    }

    /// After the rank up, the leaderboard moment if there is one.
    private func next() {
        guard result.board != nil else { return show(.none) }
        show(.none)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { show(.board) }
    }

    private func openBoard() {
        router.dismissCover()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { router.push(.leaderboard) }
    }
}

extension View {
    /// Rank up and leaderboard moments for a finished check-in.
    func adventureMoments(_ result: CheckInResult) -> some View {
        modifier(AdventureMoments(result: result))
    }
}
