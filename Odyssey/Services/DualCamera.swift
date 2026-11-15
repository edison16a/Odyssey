//
//  DualCamera.swift
//  Odyssey
//
//  Both cameras at once for a post: the place through the back camera and
//  you through the front, taken by one press of the shutter. Phones that can
//  run two cameras together (iPhone XS and later) use a multi camera session
//  with a live preview of each. Older phones fall back to the single camera,
//  taking the back photo and then the selfie straight after, with no second
//  tap.
//

import AVFoundation
import CoreMedia
import Foundation
import Observation
import UIKit

@Observable
final class DualCamera {
    var isRunning = false
    var permissionDenied = false

    @ObservationIgnored let engine = DualCameraEngine()
    /// The single camera used where two at once are not supported.
    @ObservationIgnored let single = CameraModel()
    @ObservationIgnored private var wanted = false

    var isAvailable: Bool { single.isAvailable }
    var isDual: Bool { AVCaptureMultiCamSession.isMultiCamSupported }

    func start() async {
        guard isAvailable else { return }
        wanted = true
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard granted else {
            permissionDenied = true
            return
        }
        guard wanted else { return }
        if isDual {
            await engine.start()
        } else {
            await single.start(side: .back)
        }
        if !wanted { stop() } else { isRunning = true }
    }

    func stop() {
        wanted = false
        isRunning = false
        engine.stop()
        single.stop()
    }

    /// One press: the place and you. Either can be nil if that camera failed.
    func capture() async -> (back: UIImage?, front: UIImage?) {
        guard isRunning else { return (nil, nil) }
        if isDual {
            let shots = await engine.capture()
            return (shots.back, shots.front.map(Self.mirrored))
        }
        let back = await single.capture()
        await single.switchTo(.front)
        // Give the front camera a moment to settle its exposure before the selfie.
        try? await Task.sleep(for: .milliseconds(350))
        let front = await single.capture()
        await single.switchTo(.back)
        return (back, front)
    }

    private static func mirrored(_ image: UIImage) -> UIImage {
        guard let cg = image.cgImage else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: .leftMirrored)
    }
}

/// The multi camera session. Everything here runs on its own queue.
nonisolated final class DualCameraEngine: @unchecked Sendable {
    let session: AVCaptureMultiCamSession
    let backLayer: AVCaptureVideoPreviewLayer
    let frontLayer: AVCaptureVideoPreviewLayer
    private let queue = DispatchQueue(label: "odyssey.dualcamera")
    private let backOutput = AVCapturePhotoOutput()
    private let frontOutput = AVCapturePhotoOutput()
    private var configured = false
    private var grabs: [PhotoGrab] = []

    init() {
        let session = AVCaptureMultiCamSession()
        self.session = session
        backLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        frontLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        backLayer.videoGravity = .resizeAspectFill
        frontLayer.videoGravity = .resizeAspectFill
    }

    func start() async {
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            queue.async {
                if !self.configured { self.configure() }
                if !self.session.isRunning { self.session.startRunning() }
                done.resume()
            }
        }
    }

    func stop() {
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    private func configure() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        add(.back, output: backOutput, layer: backLayer)
        add(.front, output: frontOutput, layer: frontLayer)
        configured = true
    }

    /// Wire one camera to its photo output and its preview, picking a format both can share.
    private func add(_ position: AVCaptureDevice.Position, output: AVCapturePhotoOutput, layer: AVCaptureVideoPreviewLayer) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return }
        Self.useMultiCamFormat(device)
        session.addInputWithNoConnections(input)
        guard let port = input.ports(for: .video, sourceDeviceType: device.deviceType, sourceDevicePosition: position).first,
              session.canAddOutput(output) else { return }
        session.addOutputWithNoConnections(output)
        output.maxPhotoQualityPrioritization = .balanced
        let photo = AVCaptureConnection(inputPorts: [port], output: output)
        if session.canAddConnection(photo) { session.addConnection(photo) }
        let preview = AVCaptureConnection(inputPort: port, videoPreviewLayer: layer)
        if session.canAddConnection(preview) { session.addConnection(preview) }
    }

    /// The largest format no wider than 1920 that supports running with the other camera.
    private static func useMultiCamFormat(_ device: AVCaptureDevice) {
        let formats = device.formats.filter { $0.isMultiCamSupported }
        let fit = formats.filter { CMVideoFormatDescriptionGetDimensions($0.formatDescription).width <= 1920 }
        guard let best = fit.max(by: {
            CMVideoFormatDescriptionGetDimensions($0.formatDescription).width < CMVideoFormatDescriptionGetDimensions($1.formatDescription).width
        }) ?? formats.first, (try? device.lockForConfiguration()) != nil else { return }
        device.activeFormat = best
        device.unlockForConfiguration()
    }

    /// Fire both shutters together and wait for both photos.
    func capture() async -> (back: UIImage?, front: UIImage?) {
        async let back = shoot(backOutput)
        async let front = shoot(frontOutput)
        return await (back, front)
    }

    private func shoot(_ output: AVCapturePhotoOutput) async -> UIImage? {
        await withCheckedContinuation { continuation in
            queue.async {
                guard self.session.isRunning, output.connection(with: .video) != nil else {
                    continuation.resume(returning: nil)
                    return
                }
                let grab = PhotoGrab { [weak self] grab, image in
                    continuation.resume(returning: image)
                    self?.queue.async { self?.grabs.removeAll { $0 === grab } }
                }
                self.grabs.append(grab)
                output.capturePhoto(with: AVCapturePhotoSettings(), delegate: grab)
            }
        }
    }
}

/// Receives one photo and hands it back once.
nonisolated private final class PhotoGrab: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let done: (PhotoGrab, UIImage?) -> Void

    init(done: @escaping (PhotoGrab, UIImage?) -> Void) { self.done = done }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        done(self, photo.fileDataRepresentation().flatMap(UIImage.init(data:)))
    }
}
