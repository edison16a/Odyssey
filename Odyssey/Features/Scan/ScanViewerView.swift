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
            phase = .ready(model: file, meta: ScanViewerView.meta(meta, with: scan.features))
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

extension ScanViewerView {
    /// The scan's path data plus the features found in the video, so the page can label them in the space.
    static func meta(_ meta: String, with features: [ScanFeature]) -> String {
        guard !features.isEmpty,
              var object = try? JSONSerialization.jsonObject(with: Data(meta.utf8)) as? [String: Any] else { return meta }
        object["features"] = features.map { ["label": $0.label, "tone": $0.wheelchair, "frame": $0.frame] }
        guard let data = try? JSONSerialization.data(withJSONObject: object), let text = String(data: data, encoding: .utf8) else { return meta }
        return text
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
            if !spaces.isEmpty { PlaceInsideCard(place: place) }
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

/// What explorers' videos show of the inside of a place: whether a wheelchair gets in, and the
/// stairs, lifts, restrooms, seating and so on that were filmed. All of it comes from video and
/// is labelled that way; nothing here has been checked by a person.
struct PlaceInsideCard: View {
    var place: Place
    private let scans = ScanService.shared
    @State private var showAll = false

    var body: some View {
        let access = scans.access(for: place.id)
        let features = scans.features(for: place.id)
        if access != nil || !features.isEmpty || scans.isReading(place.id) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Inside this place").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                if let access { banner(access) }
                if scans.isReading(place.id) {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Looking through a video for stairs, doors and other features").font(.system(size: 13)).foregroundStyle(Palette.muted)
                    }
                }
                if !features.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array((showAll ? features : Array(features.prefix(4))).enumerated()), id: \.offset) { _, item in
                            row(item.feature, space: item.space)
                        }
                    }
                    if features.count > 4 {
                        Button(showAll ? "Show fewer" : "Show all \(features.count) features") {
                            withAnimation(.easeInOut(duration: 0.25)) { showAll.toggle() }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.accentInk)
                    }
                }
                Text("From explorers' videos, read by AI. Not checked by a person.")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
    }

    private func banner(_ access: PlaceAccess) -> some View {
        let look: (title: String, icon: String, tint: Color, soft: Color) = {
            switch access.verdict {
            case "not_accessible": return ("Not wheelchair accessible", "figure.roll", Palette.danger, Palette.danger.opacity(0.12))
            case "partly": return ("Partly wheelchair accessible", "figure.roll", Palette.flame, Palette.flameSoft)
            case "accessible": return ("Step-free where it was filmed", "figure.roll", Palette.success, Palette.successSoft)
            default: return ("Wheelchair access unknown", "questionmark.circle", Palette.muted, Palette.surface3)
            }
        }()
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: look.icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(look.tint, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(look.title).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                Text(access.reason).font(.system(size: 13)).foregroundStyle(Palette.ink2).fixedSize(horizontal: false, vertical: true)
                Text("Seen in \(access.space)").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(look.soft, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    private func row(_ feature: ScanFeature, space: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: feature.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(feature.isBarrier ? Palette.danger : feature.helps ? Palette.success : Palette.ink2)
                .frame(width: 26, height: 26)
                .background(.white, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(feature.label).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
                    if feature.certainty != "seen" {
                        Text("Likely").font(.system(size: 10, weight: .bold)).foregroundStyle(Palette.muted)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.white, in: Capsule())
                    }
                }
                Text("\(feature.detail) Seen in \(space).")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
