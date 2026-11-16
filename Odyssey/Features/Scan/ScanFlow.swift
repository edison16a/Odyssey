//
//  ScanFlow.swift
//  Odyssey
//
//  The + button: film a walk through a place and Odyssey turns it into a
//  3D space people can walk around in. The place comes from GPS (the
//  nearest place on the map) unless the flow was opened from a place.
//  The video goes to Convex, a render computer builds the space, and this
//  screen shows each step until it is ready.
//

import PhotosUI
import SwiftUI

struct ScanFlow: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    /// Nil means "wherever I am": the nearest place by GPS.
    var placeID: String?

    private enum Stage: Equatable {
        case record
        case naming(video: URL)
        case sending
        case building(scanID: String)
        case problem(String)
    }

    @State private var stage: Stage = .record
    @State private var place: Place?
    @State private var spaceName = ""
    @State private var sendingText = "Getting your video ready"
    @State private var sendingProgress = 0.0
    private let scans = ScanService.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconButton(icon: "close", label: "Close") { router.dismissCover() }
                VStack(spacing: 1) {
                    Text("3D scan").font(.system(size: 17, weight: .bold))
                    if let place {
                        Label(place.name, systemImage: "mappin.and.ellipse")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.muted)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 12)
            content
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .frame(maxHeight: .infinity)
        }
        .background(Palette.surface)
        .onAppear {
            scans.watch()
            if place == nil { place = placeID.flatMap(store.place) ?? store.nearestPlace ?? ScanFlow.here(store.here) }
        }
    }

    /// With no known place nearby, the scan still belongs to the spot you are standing on.
    private static func here(_ coord: Coord) -> Place {
        Place(id: String(format: "gps:%.4f,%.4f", coord.lat, coord.lng), name: "Where you are", coords: coord, photo: "")
    }

    @ViewBuilder private var content: some View {
        switch stage {
        case .record:
            ScanRecorder { video in
                if spaceName.isEmpty, let place { spaceName = scans.suggestedName(for: place.id) }
                withAnimation(.easeInOut(duration: 0.3)) { stage = .naming(video: video) }
            }
        case .naming(let video):
            ScanNameStep(placeName: place?.name ?? "this place", name: $spaceName) { send(video) }
        case .sending:
            ScanStatusScreen(title: "Sending your video", message: sendingText, progress: sendingProgress,
                             note: "Keep Odyssey open until the video is sent.")
        case .building(let scanID):
            building(scans.scan(scanID))
        case .problem(let text):
            VStack(spacing: 14) {
                Spacer()
                GlobieView(mood: .sad, form: store.streakTier.id, size: 96)
                Text("That did not work").font(.system(size: 22, weight: .bold)).tracking(-0.4)
                Text(text).mutedStyle(15).multilineTextAlignment(.center)
                Spacer()
                Button("Try again") { stage = .record }.buttonStyle(.pill(.accent, fill: true))
            }
        }
    }

    @ViewBuilder private func building(_ scan: Scan?) -> some View {
        if let scan, scan.isReady {
            VStack(spacing: 14) {
                Spacer()
                GlobieView(mood: .happy, form: store.streakTier.id, size: 110)
                Text("Your 3D space is ready").font(.system(size: 24, weight: .bold)).tracking(-0.4)
                Text("\(scan.name) at \(place?.name ?? scan.placeName) can now be explored from anywhere.")
                    .mutedStyle(15).multilineTextAlignment(.center)
                Spacer()
                Button {
                    router.present(.scanViewer(scanID: scan.id))
                } label: {
                    Label("Walk around", systemImage: "figure.walk")
                }
                .buttonStyle(.pill(.accent, fill: true))
            }
        } else if let scan, scan.isFailed {
            VStack(spacing: 14) {
                Spacer()
                GlobieView(mood: .sad, form: store.streakTier.id, size: 96)
                Text("This scan did not work").font(.system(size: 22, weight: .bold)).tracking(-0.4)
                Text(scan.message).mutedStyle(15).multilineTextAlignment(.center)
                Spacer()
                Button("Scan again") { stage = .record }.buttonStyle(.pill(.accent, fill: true))
            }
        } else {
            VStack(spacing: 0) {
                ScanStatusScreen(title: "Building your 3D space",
                                 message: scan?.message ?? "Waiting for a render computer",
                                 progress: scan?.progress ?? 0,
                                 note: "This takes about 15 minutes. You can close this and keep exploring; the place will show a 3D button when it is ready.")
                Button("Done") { router.dismissCover() }.buttonStyle(.pill(.primary, fill: true))
            }
        }
    }

    private func send(_ video: URL) {
        guard let place else { return }
        sendingText = "Getting your video ready"
        sendingProgress = 0
        withAnimation(.easeInOut(duration: 0.3)) { stage = .sending }
        Task {
            do {
                let typed = spaceName.trimmingCharacters(in: .whitespacesAndNewlines)
                let name = typed.isEmpty ? scans.suggestedName(for: place.id) : typed
                let id = try await scans.submit(video: video, place: place, name: name, creator: store.me.name) { text, fraction in
                    sendingText = text
                    sendingProgress = fraction
                }
                Haptics.success()
                withAnimation(.easeInOut(duration: 0.3)) { stage = .building(scanID: id) }
            } catch {
                withAnimation(.easeInOut(duration: 0.3)) { stage = .problem(error.localizedDescription) }
            }
            try? FileManager.default.removeItem(at: video)
        }
    }
}

