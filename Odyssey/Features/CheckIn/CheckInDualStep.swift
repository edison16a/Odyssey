//
//  CheckInDualStep.swift
//  Odyssey
//
//  The camera, where every post starts. Both cameras show at once, the
//  place big and you in the corner (tap the corner to swap), and one press
//  of the shutter takes both. Under the shutter you can switch to a video
//  walkthrough or to today's Daily Map. Without a camera (the simulator)
//  the viewfinder shows sample photos and says so.
//

import AVFoundation
import Foundation
import SwiftUI
import UIKit

enum PostMode: String, CaseIterable {
    case picture = "Picture"
    case video = "Video"
    case dailyMap = "Daily Map"
}

struct CheckInDualStep: View {
    var camera: DualCamera
    var hint: String
    var fallbackPlace: String
    var fallbackSelfie: String
    var onTaken: (_ place: UIImage, _ selfie: UIImage) -> Void
    var onMode: (PostMode) -> Void

    @State private var back: UIImage?
    @State private var front: UIImage?
    @State private var swapped = false
    @State private var flashing = false
    @State private var busy = false

    private var live: Bool { camera.isAvailable && !camera.permissionDenied && camera.isRunning }
    private var taken: Bool { back != nil && front != nil }

    var body: some View {
        VStack(spacing: 14) {
            viewfinder
            Group { if taken { decision } else { shutterBar } }
                .frame(height: 74)
            modes
        }
        .task { await camera.start() }
    }

    // MARK: Viewfinder

    private var viewfinder: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: "#111111")
            pane(big: true).id("big-\(swapped)")
            pane(big: false)
                .id("inset-\(swapped)")
                .frame(width: 112, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white, lineWidth: 2.5))
                .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                .padding(14)
                .onTapGesture {
                    Haptics.soft()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { swapped.toggle() }
                }
                .accessibilityLabel("Swap photos")
            overlayText
            Color.white.opacity(flashing ? 1 : 0).allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
    }

    /// The place or the selfie, live, taken, or a sample when there is no camera.
    @ViewBuilder private func pane(big: Bool) -> some View {
        let showsBack = big != swapped
        if let image = showsBack ? back : front {
            Color.clear.overlay { Image(uiImage: image).resizable().scaledToFill() }.clipped()
        } else if live && camera.isDual {
            LayerPreview(layer: showsBack ? camera.engine.backLayer : camera.engine.frontLayer)
        } else if live && showsBack {
            CameraPreview(session: camera.single.engine.session)
        } else if live {
            // One camera at a time on this phone: the selfie is taken right after the place.
            ZStack {
                Color(hex: "#1c1c1f")
                Image(systemName: "person.crop.circle").font(.system(size: 30)).foregroundStyle(.white.opacity(0.7))
            }
        } else {
            PhotoView(path: showsBack ? fallbackPlace : fallbackSelfie)
                .scaleEffect(x: showsBack ? 1 : -1, y: 1)
                .clipped()
        }
    }

    private var overlayText: some View {
        VStack {
            if !taken {
                Text(hint)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(.top, 18)
            }
            Spacer()
            if !live && !taken {
                Text(camera.permissionDenied ? "Camera access is off. Showing sample photos." : "No camera here. Showing sample photos.")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }

    // MARK: Controls

    private var shutterBar: some View {
        Button(action: shoot) {
            ZStack {
                Circle().strokeBorder(Palette.ink, lineWidth: 4).frame(width: 74, height: 74)
                Circle().fill(Palette.ink).frame(width: 58, height: 58).scaleEffect(busy ? 0.86 : 1)
            }
        }
        .buttonStyle(PressStyle(scale: 0.94))
        .disabled(busy)
        .accessibilityLabel("Take photos")
    }

    private var decision: some View {
        HStack(spacing: 8) {
            Button("Retake") {
                back = nil
                front = nil
                Task { await camera.start() }
            }
            .buttonStyle(.pill(.soft, fill: true))
            Button("Use photos") {
                if let back, let front { onTaken(back, front) }
            }
            .buttonStyle(.pill(.primary, fill: true))
        }
    }

    private var modes: some View {
        HStack(spacing: 6) {
            ForEach(PostMode.allCases, id: \.self) { mode in
                Button {
                    Haptics.tap()
                    if mode != .picture { onMode(mode) }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 14, weight: mode == .picture ? .bold : .semibold))
                        .foregroundStyle(mode == .picture ? .white : Palette.muted)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(mode == .picture ? Palette.ink : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Palette.surface2, in: Capsule())
    }

    /// One press, both photos. Samples stand in where there is no camera.
    private func shoot() {
        busy = true
        Haptics.tap()
        withAnimation(.easeOut(duration: 0.12)) { flashing = true }
        Task {
            var shots: (back: UIImage?, front: UIImage?) = (nil, nil)
            if live { shots = await camera.capture() }
            withAnimation(.easeOut(duration: 0.25)) { flashing = false }
            back = shots.back ?? UIImage(named: Media.name(for: fallbackPlace))
            front = shots.front ?? UIImage(named: Media.name(for: fallbackSelfie))
            busy = false
            camera.stop()
        }
    }
}

/// Shows a preview layer the camera session already feeds.
struct LayerPreview: UIViewRepresentable {
    let layer: CALayer

    func makeUIView(context: Context) -> HostView {
        let view = HostView()
        view.hosted = layer
        view.layer.addSublayer(layer)
        return view
    }

    func updateUIView(_ view: HostView, context: Context) {
        if layer.superlayer !== view.layer { view.layer.addSublayer(layer) }
    }

    final class HostView: UIView {
        var hosted: CALayer?

        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            hosted?.frame = bounds
            CATransaction.commit()
        }
    }
}
