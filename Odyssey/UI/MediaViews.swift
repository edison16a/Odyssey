//
//  MediaViews.swift
//  Odyssey
//
//  Two players for the mockup's own media. SVGArtView draws the hand made
//  SVG art (the engraved explorer portraits, the arrival scene) with its
//  patterns and animations intact. LoopingVideoView plays the landing
//  montage silently on a loop behind the sign in screen.
//

import AVFoundation
import Foundation
import SwiftUI
import UIKit
import WebKit

/// SVG art from the bundle (by name) or from markup, drawn exactly as authored.
struct SVGArtView: UIViewRepresentable {
    var name: String? = nil
    var markup: String? = nil

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        view.isUserInteractionEnabled = false
        load(into: view)
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        let key = (name ?? "") + String((markup ?? "").hashValue)
        if view.accessibilityIdentifier != key { load(into: view) }
    }

    private func load(into view: WKWebView) {
        var svg = markup ?? ""
        if let name, let url = Bundle.main.url(forResource: name, withExtension: "svg"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            svg = text
        }
        view.accessibilityIdentifier = (name ?? "") + String((markup ?? "").hashValue)
        let page = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>html,body{margin:0;padding:0;background:transparent;width:100%;height:100%;overflow:hidden}
        body{display:flex;align-items:center;justify-content:center}
        svg{width:100%;height:100%;display:block}</style></head><body>\(svg)</body></html>
        """
        view.loadHTMLString(page, baseURL: nil)
    }
}

/// A muted video that loops forever, with a poster until the first frame shows.
struct LoopingVideoView: UIViewRepresentable {
    var resource: String
    var ext: String = "mp4"

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else { return view }
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        view.looper = AVPlayerLooper(player: player, templateItem: item)
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        player.play()
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.playerLayer.player?.play()
    }

    static func dismantleUIView(_ uiView: PlayerView, coordinator: ()) {
        uiView.playerLayer.player?.pause()
    }

    final class PlayerView: UIView {
        var looper: AVPlayerLooper?
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

/// An explorer's engraved portrait, the bank note style art from the mockup.
struct ExplorerPortrait: View {
    var explorerID: String
    var width: CGFloat = 86

    var body: some View {
        // Pre-rendered from the mockup's SVG (tools/render-portraits.mjs), so no web view is needed.
        Image("portrait-" + explorerID)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: width, height: width * 1.2)
            .accessibilityHidden(true)
    }
}