/// After filming: give the space a name. A place can have several, so the name says which part this is.
struct ScanNameStep: View {
    var placeName: String
    @Binding var name: String
    var onStart: () -> Void
    @FocusState private var typing: Bool

    private static let ideas = ["Entrance", "Main hall", "Kitchen", "Upstairs", "Downstairs", "Outside"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Name this space").font(.system(size: 24, weight: .bold)).tracking(-0.4).padding(.top, 8)
            Text("\(placeName) can have several 3D spaces: a room, a floor, the courtyard. The name tells explorers which one this is.")
                .mutedStyle(15)
                .fixedSize(horizontal: false, vertical: true)
            TextField("Main hall", text: $name)
                .font(.system(size: 17, weight: .semibold))
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .focused($typing)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .onChange(of: name) { _, value in
                    if value.count > 40 { name = String(value.prefix(40)) }
                }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ScanNameStep.ideas, id: \.self) { idea in
                        Button(idea) {
                            Haptics.tap()
                            name = idea
                        }
                        .buttonStyle(.pill(name == idea ? .primary : .soft, height: 36))
                    }
                }
            }
            Spacer()
            Button {
                typing = false
                onStart()
            } label: {
                Label("Build 3D space", systemImage: "cube.transparent")
            }
            .buttonStyle(.pill(.accent, fill: true))
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Globie, a title, what is happening right now and a progress bar.
struct ScanStatusScreen: View {
    @Environment(AppStore.self) private var store
    var title: String
    var message: String
    var progress: Double
    var note: String

    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            GlobieView(mood: .happy, form: store.streakTier.id, size: 96)
            Text(title).font(.system(size: 22, weight: .bold)).tracking(-0.4).padding(.top, 6)
            Text(message)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.accentInk)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: message)
            ProgressView(value: min(1, max(0, progress)))
                .tint(Palette.accent)
                .padding(.horizontal, 40)
                .padding(.top, 6)
                .animation(.easeInOut(duration: 0.4), value: progress)
            Text("\(Int((min(1, max(0, progress)) * 100).rounded()))%")
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Palette.muted)
            Spacer()
            Text(note).mutedStyle(13).multilineTextAlignment(.center).padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity)
    }
}

/// A video picked from the photo library, copied somewhere the app can read it.
nonisolated struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent("scan-pick-\(UUID().uuidString).\(ext)")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedMovie(url: copy)
        }
    }
}

/// Records the walk with the 0.5x camera (it sees more of the room, which the 3D build tracks far
/// better), or takes a video from the library.
struct ScanRecorder: View {
    @Environment(ToastCenter.self) private var toast
    var onVideo: (URL) -> Void

    @State private var camera = CameraModel()
    @State private var recording = false
    @State private var startedAt = Date()
    @State private var finishing = false
    @State private var picked: PhotosPickerItem?
    @State private var loadingPick = false

