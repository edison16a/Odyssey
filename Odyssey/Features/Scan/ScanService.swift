//
//  ScanService.swift
//  Odyssey
//
//  3D scans, all through Convex. The phone uploads a walkthrough video and
//  creates a scan; a render computer picks it up, builds the 3D space and
//  uploads it back. This keeps the list of scans fresh so place cards can
//  say "Building", show what the render computer is doing, or open the
//  finished space. See convex/scans.ts and tools/scan-worker.
//

import AVFoundation
import Foundation
import Observation

/// One scan of a place, as Convex reports it.
nonisolated struct Scan: Identifiable, Hashable, Sendable {
    var id: String
    var placeID: String
    var placeName: String
    /// "queued", "processing", "ready" or "failed".
    var status: String
    /// What is happening right now, written by the render computer.
    var message: String
    var progress: Double
    var modelURL: URL?
    /// JSON for the viewer: which way is up and the path that was walked.
    var meta: String?
    var splats: Int
    var createdAt: Double

    var isReady: Bool { status == "ready" && modelURL != nil && meta != nil }
    var isWorking: Bool { status == "queued" || status == "processing" }
    var isFailed: Bool { status == "failed" }

    init?(_ json: [String: Any]) {
        guard let id = json["id"] as? String, let placeID = json["placeId"] as? String else { return nil }
        self.id = id
        self.placeID = placeID
        placeName = json["placeName"] as? String ?? ""
        status = json["status"] as? String ?? "queued"
        message = json["message"] as? String ?? ""
        progress = (json["progress"] as? NSNumber)?.doubleValue ?? 0
        modelURL = (json["modelUrl"] as? String).flatMap(URL.init(string:))
        meta = json["meta"] as? String
        splats = (json["splats"] as? NSNumber)?.intValue ?? 0
        createdAt = (json["createdAt"] as? NSNumber)?.doubleValue ?? 0
    }
}

enum ScanError: LocalizedError {
    case tooShort
    case upload
    case download

    var errorDescription: String? {
        switch self {
        case .tooShort: return "That video is too short. Record at least \(Int(ScanService.minimumSeconds)) seconds."
        case .upload: return "The video could not be sent. Check your connection and try again."
        case .download: return "The 3D space could not be loaded. Check your connection and try again."
        }
    }
}

@Observable
final class ScanService {
    static let shared = ScanService()

    static let minimumSeconds = 20.0
    static let maximumSeconds = 90.0

    /// The latest scans, newest first.
    private(set) var scans: [Scan] = []
    @ObservationIgnored private var watcher: Task<Void, Never>?
    @ObservationIgnored private let api = ConvexAPI.shared

    // MARK: Reading

    /// The newest finished scan of a place.
    func ready(for placeID: String) -> Scan? { scans.first { $0.placeID == placeID && $0.isReady } }

    /// A scan of this place that is waiting or being built.
    func working(for placeID: String) -> Scan? { scans.first { $0.placeID == placeID && $0.isWorking } }

    /// The newest scan of this place, if it failed.
    func failed(for placeID: String) -> Scan? {
        guard let newest = scans.first(where: { $0.placeID == placeID }), newest.isFailed else { return nil }
        return newest
    }

    func scan(_ id: String) -> Scan? { scans.first { $0.id == id } }

    /// Keep the list fresh while the app is open. Safe to call from every screen that shows scans.
    func watch() {
        guard watcher == nil else { return }
        watcher = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                // Often while something is being built, slowly otherwise.
                let busy = self?.scans.contains { $0.isWorking } ?? false
                try? await Task.sleep(for: .seconds(busy ? 3 : 12))
            }
        }
    }

    func refresh() async {
        guard let rows = try? await api.query("scans:recent") as? [[String: Any]] else { return }
        let next = rows.compactMap(Scan.init)
        if next != scans { scans = next }
    }

    // MARK: Sending a video

    /// Shrink the video, upload it and queue the scan. `step` reports what is happening and how far along it is.
    func submit(video: URL, place: Place, step: @escaping (String, Double) -> Void) async throws -> String {
        let asset = AVURLAsset(url: video)
        let seconds = (try? await asset.load(.duration).seconds) ?? 0
        guard seconds >= ScanService.minimumSeconds - 1 else { throw ScanError.tooShort }

        step("Getting your video ready", 0.05)
        let small = await compress(asset) ?? video
        defer { if small != video { try? FileManager.default.removeItem(at: small) } }

        step("Sending your video", 0.15)
        guard let target = try await api.mutation("scans:generateUploadUrl") as? String, let url = URL(string: target) else {
            throw ScanError.upload
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 900
        request.setValue(small.pathExtension.lowercased() == "mp4" ? "video/mp4" : "video/quicktime", forHTTPHeaderField: "Content-Type")
        let progress = UploadProgress { fraction in
            Task { @MainActor in step("Sending your video", 0.15 + 0.8 * fraction) }
        }
        let (body, response) = try await URLSession.shared.upload(for: request, fromFile: small, delegate: progress)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let storageID = json["storageId"] as? String else { throw ScanError.upload }

        step("Almost there", 0.97)
        let created = try await api.mutation("scans:create", [
            "placeId": place.id, "placeName": place.name,
            "lat": place.coords.lat, "lng": place.coords.lng,
            "videoId": storageID, "seconds": seconds,
        ])
        await refresh()
        guard let id = created as? String else { throw ScanError.upload }
        return id
    }

    /// 720p is plenty for the 3D build and a fraction of the upload.
    private func compress(_ asset: AVURLAsset) async -> URL? {
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else { return nil }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("scan-\(UUID().uuidString).mp4")
        do {
            try await export.export(to: out, as: .mp4)
            return out
        } catch {
            return nil
        }
    }

    // MARK: The finished space

    /// The model file for a scan, downloaded once and kept in the cache.
    func modelFile(for scan: Scan) async throws -> URL {
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("scans", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("\(scan.id).bin")
        if FileManager.default.fileExists(atPath: file.path) { return file }
        guard let remote = scan.modelURL else { throw ScanError.download }
        let (temp, response) = try await URLSession.shared.download(from: remote)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ScanError.download }
        try? FileManager.default.removeItem(at: file)
        try FileManager.default.moveItem(at: temp, to: file)
        return file
    }
}

/// Reports how much of an upload has left the phone.
nonisolated final class UploadProgress: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let onProgress: @Sendable (Double) -> Void

    init(_ onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        onProgress(Double(totalBytesSent) / Double(totalBytesExpectedToSend))
    }
}
