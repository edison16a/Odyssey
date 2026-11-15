//
//  ScanViewerView.swift
//  Odyssey
//
//  Walk around inside a 3D scan. The model is downloaded from Convex once
//  and kept on the phone; the page in ScanViewerPage draws it, with a thumb
//  stick to walk and a drag to look around. The page asks for its files on
//  a private "odyssey-scan" address that this screen answers itself, so the
//  model never has to leave the phone again.
//

import SwiftUI
import WebKit

struct ScanViewerView: View {
    @Environment(AppRouter.self) private var router
    var scanID: String

    private enum Phase {
        case loading
        case ready(model: URL, meta: String)
        case failed(String)
    }

    @State private var phase: Phase = .loading
    @State private var drawn = false
    @State private var name = ""
    private let scans = ScanService.shared

    var body: some View {
        ZStack {
            Color(hex: "#0b0b0c").ignoresSafeArea()
            switch phase {
            case .ready(let model, let meta):
                ScanWebView(model: model, meta: meta) { drawn = true } onProblem: { text in
                    phase = .failed(text)
                }
                .ignoresSafeArea()
            case .failed(let text):
                VStack(spacing: 12) {
                    Image(systemName: "cube.transparent").font(.system(size: 40, weight: .semibold))
                    Text("This space could not be opened").font(.system(size: 20, weight: .bold))
                    Text(text).font(.system(size: 14)).multilineTextAlignment(.center).opacity(0.75)
                    Button("Try again") {
                        phase = .loading
                        Task { await load() }
                    }
                    .buttonStyle(.pill(.light))
                    .padding(.top, 8)
                }
                .foregroundStyle(.white)
                .padding(30)
            case .loading:
                EmptyView()
            }
            if !drawn, !isFailed {
                VStack(spacing: 14) {
                    ProgressView().controlSize(.large).tint(.white)
                    Text("Opening the 3D space").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                }
            }
        }
        .overlay(alignment: .top) {
            HStack(spacing: 10) {
                IconButton(icon: "close", kind: .dark, label: "Close") { router.dismissCover() }
                if !name.isEmpty {
                    Text(name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(.black.opacity(0.45), in: Capsule())
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
        .statusBarHidden()
        .task { await load() }
    }

    private var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    private func load() async {
        scans.watch()
        if scans.scan(scanID) == nil { await scans.refresh() }
        guard let scan = scans.scan(scanID), scan.isReady, let meta = scan.meta else {
            phase = .failed("This scan is not ready yet.")
            return
        }
        name = scan.placeName
        do {
            let file = try await scans.modelFile(for: scan)
            phase = .ready(model: file, meta: meta)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

/// The web view that draws the scan, and the handler that hands it the page, the path and the model.
private struct ScanWebView: UIViewRepresentable {
    var model: URL
    var meta: String
    var onReady: () -> Void
    var onProblem: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(model: model, meta: meta, onReady: onReady, onProblem: onProblem) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(context.coordinator, forURLScheme: Coordinator.scheme)
        config.userContentController.add(context.coordinator, name: "scan")
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .black
        view.scrollView.backgroundColor = .black
        view.scrollView.isScrollEnabled = false
        view.scrollView.bounces = false
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.isInspectable = true
        view.load(URLRequest(url: URL(string: "\(Coordinator.scheme)://viewer/index.html")!))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.configuration.userContentController.removeScriptMessageHandler(forName: "scan")
    }

    final class Coordinator: NSObject, WKURLSchemeHandler, WKScriptMessageHandler {
        static let scheme = "odyssey-scan"
        let model: URL
        let meta: String
        let onReady: () -> Void
        let onProblem: (String) -> Void

        init(model: URL, meta: String, onReady: @escaping () -> Void, onProblem: @escaping (String) -> Void) {
            self.model = model
            self.meta = meta
            self.onReady = onReady
            self.onProblem = onProblem
        }

        func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
            guard let url = task.request.url else { return }
            let data: Data
            let type: String
            switch url.lastPathComponent {
            case "meta.json":
                data = Data(meta.utf8)
                type = "application/json"
            case "model.bin":
                data = (try? Data(contentsOf: model, options: .mappedIfSafe)) ?? Data()
                type = "application/octet-stream"
            default:
                data = Data(ScanViewerPage.html.utf8)
                type = "text/html; charset=utf-8"
            }
            let headers = ["Content-Type": type, "Content-Length": "\(data.count)", "Access-Control-Allow-Origin": "*"]
            guard let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers) else { return }
            task.didReceive(response)
            task.didReceive(data)
            task.didFinish()
        }

        func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
            if type == "ready" {
                onReady()
            } else if type == "error" {
                onProblem(body["detail"] as? String ?? "The 3D view stopped.")
            }
        }
    }
}

/// On a place: open its 3D space, show how the build is going, or offer to scan it.
struct ScanPlaceRow: View {
    @Environment(AppRouter.self) private var router
    var place: Place
    /// Called before a cover is presented, to close the sheet this row sits in.
    var before: (() -> Void)?
    private let scans = ScanService.shared

    var body: some View {
        let ready = scans.ready(for: place.id)
        let working = scans.working(for: place.id)
        VStack(spacing: 8) {
            if let ready {
                Button { open(.scanViewer(scanID: ready.id)) } label: {
                    row(icon: "cube.transparent.fill", tint: Palette.accent,
                        title: "Walk around in 3D",
                        detail: "Explore the inside of \(place.name) from here",
                        trailing: AnyView(Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))))
                }
                .buttonStyle(PressStyle())
            }
            if let working {
                row(icon: "hammer.fill", tint: Palette.ink,
                    title: ready == nil ? "Building the 3D view" : "Building a newer 3D view",
                    detail: working.message,
                    trailing: AnyView(Text("\(Int((working.progress * 100).rounded()))%").font(.system(size: 13, weight: .bold)).monospacedDigit()))
            } else if ready == nil {
                Button { open(.scan(placeID: place.id)) } label: {
                    row(icon: "video.fill", tint: Palette.ink,
                        title: "Scan this place in 3D",
                        detail: scans.failed(for: place.id)?.message ?? "Film a short walk and others can explore it",
                        trailing: AnyView(Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))))
                }
                .buttonStyle(PressStyle())
            }
        }
        .onAppear { scans.watch() }
    }

    private func row(icon: String, tint: Color, title: String, detail: String, trailing: AnyView) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                Text(detail).font(.system(size: 13)).foregroundStyle(Palette.muted).lineLimit(2)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            trailing.foregroundStyle(Palette.muted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    private func open(_ cover: Cover) {
        Haptics.tap()
        guard let before else {
            router.present(cover)
            return
        }
        before()
        // Let the sheet finish closing, or the cover can fail to present.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.present(cover) }
    }
}