    private static let tips = [
        "Walk slowly and hold the phone upright",
        "Turn slowly: quick turns lose the room",
        "Point at walls and furniture, not people",
        "Loop back to where you started if you can",
    ]

    private var live: Bool { camera.isAvailable && !camera.permissionDenied && camera.isRunning }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
            let seconds = recording ? timeline.date.timeIntervalSince(startedAt) : 0
            VStack(spacing: 16) {
                preview(seconds: seconds)
                bar(seconds: seconds)
            }
            .onChange(of: Int(seconds)) { _, whole in
                if recording && Double(whole) >= ScanService.maximumSeconds { finish() }
            }
        }
        .task {
            if camera.isAvailable { await camera.start(ultraWide: true) }
        }
        .onDisappear { camera.stop() }
        .onChange(of: picked) { _, item in
            guard let item else { return }
            loadingPick = true
            Task {
                let movie = try? await item.loadTransferable(type: PickedMovie.self)
                loadingPick = false
                picked = nil
                if let movie { onVideo(movie.url) } else { toast.show("That video could not be opened.", icon: "exclamationmark.triangle") }
            }
        }
    }

    private func preview(seconds: Double) -> some View {
        ZStack {
            Palette.ink
            if live {
                CameraPreview(session: camera.engine.session)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: camera.permissionDenied ? "video.slash" : "cube.transparent")
                        .font(.system(size: 40, weight: .semibold))
                    Text(camera.permissionDenied ? "Odyssey cannot use the camera. Allow it in Settings, or choose a video you already filmed."
                         : camera.isAvailable ? "Starting the camera" : "No camera here. Choose a video you already filmed.")
                        .font(.system(size: 15, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                .foregroundStyle(.white.opacity(0.85))
            }
            VStack {
                HStack(spacing: 6) {
                    Circle().fill(recording ? Color(hex: "#ff3b30") : .white.opacity(0.6)).frame(width: 8, height: 8)
                    Text(String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)).monospacedDigit()
                }
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.black.opacity(0.5), in: Capsule())
                .padding(12)
                Spacer()
                Text(recording ? ScanRecorder.tips[min(ScanRecorder.tips.count - 1, Int(seconds / 12))]
                     : "Film a slow walk through the place, 20 to 90 seconds")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .padding(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func bar(seconds: Double) -> some View {
        HStack {
            PhotosPicker(selection: $picked, matching: .videos, photoLibrary: .shared()) {
                VStack(spacing: 4) {
                    if loadingPick {
                        ProgressView().frame(height: 22)
                    } else {
                        Image(systemName: "photo.on.rectangle").font(.system(size: 20, weight: .semibold)).frame(height: 22)
                    }
                    Text("Choose video")
                }
            }
            .disabled(recording || loadingPick)
            .opacity(recording ? 0.3 : 1)
            .frame(maxWidth: .infinity)
            Button {
                recording ? finish() : begin()
            } label: {
                ZStack {
                    Circle().stroke(Palette.lineStrong, lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: min(1, seconds / ScanService.maximumSeconds))
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
            .disabled(finishing || !live)
            .opacity(live ? 1 : 0.35)
            .accessibilityLabel(recording ? "Stop recording" : "Record")
            Text(recording ? (seconds < ScanService.minimumSeconds ? "Keep going" : "Tap to finish") : "\(Int(ScanService.maximumSeconds))s max")
                .frame(maxWidth: .infinity)
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(Palette.muted)
    }

    private func begin() {
        guard live else { return }
        Haptics.tap()
        startedAt = Date()
        recording = true
        camera.startRecording()
    }

    private func finish() {
        guard recording, !finishing else { return }
        let seconds = Date().timeIntervalSince(startedAt)
        if seconds < ScanService.minimumSeconds {
            toast.show("Keep walking. A 3D space needs at least \(Int(ScanService.minimumSeconds)) seconds.", icon: "clock")
            return
        }
        finishing = true
        Task {
            let url = await camera.stopRecording()
            recording = false
            finishing = false
            camera.stop()
            Haptics.success()
            if let url { onVideo(url) } else { toast.show("The recording was lost. Try again.", icon: "exclamationmark.triangle") }
        }
    }
}
