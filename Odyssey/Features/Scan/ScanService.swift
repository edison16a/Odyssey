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

/// Something the video shows of the building: stairs, a ramp, a restroom, seating.
nonisolated struct ScanFeature: Identifiable, Hashable, Sendable {
    /// "stairs", "elevator", "restroom"...
    var kind: String
    var label: String
    var detail: String
    /// What it means for a wheelchair user: "barrier", "helps" or "neutral".
    var wheelchair: String
    /// "seen" when it is clearly in the video, "likely" when it is only partly visible.
    var certainty: String
    /// The video frame it shows best in, which places it in the 3D space.
    var frame: Int

    var id: String { "\(kind)|\(label)|\(frame)" }
    var isBarrier: Bool { wheelchair == "barrier" }
    var helps: Bool { wheelchair == "helps" }

    var icon: String {
        switch kind {
        case "stairs", "step", "escalator": return "figure.stairs"
        case "ramp": return "road.lanes"
        case "elevator": return "arrow.up.arrow.down.square"
        case "entrance": return "door.left.hand.open"
        case "exit": return "figure.walk.departure"
        case "door", "automatic_door": return "door.left.hand.closed"
        case "narrow_passage", "hallway": return "arrow.left.and.right"
        case "restroom": return "toilet"
        case "accessible_restroom": return "figure.roll"
        case "seating": return "chair.lounge"
        case "tables", "workspace": return "table.furniture"
        case "counter", "reception": return "person.crop.rectangle"
        case "kitchen", "food_drinks": return "fork.knife"
        case "power_outlets": return "powerplug"
        case "signage": return "signpost.right"
        case "screen": return "tv"
        default: return "mappin"
        }
    }

    init?(_ json: [String: Any]) {
        guard let kind = json["kind"] as? String, let label = json["label"] as? String else { return nil }
        self.kind = kind
        self.label = label
        detail = json["detail"] as? String ?? ""
        wheelchair = json["wheelchair"] as? String ?? "neutral"
        certainty = json["certainty"] as? String ?? "seen"
        frame = (json["frame"] as? NSNumber)?.intValue ?? 0
    }
}

/// What the videos of a place say about wheelchair access, and which space said it.
nonisolated struct PlaceAccess: Hashable, Sendable {
    /// "not_accessible", "partly", "accessible" or "unknown".
    var verdict: String
    var reason: String
    var space: String
}

