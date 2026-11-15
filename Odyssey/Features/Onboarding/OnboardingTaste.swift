//
//  OnboardingTaste.swift
//  Odyssey
//
//  The taste part of onboarding, after the five questions:
//  1. Connect: your photo library (real), plus Google and Yelp (optional).
//  2. Compile: your photos spiral into the centre like a galaxy while your
//     taste gem gets cut from them.
//  3. Reveal: the finished gem, your explorer type, and the first adventure
//     it picked for you.
//  Photos never leave the phone; they are only thumbnails for the animation.
//

import Foundation
import Photos
import PhotosUI
import SwiftUI

// MARK: Photos

/// Loads small thumbnails from the photo library, a picker, or the bundled place photos.
nonisolated enum OnboardingPhotoLoader {
    static let side: CGFloat = 300

    /// The most recent images in the library, newest first. Needs read access.
    @concurrent
    static func recent(limit: Int = 24) async -> [UIImage] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in assets.append(asset) }

        let manager = PHImageManager.default()
        var images: [UIImage] = []
        for asset in assets {
            if let image = await request(asset, manager: manager, mode: .highQualityFormat) {
                images.append(image)
            } else if let image = await request(asset, manager: manager, mode: .fastFormat) {
                images.append(image)
            }
        }
        return images
    }

    private static func request(_ asset: PHAsset, manager: PHImageManager, mode: PHImageRequestOptionsDeliveryMode) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = mode
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        options.isSynchronous = false
        return await withCheckedContinuation { continuation in
            // Both delivery modes call back exactly once.
            manager.requestImage(for: asset, targetSize: CGSize(width: side, height: side),
                                 contentMode: .aspectFill, options: options) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    /// Images the user picked by hand.
    @concurrent
    static func picked(_ items: [PhotosPickerItem]) async -> [UIImage] {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                images.append(thumbnail(image))
            }
        }
        return images
    }

    /// Bundled place photos, for when there is no library to read.
    @concurrent
    static func samples(_ paths: [String], limit: Int = 24) async -> [UIImage] {
        var images: [UIImage] = []
        var seen = Set<String>()
        for path in paths where images.count < limit {
            let name = Media.name(for: path)
            guard seen.insert(name).inserted, let image = UIImage(named: name) else { continue }
            images.append(thumbnail(image))
        }
        return images
    }

    static func thumbnail(_ image: UIImage) -> UIImage {
        let w = image.size.width, h = image.size.height
        guard w > 0, h > 0, min(w, h) > side else { return image }
        let scale = side / min(w, h)
        return image.preparingThumbnail(of: CGSize(width: w * scale, height: h * scale)) ?? image
    }
}

// MARK: Connect

struct OnboardingConnectStep: View {
    @Environment(AppStore.self) private var store
    @Binding var photos: [UIImage]
    var done: () -> Void

    enum Link: Equatable { case idle, working, connected }

