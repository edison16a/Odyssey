//
//  WalkthroughAnalyzer.swift
//  Odyssey
//
//  What a walkthrough says about a place, worked out on the phone. A few
//  evenly spaced frames come out of the video, Vision names what is in
//  them (reading room, cafe, shelves...) and counts the people, and that
//  becomes a vibe, a short summary and what the place is good for. With no
//  video (the simulator), the photos of the simulated walk stand in, and if
//  Vision cannot run Odyssey falls back to what it already knows about the
//  place, so the flow always ends with something useful. Faces in every
//  frame are blurred before anything reads them. Ported from walk-analyze.js.
//

import AVFoundation
import CoreGraphics
import CoreImage
import CoreMedia
import Foundation
import UIKit
import Vision

struct WalkthroughAnalysis {
    var insights: AppState.Insights
    var highlights: [String]
    var frames: Int
}

enum WalkthroughAnalyzer {
    private struct Guess {
        var vibe: String
        var goodFor: [String]
        var highlights: [String]
    }

    private static let guesses: [String: Guess] = [
        "library": Guess(vibe: "quiet", goodFor: ["studying", "reading"], highlights: ["long reading tables", "tall shelves"]),
        "cafe": Guess(vibe: "mixed", goodFor: ["a quick coffee", "catching up"], highlights: ["a busy counter", "window seats"]),
        "food": Guess(vibe: "lively", goodFor: ["groups", "a casual dinner"], highlights: ["an open kitchen", "shared tables"]),
        "books": Guess(vibe: "quiet", goodFor: ["browsing", "a slow afternoon"], highlights: ["packed shelves", "a reading corner"]),
        "museum": Guess(vibe: "quiet", goodFor: ["a date", "an afternoon out"], highlights: ["big open galleries", "natural light"]),
        "gym": Guess(vibe: "lively", goodFor: ["a workout", "meeting people"], highlights: ["tall walls", "a warm up area"]),
        "outdoors": Guess(vibe: "mixed", goodFor: ["a walk", "a picnic"], highlights: ["open space", "great views"]),
        "default": Guess(vibe: "mixed", goodFor: ["a visit with friends"], highlights: ["an easy entrance"]),
    ]

    /// Read the walkthrough. Vision runs off the main actor.
    static func analyze(place: Place, video: URL?, photos: [String] = [], store: AppStore) async -> WalkthroughAnalysis {
        let guess = guessFor(place, store: store)
        var images: [CGImage] = []
        if let video {
            images = await frames(from: video)
        }
        if images.isEmpty {
            let paths = photos.isEmpty ? [place.photo] : Array(photos.prefix(4))
            images = paths.compactMap { UIImage(named: Media.name(for: $0))?.cgImage }
        }
        // A detached task may not capture a var, so hand it a constant copy.
        let stills = images
        let seen = await Task.detached(priority: .userInitiated) { () -> (labels: [String], people: Double) in
            WalkthroughAnalyzer.look(at: stills.map { WalkthroughAnalyzer.blurFaces(in: $0) })
        }.value

        var vibe = guess.vibe
        if !seen.labels.isEmpty || seen.people > 0 {
            if seen.people >= 3 { vibe = "lively" } else if seen.people < 0.5 && guess.vibe != "lively" { vibe = "quiet" }
        }
        let wifi = ["wlan", "yes", "wifi"].contains(place.tags?["internet_access"] ?? "")
        if wifi && vibe == "mixed" { vibe = "quiet" }
        let goodFor = Array(((wifi ? ["studying"] : []) + guess.goodFor).prefix(3))
        let feel = vibe == "quiet" ? "calm and easy to settle into" : vibe == "lively" ? "busy in a good way" : "relaxed with a steady buzz"
        let highlights = seen.labels.isEmpty ? guess.highlights : Array(seen.labels.prefix(3))
        let insights = AppState.Insights(vibe: vibe, summary: "\(place.name) feels \(feel).", tags: goodFor, source: "On device")
        return WalkthroughAnalysis(insights: insights, highlights: highlights, frames: images.count)
    }

    private static func guessFor(_ place: Place, store: AppStore) -> Guess {
        if let category = place.category, let guess = guesses[category] { return guess }
        let cats = store.tasteCategories(place)
        let key = cats.contains("library") ? "library" : cats.contains("coffee") ? "cafe" : cats.contains("food") ? "food" : "default"
        return guesses[key] ?? guesses["default"]!
    }

    /// Up to four evenly spaced stills from the movie, upright and at most 768 points wide.
    nonisolated static func frames(from url: URL, count: Int = 4) async -> [CGImage] {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return [] }
        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isFinite, seconds > 0 else { return [] }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 768, height: 768)
        var images: [CGImage] = []
        for i in 0..<count {
            let at = seconds * (Double(i) + 0.5) / Double(count)
            if let frame = try? await generator.image(at: CMTime(seconds: at, preferredTimescale: 600)) {
                images.append(frame.image)
            }
        }
        return images
    }

    /// The frame with every face Vision finds blurred out.
    nonisolated static func blurFaces(in image: CGImage) -> CGImage {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        guard (try? handler.perform([request])) != nil, let faces = request.results, !faces.isEmpty else { return image }
        let input = CIImage(cgImage: image)
        let blurred = input.clampedToExtent().applyingGaussianBlur(sigma: 24).cropped(to: input.extent)
        let width = input.extent.width
        let height = input.extent.height
        var output = input
        for face in faces {
            let box = face.boundingBox
            let rect = CGRect(x: box.minX * width, y: box.minY * height, width: box.width * width, height: box.height * height)
                .insetBy(dx: -box.width * width * 0.2, dy: -box.height * height * 0.2)
            output = blurred.cropped(to: rect).composited(over: output)
        }
        return CIContext().createCGImage(output, from: input.extent) ?? image
    }

    /// Scene labels seen across the frames, most confident first, and the average number of people.
    nonisolated static func look(at images: [CGImage]) -> (labels: [String], people: Double) {
        var scores: [String: Float] = [:]
        var people = 0
        for image in images {
            let classify = VNClassifyImageRequest()
            let humans = VNDetectHumanRectanglesRequest()
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([classify, humans])
            } catch {
                continue
            }
            for observation in classify.results ?? [] where observation.confidence > 0.25 {
                scores[observation.identifier, default: 0] += observation.confidence
            }
            people += humans.results?.count ?? 0
        }
        let skip: Set<String> = ["structure", "indoor", "outdoor", "people", "adult", "material", "wood_processed", "interior_room"]
        let labels = scores
            .filter { !skip.contains($0.key) }
            .sorted { $0.value > $1.value }
            .prefix(4)
            .map { $0.key.replacingOccurrences(of: "_", with: " ") }
        return (Array(labels), images.isEmpty ? 0 : Double(people) / Double(images.count))
    }
}