/// One scan of a place, as Convex reports it.
nonisolated struct Scan: Identifiable, Hashable, Sendable {
    var id: String
    var placeID: String
    var placeName: String
    /// What the explorer called this space: "Main hall", "Kitchen". A place can have several.
    var name: String
    var creatorName: String?
    /// Whether this phone made the scan, and so may delete or rename it.
    var mine: Bool
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
    /// Reading the video for building features: "pending", "done", "failed", or nil when it never ran.
    var analysis: String?
    var summary: String?
    var features: [ScanFeature]
    /// "not_accessible", "partly", "accessible" or "unknown", from this video alone.
    var wheelchair: String?
    var wheelchairReason: String?

    var isReady: Bool { status == "ready" && modelURL != nil && meta != nil }
    var isWorking: Bool { status == "queued" || status == "processing" }
    var isFailed: Bool { status == "failed" }

    init?(_ json: [String: Any]) {
        guard let id = json["id"] as? String, let placeID = json["placeId"] as? String else { return nil }
        self.id = id
        self.placeID = placeID
        placeName = json["placeName"] as? String ?? ""
        name = json["name"] as? String ?? placeName
        creatorName = json["creatorName"] as? String
        mine = json["mine"] as? Bool ?? false
        status = json["status"] as? String ?? "queued"
        message = json["message"] as? String ?? ""
        progress = (json["progress"] as? NSNumber)?.doubleValue ?? 0
        modelURL = (json["modelUrl"] as? String).flatMap(URL.init(string:))
        meta = json["meta"] as? String
        splats = (json["splats"] as? NSNumber)?.intValue ?? 0
        createdAt = (json["createdAt"] as? NSNumber)?.doubleValue ?? 0
        analysis = json["analysis"] as? String
        summary = json["summary"] as? String
        features = (json["features"] as? [[String: Any]] ?? []).compactMap(ScanFeature.init)
        let access = json["access"] as? [String: Any]
        wheelchair = access?["wheelchair"] as? String
        wheelchairReason = access?["reason"] as? String
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

/// Where scans live. For now they have a Convex deployment of their own (same project), so the
/// scan functions are not overwritten whenever someone else pushes to the shared dev deployment.
/// Set ScanConvexURL in Info.plist to point somewhere else, such as the main deployment once
/// convex/scans.ts is deployed there.
enum ScanConfig {
    static let url: URL = {
        if let s = Bundle.main.object(forInfoDictionaryKey: "ScanConvexURL") as? String, let url = URL(string: s), !s.isEmpty {
            return url
        }
        return URL(string: "https://valiant-jay-880.convex.cloud")!
    }()
}

@Observable
final class ScanService {
    static let shared = ScanService()

    static let minimumSeconds = 20.0
    static let maximumSeconds = 90.0

    /// The latest scans, newest first.
    private(set) var scans: [Scan] = []
    @ObservationIgnored private var watcher: Task<Void, Never>?

    /// Call a scan function over Convex's HTTP API. Scans are public, so no sign-in is sent.
    private func call(_ kind: String, _ path: String, _ args: [String: Any] = [:]) async throws -> Any {
        var request = URLRequest(url: ScanConfig.url.appendingPathComponent("api/\(kind)"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["path": path, "args": args, "format": "json"])
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ConvexError.badResponse }
        guard json["status"] as? String == "success" else {
            throw ConvexError.server(json["errorMessage"] as? String ?? "The scan server did not answer.")
        }
        return json["value"] ?? NSNull()
    }

    // MARK: Reading

    /// This phone's private key for the scans it makes. Convex only lets the phone that made a scan delete it.
    @ObservationIgnored private(set) lazy var ownerKey: String = {
        let defaults = UserDefaults.standard
        if let key = defaults.string(forKey: "scan.ownerKey") { return key }
        let key = UUID().uuidString
        defaults.set(key, forKey: "scan.ownerKey")
        return key
    }()

    /// The finished 3D spaces of a place, newest first.
    func spaces(for placeID: String) -> [Scan] { scans.filter { $0.placeID == placeID && $0.isReady } }

    /// The scans of this place that are waiting or being built.
    func building(for placeID: String) -> [Scan] { scans.filter { $0.placeID == placeID && $0.isWorking } }

    /// The newest scan of this place, if it failed.
    func failed(for placeID: String) -> Scan? {
        guard let newest = scans.first(where: { $0.placeID == placeID }), newest.isFailed else { return nil }
        return newest
    }

    /// Wheelchair access for a place, from all its videos. The worst finding wins: one video showing
    /// stairs as the way in outweighs another that only shows a level room.
    func access(for placeID: String) -> PlaceAccess? {
        let judged = spaces(for: placeID).filter { $0.wheelchair != nil }
        for verdict in ["not_accessible", "partly", "accessible", "unknown"] {
            if let scan = judged.first(where: { $0.wheelchair == verdict }) {
                return PlaceAccess(verdict: verdict, reason: scan.wheelchairReason ?? "", space: scan.name)
            }
        }
        return nil
    }

    /// Everything the videos of a place show, barriers first, each thing once.
    func features(for placeID: String) -> [(feature: ScanFeature, space: String)] {
        var seen = Set<String>()
        var out: [(feature: ScanFeature, space: String)] = []
        for scan in spaces(for: placeID) {
            for feature in scan.features where seen.insert("\(feature.kind)|\(feature.label.lowercased())").inserted {
                out.append((feature, scan.name))
            }
        }
        let rank: (ScanFeature) -> Int = { $0.isBarrier ? 0 : $0.helps ? 1 : 2 }
        return out.enumerated().sorted { a, b in
            rank(a.element.feature) != rank(b.element.feature) ? rank(a.element.feature) < rank(b.element.feature) : a.offset < b.offset
        }.map(\.element)
    }

    /// Whether a video of this place is still being read for features.
    func isReading(_ placeID: String) -> Bool { scans.contains { $0.placeID == placeID && $0.analysis == "pending" } }

    /// A name for the next space at a place: "Main space" for the first, then "Space 2", "Space 3".
    func suggestedName(for placeID: String) -> String {
        let count = scans.filter { $0.placeID == placeID && !$0.isFailed }.count
        return count == 0 ? "Main space" : "Space \(count + 1)"
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
        guard let rows = try? await call("query", "scans:recent", ["owner": ownerKey]) as? [[String: Any]] else { return }
        let next = rows.compactMap(Scan.init)
        if next != scans { scans = next }
    }

    // MARK: Sending a video

    /// Re-encode the video, upload it and queue the scan. `step` reports what is happening and how far along it is.
    func submit(video: URL, place: Place, name: String, creator: String, step: @escaping (String, Double) -> Void) async throws -> String {
        let asset = AVURLAsset(url: video)
        let seconds = (try? await asset.load(.duration).seconds) ?? 0
        guard seconds >= ScanService.minimumSeconds - 1 else { throw ScanError.tooShort }

        step("Getting your video ready", 0.05)
        let small = await compress(asset) ?? video
        defer { if small != video { try? FileManager.default.removeItem(at: small) } }

        step("Sending your video", 0.15)
        guard let target = try await call("mutation", "scans:generateUploadUrl") as? String, let url = URL(string: target) else {
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
        let created = try await call("mutation", "scans:create", [
            "placeId": place.id, "placeName": place.name,
            "name": name, "creatorName": creator, "owner": ownerKey,
            "lat": place.coords.lat, "lng": place.coords.lng,
            "videoId": storageID, "seconds": seconds,
        ])
        await refresh()
        guard let id = created as? String else { throw ScanError.upload }
        return id
    }

    /// Full HD in HEVC: the 3D build tracks the camera by fine detail, so it needs the pixels, and HEVC
    /// keeps the upload around half the size of the original.
    private func compress(_ asset: AVURLAsset) async -> URL? {
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHEVC1920x1080) else { return nil }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("scan-\(UUID().uuidString).mp4")
        do {
            try await export.export(to: out, as: .mp4)
            return out
        } catch {
            return nil
        }
    }

    // MARK: Changing a scan (only the phone that made it)

    func delete(_ scan: Scan) async throws {
        _ = try await call("mutation", "scans:remove", ["id": scan.id, "owner": ownerKey])
        scans.removeAll { $0.id == scan.id }
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("scans", isDirectory: true)
        try? FileManager.default.removeItem(at: folder.appendingPathComponent("\(scan.id).bin"))
        await refresh()
    }

    func rename(_ scan: Scan, to name: String) async throws {
        _ = try await call("mutation", "scans:rename", ["id": scan.id, "owner": ownerKey, "name": name])
        await refresh()
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
