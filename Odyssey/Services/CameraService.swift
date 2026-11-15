//
//  CameraService.swift
//  Odyssey
//
//  The single camera, for walkthroughs and for phones that cannot run both
//  cameras at once (DualCamera uses it there, taking the place and then the
//  selfie from one press). Walkthroughs record a short video with sound. All capture work runs on its own queue; the SwiftUI
//  side only sees the published state.
//
//  The simulator has no camera, so isAvailable is false there and the
//  check-in screens fall back to the place photo and a sample selfie.
//

import Foundation
import AVFoundation
import Observation
import SwiftUI
import UIKit

@Observable
final class CameraModel {
    enum Side { case back, front }

    var side: Side = .back
    var isRunning = false
    var isRecording = false
    var permissionDenied = false
    var flash = false

    @ObservationIgnored let engine = CameraEngine()
    /// False once stop() is called, so a start still waiting on permission or setup does not turn the camera back on.
    @ObservationIgnored private var wanted = false

    /// Looked up once; screens read this several times on every redraw.
    private static let hasCamera = AVCaptureDevice.default(for: .video) != nil

    var isAvailable: Bool { CameraModel.hasCamera }

    /// Ask for camera (and microphone, for video) access, then start the preview.
    func start(side: Side = .back, video: Bool = false) async {
        guard isAvailable else { return }
        wanted = true
        var granted = await AVCaptureDevice.requestAccess(for: .video)
        if video { _ = await AVCaptureDevice.requestAccess(for: .audio) }
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized { granted = true }
        guard granted else {
            permissionDenied = true
            return
        }
        guard wanted else { return }
        self.side = side
        await engine.configure(position: side == .back ? .back : .front, video: video)
        // The screen closed while the session was starting: turn it straight back off.
        guard wanted else {
            engine.stop()
            return
        }
        isRunning = true
    }

    func stop() {
        wanted = false
        engine.stop()
        isRunning = false
    }

    func flip() async {
        side = side == .back ? .front : .back
        await engine.switchCamera(to: side == .back ? .back : .front)
    }

    func switchTo(_ side: Side) async {
        guard side != self.side else { return }
        self.side = side
        await engine.switchCamera(to: side == .back ? .back : .front)
    }

    /// Take one photo with the current camera. Front photos come back mirrored like a selfie.
    func capture() async -> UIImage? {
        guard isRunning else { return nil }
        let image = await engine.capturePhoto(flash: flash && side == .back)
        guard let image, side == .front, let cg = image.cgImage else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: .leftMirrored)
    }

    func startRecording() {
        isRecording = true
        engine.startRecording()
    }

    /// Stop the walkthrough recording. Returns the movie file.
    func stopRecording() async -> URL? {
        isRecording = false
        return await engine.stopRecording()
    }
}

/// The AVFoundation side. Everything here runs on the session queue.
nonisolated final class CameraEngine: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "odyssey.camera")
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var input: AVCaptureDeviceInput?
    private var photoContinuation: CheckedContinuation<UIImage?, Never>?
    private var movieContinuation: CheckedContinuation<URL?, Never>?

    func configure(position: AVCaptureDevice.Position, video: Bool) async {
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            queue.async {
                self.session.beginConfiguration()
                self.session.sessionPreset = video ? .high : .photo
                self.session.inputs.forEach { self.session.removeInput($0) }
                self.session.outputs.forEach { self.session.removeOutput($0) }
                if let device = Self.device(position), let input = try? AVCaptureDeviceInput(device: device),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.input = input
                }
                if video {
                    if let mic = AVCaptureDevice.default(for: .audio), let audio = try? AVCaptureDeviceInput(device: mic),
                       self.session.canAddInput(audio) {
                        self.session.addInput(audio)
                    }
                    if self.session.canAddOutput(self.movieOutput) { self.session.addOutput(self.movieOutput) }
                } else if self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                    self.photoOutput.maxPhotoQualityPrioritization = .balanced
                }
                self.session.commitConfiguration()
                if !self.session.isRunning { self.session.startRunning() }
                done.resume()
            }
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func switchCamera(to position: AVCaptureDevice.Position) async {
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            queue.async {
                guard let device = Self.device(position), let next = try? AVCaptureDeviceInput(device: device) else {
                    done.resume()
                    return
                }
                self.session.beginConfiguration()
                if let current = self.input { self.session.removeInput(current) }
                if self.session.canAddInput(next) {
                    self.session.addInput(next)
                    self.input = next
                } else if let current = self.input {
                    self.session.addInput(current)
                }
                self.session.commitConfiguration()
                done.resume()
            }
        }
    }

    func capturePhoto(flash: Bool) async -> UIImage? {
        await withCheckedContinuation { continuation in
            queue.async {
                // One shot at a time: a second capture would overwrite the first continuation and leave it hanging.
                // Capturing with no live video connection throws, so check the session is really running.
                guard self.session.outputs.contains(self.photoOutput), self.session.isRunning,
                      self.photoOutput.connection(with: .video) != nil, self.photoContinuation == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                self.photoContinuation = continuation
                let settings = AVCapturePhotoSettings()
                if flash, self.photoOutput.supportedFlashModes.contains(.on) { settings.flashMode = .on }
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    func startRecording() {
        queue.async {
            guard self.session.outputs.contains(self.movieOutput), !self.movieOutput.isRecording else { return }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("walkthrough-\(UUID().uuidString).mov")
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    func stopRecording() async -> URL? {
        await withCheckedContinuation { continuation in
            queue.async {
                guard self.movieOutput.isRecording else {
                    continuation.resume(returning: nil)
                    return
                }
                self.movieContinuation = continuation
                self.movieOutput.stopRecording()
            }
        }
    }

    private static func device(_ position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
            ?? AVCaptureDevice.default(for: .video)
    }
}

nonisolated extension CameraEngine: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap { UIImage(data: $0) }
        queue.async {
            self.photoContinuation?.resume(returning: image)
            self.photoContinuation = nil
        }
    }

    /// Always called last. If the shot failed before a photo came back (the session stopped mid capture),
    /// the waiting shutter is released here instead of hanging.
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        queue.async {
            self.photoContinuation?.resume(returning: nil)
            self.photoContinuation = nil
        }
    }
}

nonisolated extension CameraEngine: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) {
        queue.async {
            self.movieContinuation?.resume(returning: outputFileURL)
            self.movieContinuation = nil
        }
    }
}

/// The live camera picture.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var mirrored = false

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

/// Photos the user takes live in the app's documents, referenced by file name.
enum PhotoStore {
    /// Made once; reading it used to touch the disk on every photo drawn.
    static let folder: URL = {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("photos")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    /// Decoded photos stay in memory, so feeds and stories do not reread the disk on every redraw.
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 60
        return cache
    }()

    /// Save a JPEG and return its file name.
    static func save(_ image: UIImage, prefix: String = "photo", maxSide: CGFloat = 1600) -> String? {
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let data = resized.jpegData(compressionQuality: 0.85) else { return nil }
        let name = "\(prefix)-\(UUID().uuidString.prefix(8)).jpg"
        do {
            try data.write(to: folder.appendingPathComponent(name), options: .atomic)
            cache.setObject(resized, forKey: name as NSString)
            return name
        } catch {
            return nil
        }
    }

    static func load(_ name: String?) -> UIImage? {
        guard let name, !name.isEmpty else { return nil }
        if let hit = cache.object(forKey: name as NSString) { return hit }
        guard let image = UIImage(contentsOfFile: folder.appendingPathComponent(name).path) else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }
}