    @State private var photoLink: Link = .idle
    @State private var google: Link = .idle
    @State private var yelp: Link = .idle
    @State private var usingSamples = false
    @State private var picking = false
    @State private var picked: [PhotosPickerItem] = []
    @State private var samples: [UIImage] = []
    @State private var shown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer(minLength: 0)
            Image(systemName: "sparkles")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: 56, height: 56)
                .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.bottom, 6)
            Text("Make Odyssey yours").font(.system(size: 28, weight: .bold)).tracking(-0.8)
            Text("Connect what you already have and we will cut a taste gem that is yours alone.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.72))

            VStack(spacing: 0) {
                photosRow
                divider
                sourceRow(
                    badge: AnyView(letterBadge("G", Color(hex: "#4285F4"))),
                    title: "Google", optional: true, link: google,
                    detail: google == .connected ? "Connected · 38 saved places, 112 reviews"
                        : google == .working ? "Connecting to Google…" : "Saved places and reviews",
                    action: { fakeConnect($google) }
                )
                divider
                sourceRow(
                    badge: AnyView(letterBadge("y", Color(hex: "#d32323"))),
                    title: "Yelp", optional: true, link: yelp,
                    detail: yelp == .connected ? "Connected · 21 bookmarks"
                        : yelp == .working ? "Connecting to Yelp…" : "Bookmarks and check-ins",
                    action: { fakeConnect($yelp) }
                )
            }
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(.white.opacity(0.16), lineWidth: 1))
            .padding(.top, 6)
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)

            HStack(spacing: 8) {
                Image(systemName: "lock.fill").font(.system(size: 11, weight: .semibold))
                Text("Photos stay on your phone. Google and Yelp are optional.")
                    .font(.system(size: 12))
            }
            .foregroundStyle(.white.opacity(0.6))
            .padding(.bottom, 4)

            Button("Build my taste gem") { proceed() }
                .buttonStyle(AuthBigButtonStyle())
                .disabled(photoLink == .working)
            Button("Skip for now") { proceed() }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .photosPicker(isPresented: $picking, selection: $picked, maxSelectionCount: 24, matching: .images)
        .onChange(of: picking) { _, open in
            // Closed the picker without choosing anything: use the sample photos.
            if !open && picked.isEmpty && photoLink != .connected { useSamples() }
        }
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            photoLink = .working
            Task {
                let images = await OnboardingPhotoLoader.picked(items)
                if images.isEmpty { useSamples() } else { connectPhotos(images) }
            }
        }
        .task {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.1)) { shown = true }
            samples = await OnboardingPhotoLoader.samples(store.seed.places.map(\.photo))
        }
    }

    // MARK: Rows

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.12)).frame(height: 1).padding(.leading, 66)
    }

    private var photosRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            sourceRow(
                badge: AnyView(
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(LinearGradient(colors: [Color(hex: "#ff9f0a"), Color(hex: "#ff375f"), Color(hex: "#5e5ce6")],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                ),
                title: "Photos", optional: false, link: photoLink,
                detail: photoDetail,
                action: startPhotos
            )
            if photoLink == .connected && !photos.isEmpty {
                HStack(spacing: -10) {
                    ForEach(Array(photos.prefix(8).enumerated()), id: \.offset) { i, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(.black.opacity(0.5), lineWidth: 1.5))
                            .zIndex(Double(8 - i))
                    }
                    if photos.count > 8 {
                        Text("+\(photos.count - 8)")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.leading, 18)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                .padding(.leading, 66)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var photoDetail: String {
        switch photoLink {
        case .idle: return "Your recent photos show the places you love"
        case .working: return "Reading your library…"
        case .connected:
            return usingSamples ? "Using \(photos.count) sample photos from SF" : "\(photos.count) recent photos ready"
        }
    }

    private func letterBadge(_ letter: String, _ color: Color) -> some View {
        Text(letter)
            .font(.system(size: 20, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .frame(width: 40, height: 40)
            .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func sourceRow(badge: AnyView, title: String, optional: Bool, link: Link, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                badge
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title).font(.system(size: 16, weight: .semibold))
                        Text(optional ? "Optional" : "Recommended")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .frame(height: 18)
                            .background(.white.opacity(optional ? 0.12 : 0.22), in: Capsule())
                            .foregroundStyle(.white.opacity(optional ? 0.7 : 0.95))
                    }
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(link == .connected ? Color(hex: "#5ee39a") : .white.opacity(0.65))
                        .lineLimit(2)
                        .contentTransition(.opacity)
                }
                Spacer(minLength: 8)
                trailing(link)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(link != .idle)
    }

    @ViewBuilder
    private func trailing(_ link: Link) -> some View {
        switch link {
        case .idle:
            Text("Connect")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(.white, in: Capsule())
        case .working:
            ProgressView().tint(.white).frame(width: 30, height: 30)
        case .connected:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color(hex: "#34c759"))
                .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: Actions

    private func startPhotos() {
        guard photoLink == .idle else { return }
        Haptics.tap()
        withAnimation(.easeOut(duration: 0.2)) { photoLink = .working }
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            var images: [UIImage] = []
            if status == .authorized || status == .limited {
                images = await OnboardingPhotoLoader.recent(limit: 24)
            }
            if images.isEmpty {
                // No access or nothing shared: let them pick a few by hand.
                withAnimation(.easeOut(duration: 0.2)) { photoLink = .idle }
                picked = []
                picking = true
            } else {
                connectPhotos(images)
            }
        }
    }

    private func connectPhotos(_ images: [UIImage]) {
        usingSamples = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            photos = images
            photoLink = .connected
        }
        Haptics.success()
    }

    private func useSamples() {
        Task {
            if samples.isEmpty { samples = await OnboardingPhotoLoader.samples(store.seed.places.map(\.photo)) }
            // A real pick landed meanwhile; it wins.
            guard picked.isEmpty else { return }
            usingSamples = true
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                photos = samples
                photoLink = .connected
            }
            Haptics.soft()
        }
    }

    /// Google and Yelp are pretend for the demo: a short spinner, then a believable summary.
    private func fakeConnect(_ link: Binding<Link>) {
        Haptics.tap()
        withAnimation(.easeOut(duration: 0.2)) { link.wrappedValue = .working }
        Task {
            try? await Task.sleep(for: .milliseconds(1400))
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { link.wrappedValue = .connected }
            Haptics.success()
        }
    }

    private func proceed() {
        Haptics.tap()
        if photos.isEmpty { photos = samples }
        var sources: [String] = []
        if photoLink == .connected && !usingSamples { sources.append("photos") }
        if google == .connected { sources.append("google") }
        if yelp == .connected { sources.append("yelp") }
        store.update { s in s.connectedSources = sources }
        done()
    }

}

