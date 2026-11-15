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
        name = scan.name == scan.placeName ? scan.placeName : "\(scan.name) · \(scan.placeName)"
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

/// On a place: its 3D spaces (there can be several, each with a name), the ones being built,
/// and a button to add another. The explorer who made a space can rename or delete it.
struct ScanPlaceRow: View {
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toast
    var place: Place
    /// Called before a cover is presented, to close the sheet this row sits in.
    var before: (() -> Void)?
    private let scans = ScanService.shared

    @State private var deleting: Scan?
    @State private var renaming: Scan?
    @State private var newName = ""

    var body: some View {
        let spaces = scans.spaces(for: place.id)
        let building = scans.building(for: place.id)
        VStack(spacing: 8) {
            ForEach(spaces) { space in
                row(icon: "cube.transparent.fill", tint: Palette.accent, title: space.name,
                    detail: space.creatorName.map { "3D space by \($0)" } ?? "Walk around in 3D",
                    scan: space) { open(.scanViewer(scanID: space.id)) }
            }
            ForEach(building) { scan in
                row(icon: "hammer.fill", tint: Palette.ink, title: "Building \(scan.name)",
                    detail: "\(Int((scan.progress * 100).rounded()))% · \(scan.message)", scan: scan, action: nil)
            }
            Button { open(.scan(placeID: place.id)) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Palette.ink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(spaces.isEmpty && building.isEmpty ? "Scan this place in 3D" : "Add another 3D space")
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                        Text(scans.failed(for: place.id)?.message ?? "Film a short walk and others can explore it")
                            .font(.system(size: 13)).foregroundStyle(Palette.muted).lineLimit(2)
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.muted)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            }
            .buttonStyle(PressStyle())
        }
        .onAppear { scans.watch() }
        .confirmationDialog("Delete \(deleting?.name ?? "this space")?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible) {
            Button("Delete 3D space", role: .destructive) {
                guard let scan = deleting else { return }
                Task {
                    do {
                        try await scans.delete(scan)
                        toast.show("\(scan.name) was deleted", icon: "trash")
                    } catch {
                        toast.show(error.localizedDescription, icon: "exclamationmark.triangle")
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It is removed for everyone and cannot be brought back.")
        }
        .alert("Rename 3D space", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Save") {
                guard let scan = renaming else { return }
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                Task {
                    do { try await scans.rename(scan, to: name) } catch { toast.show(error.localizedDescription, icon: "exclamationmark.triangle") }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// One space: tap the row to open it. Whoever made it gets a menu to rename or delete it.
    private func row(icon: String, tint: Color, title: String, detail: String, scan: Scan, action: (() -> Void)?) -> some View {
        HStack(spacing: 4) {
            Button { action?() } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink).lineLimit(1)
                        Text(detail).font(.system(size: 13)).foregroundStyle(Palette.muted).lineLimit(2)
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if action != nil, !scan.mine {
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.muted)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .disabled(action == nil)
            if scan.mine {
                Menu {
                    if scan.isReady {
                        Button {
                            newName = scan.name
                            renaming = scan
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                    }
                    Button(role: .destructive) { deleting = scan } label: {
                        Label(scan.isReady ? "Delete" : "Stop and delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.muted)
                        .frame(width: 40, height: 42)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("More for \(scan.name)")
            }
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
