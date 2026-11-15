//
//  WalkthroughRecorder.swift
//  Odyssey
//
//  The video camera: the real back camera, one record button with a timer
//  ring, up to 60 seconds. Used by the + button and by place screens.
//  Without a camera it plays a simulated walk through the place photo and
//  indoor photos so the flow still works in the simulator.
//  Ported from features/walkthrough/walk-recorder.js.
//

import Foundation
import SwiftUI

struct WalkthroughRecorder: View {
    @Environment(AppStore.self) private var store
    /// Where you are, when known. Only used for the simulated walk.
    var place: Place?
    var onDone: (_ seconds: Int, _ video: URL?, _ simulated: Bool) -> Void

    @State private var camera = CameraModel()
    @State private var recording = false
    @State private var startedAt = Date()
    @State private var finishing = false
    /// Whether the real camera was recording when the walk began.
    @State private var recordingLive = false

    /// Shorter taps are ignored, so a double tap does not end the video at once.
    private static let minimum = 1.0
    private static let maximum = Double(Rewards.maxClipSeconds)

    private var live: Bool { camera.isAvailable && !camera.permissionDenied && camera.isRunning }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
            let seconds = recording ? timeline.date.timeIntervalSince(startedAt) : 0
            VStack(spacing: 16) {
                view(seconds: seconds)
                bar(seconds: seconds)
            }
            .onChange(of: Int(seconds)) { _, whole in
                if recording && Double(whole) >= WalkthroughRecorder.maximum { finish() }
            }
        }
        .task {
            if camera.isAvailable { await camera.start(side: .back, video: true) }
        }
        .onDisappear { camera.stop() }
    }

    private var shots: [String] { WalkthroughRecorder.shots(for: place ?? store.nearestPlace) }

    /// The simulated walk: the place photo, then three indoor photos that fit the kind of place.
    static func shots(for place: Place?) -> [String] {
        let indoor: [String: [String]] = [
            "library": ["reading-room", "stairs", "corridor"], "campus": ["lobby", "hallway-1", "meeting-room"],
            "office": ["lobby", "meeting-room", "kitchen"], "museum": ["event-hall", "corridor", "stairs"],
        ]
        let names = indoor[place?.category ?? ""] ?? ["entrance-door", "lobby", "hallway-1"]
        return (place.map { [$0.photo] } ?? []) + names.map { "assets/media/indoor/\($0).jpg" }
    }

    private func view(seconds: Double) -> some View {
        ZStack {
            Palette.ink
            if live {
                CameraPreview(session: camera.engine.session)
            } else {
                let index = recording ? Int(seconds / 3) % shots.count : 0
                PhotoView(path: shots[index])
                    .scaleEffect(recording ? 1.04 + 0.1 * (seconds.truncatingRemainder(dividingBy: 3) / 3) : 1)
                    .id(index)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.6), value: index)
            }
            VStack {
                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Circle().fill(recording ? Color(hex: "#ff3b30") : .white.opacity(0.6)).frame(width: 8, height: 8)
                        Text(String(format: "0:%02d", Int(seconds))).monospacedDigit()
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.5), in: Capsule())
                    Spacer()
                }
                .overlay(alignment: .trailing) {
                    if !live && recording {
                        Label("Simulated walk", systemImage: "photo")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.85), in: Capsule())
                    }
                }
                .padding(12)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func bar(seconds: Double) -> some View {
        HStack {
            Spacer()
            Button {
                recording ? finish() : begin()
            } label: {
                ZStack {
                    Circle().stroke(Palette.lineStrong, lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: min(1, seconds / WalkthroughRecorder.maximum))
                        .stroke(Color(hex: "#ff3b30"), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.5), value: seconds)
                    RoundedRectangle(cornerRadius: recording ? 8 : 26, style: .continuous)
                        .fill(Color(hex: "#ff3b30"))
                        .padding(recording ? 26 : 14)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: recording)
                }
                .frame(width: 80, height: 80)
            }
            .buttonStyle(PressStyle(scale: 0.94))
            .disabled(finishing)
            .accessibilityLabel(recording ? "Stop recording" : "Record")
            Spacer()
        }
    }

    private func begin() {
        Haptics.tap()
        startedAt = Date()
        recording = true
        recordingLive = live
        if live { camera.startRecording() }
    }

    private func finish() {
        guard recording, !finishing else { return }
        let seconds = Date().timeIntervalSince(startedAt)
        if seconds < WalkthroughRecorder.minimum { return }
        finishing = true
        // Decided by how the walk began: the camera can come up after Record was tapped.
        let simulated = !recordingLive
        Task {
            var url: URL?
            if !simulated { url = await camera.stopRecording() }
            recording = false
            camera.stop()
            Haptics.success()
            onDone(max(1, Int(seconds.rounded())), url, simulated)
        }
    }
}