// MARK: Compile

struct OnboardingCompileStep: View {
    @Environment(AppStore.self) private var store
    var photos: [UIImage]
    var done: () -> Void

    @State private var start: Date?
    @State private var shown: [UIImage] = []
    @State private var finished = false
    @State private var bloom = false

    private let duration: Double = 4.8
    private let lines = [
        "Reading your photos…",
        "Finding your favorite kinds of places…",
        "Matching 2,400 places in San Francisco…",
        "Cutting your gem…",
    ]

    var body: some View {
        let gem = TasteGem.of(store)
        TimelineView(.animation) { context in
            let t = start.map { context.date.timeIntervalSince($0) } ?? 0
            let p = min(1, max(0, t / duration))
            VStack(spacing: 0) {
                GeometryReader { geo in
                    let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                    let reach = min(geo.size.width, geo.size.height * 1.4) * 0.48
                    ZStack {
                        // Glow that gathers as the gem forms.
                        Circle()
                            .fill(RadialGradient(colors: [gem.colors[0].opacity(0.55 * p), gem.colors[1].opacity(0.2 * p), .clear],
                                                 center: .center, startRadius: 0, endRadius: reach * 0.9))
                            .frame(width: reach * 2, height: reach * 2)
                            .position(center)
                        dust(gem: gem, t: t, p: p, center: center, reach: reach)
                        ForEach(shown.indices, id: \.self) { i in
                            thumb(i, t: t, p: p, center: center, reach: reach)
                        }
                        // A ring of light when the gem is done.
                        Circle()
                            .strokeBorder(.white.opacity(bloom ? 0 : 0.8), lineWidth: bloom ? 1 : 6)
                            .frame(width: 160, height: 160)
                            .scaleEffect(bloom ? 2.6 : 0.6)
                            .opacity(finished ? 1 : 0)
                            .position(center)
                        TasteGemView(gem: gem, size: 180, animated: true, build: smooth(0.12, 0.96, p))
                            .scaleEffect(finished ? 1.08 : 1)
                            .position(center)
                    }
                }
                status(p: p)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .task { await run() }
    }

    // MARK: Pieces

    /// One photo on its spiral: it orbits, then falls in faster and faster, shrinking and fading.
    private func thumb(_ i: Int, t: Double, p: Double, center: CGPoint, reach: CGFloat) -> some View {
        let n = Double(max(shown.count, 1))
        let seed = hash(i)
        let delay = Double(i) / n * 0.38
        let q = min(1, max(0, (p - 0.06 - delay) / 0.52))
        let fall = q * q
        let radius = reach * (0.72 + 0.28 * seed) * (1 - fall)
        let angle = Double(i) / n * 2 * .pi + seed * 0.6 + 0.75 * t + 4.2 * fall
        let x = cos(angle) * radius
        let y = sin(angle) * radius * 0.62
        let depth = 0.9 + 0.1 * sin(angle)
        let appear = min(1, max(0, (t - Double(i) * 0.035) / 0.35))
        let alpha = appear * (1 - smooth(0.7, 1, fall))
        return Image(uiImage: shown[i])
            .resizable()
            .scaledToFill()
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(.white.opacity(0.7), lineWidth: 1.2))
            .scaleEffect((0.35 + 0.65 * (1 - fall)) * depth * (0.6 + 0.4 * appear))
            .rotationEffect(.radians(angle * 0.15))
            .opacity(alpha)
            .position(x: center.x + x, y: center.y + y)
            .zIndex(sin(angle))
    }

    /// Specks of colour drifting inward along the same galaxy.
    private func dust(gem: TasteGem, t: Double, p: Double, center: CGPoint, reach: CGFloat) -> some View {
        Canvas { ctx, _ in
            let count = 70
            for k in 0..<count {
                let seed = hash(k + 101)
                let life = (seed + t * (0.18 + 0.12 * seed)).truncatingRemainder(dividingBy: 1)
                let r = reach * 1.05 * (1 - life)
                let angle = Double(k) * 2.399 + t * (0.5 + seed) + 3 * life
                let x = center.x + cos(angle) * r
                let y = center.y + sin(angle) * r * 0.62
                let size = 1.2 + 2.4 * seed * (1 - life)
                let alpha = (0.25 + 0.6 * p) * sin(life * .pi)
                let color = k % 4 == 0 ? Color.white : gem.colors[k % gem.colors.count]
                ctx.fill(Path(ellipseIn: CGRect(x: x - size / 2, y: y - size / 2, width: size, height: size)),
                         with: .color(color.opacity(alpha)))
            }
        }
        .allowsHitTesting(false)
    }

    private func status(p: Double) -> some View {
        let count = Double(lines.count)
        let index = min(lines.count - 1, Int(p * count))
        let local = p * count - Double(index)
        let alpha = index == lines.count - 1 ? min(1, local * 6) : min(1, local * 6, (1 - local) * 6)
        return VStack(spacing: 12) {
            Text("Our AI is compiling your taste…")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.5)
            Text(lines[index])
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.75))
                .opacity(alpha)
                .frame(height: 20)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule().fill(.white).frame(width: geo.size.width * p)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 40)
            Text("\(Int(p * 100))%")
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.55))
        }
        .multilineTextAlignment(.center)
    }

    // MARK: Timing

    private func run() async {
        var images = Array(photos.prefix(24))
        if images.count < 14 {
            let extra = await OnboardingPhotoLoader.samples(store.seed.places.map(\.photo), limit: 24)
            images += extra.prefix(16 - images.count)
        }
        shown = images
        start = .now
        for _ in 1..<lines.count {
            try? await Task.sleep(for: .seconds(duration / Double(lines.count)))
            Haptics.soft()
        }
        try? await Task.sleep(for: .seconds(duration / Double(lines.count) + 0.1))
        Haptics.success()
        finished = true
        withAnimation(.easeOut(duration: 0.8)) { bloom = true }
        try? await Task.sleep(for: .milliseconds(1000))
        done()
    }

    private func smooth(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let v = min(1, max(0, (x - a) / (b - a)))
        return v * v * (3 - 2 * v)
    }

    private func hash(_ i: Int) -> Double {
        let v = sin(Double(i) * 12.9898 + 78.233) * 43758.5453
        return v - floor(v)
    }
}

// MARK: Reveal

struct OnboardingRevealStep: View {
    @Environment(AppStore.self) private var store
    var done: () -> Void
    @State private var shown = false
    @State private var cardShown = false

    var body: some View {
        let gem = TasteGem.of(store)
        let pick = store.dailyPick()
        VStack(spacing: 14) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    Text("YOUR TASTE GEM")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 12)
                    TasteGemView(gem: gem, size: 210, animated: true)
                        .scaleEffect(shown ? 1 : 0.7)
                        .opacity(shown ? 1 : 0)
                    VStack(spacing: 10) {
                        Text("You're \(article(gem.persona)) \(gem.persona)")
                            .font(.system(size: 28, weight: .bold))
                            .tracking(-0.8)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 8) {
                            ForEach(Array(gem.traits.enumerated()), id: \.offset) { i, trait in
                                chip(trait, gem.colors[i % gem.colors.count])
                            }
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "diamond.fill").font(.system(size: 11, weight: .bold))
                            Text("Level \(gem.level) gem").font(.system(size: 13, weight: .bold))
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(.white.opacity(0.14), in: Capsule())
                        Text("Your gem decides what Odyssey shows you first. Save places and check in to grow it and bring out new colours.")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown ? 0 : 14)
                    adventure(pick)
                        .opacity(cardShown ? 1 : 0)
                        .offset(y: cardShown ? 0 : 24)
                        .padding(.top, 6)
                }
            }
            Button {
                Haptics.tap()
                done()
            } label: {
                HStack(spacing: 8) {
                    Text("Start exploring")
                    Image(systemName: "arrow.right").font(.system(size: 15, weight: .bold))
                }
            }
            .buttonStyle(AuthBigButtonStyle())
            .opacity(cardShown ? 1 : 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
        .onAppear {
            // Pin today's pick now so Home opens on the same adventure.
            if !store.dailyRevealed { store.revealDaily() }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { shown = true }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.45)) { cardShown = true }
        }
    }

    private func chip(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.system(size: 13, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(color.opacity(0.25), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.7), lineWidth: 1))
    }

    private func adventure(_ pick: (place: Place, reason: String, rare: Bool)) -> some View {
        let reward = Rewards.checkIn.coins + (pick.rare ? Rewards.first.coins : 0) + 150
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkle").font(.system(size: 11, weight: .bold))
                Text("YOUR FIRST ADVENTURE").font(.system(size: 11, weight: .bold)).tracking(1.2)
                Spacer()
                if pick.rare {
                    Text("Be first").font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8).frame(height: 20)
                        .background(Palette.rare, in: Capsule())
                }
            }
            .foregroundStyle(.white.opacity(0.75))
            HStack(spacing: 12) {
                PlacePhoto(place: pick.place)
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    Text(pick.place.name)
                        .font(.system(size: 18, weight: .heavy))
                        .tracking(-0.3)
                        .lineLimit(2)
                    Text(pick.reason)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                    HStack(spacing: 10) {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill").font(.system(size: 10, weight: .bold))
                            Text(Format.distance(store.metres(to: pick.place)))
                        }
                        HStack(spacing: 4) {
                            CoinIcon(size: 14)
                            Text("+\(reward)").monospacedDigit()
                        }
                        Text("+\(Rewards.checkIn.xp) XP").foregroundStyle(Color(hex: "#c9b6ff"))
                    }
                    .font(.system(size: 12, weight: .bold))
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 1))
    }

    private func article(_ word: String) -> String {
        guard let first = word.lowercased().first else { return "a" }
        return "aeiou".contains(first) ? "an" : "a"
    }
}
