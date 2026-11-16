//
//  StreakPowerUnlock.swift
//  Odyssey
//
//  The two supporting pieces of the power up: the particles each form
//  brings (energy pulled into Globie while charging, then thrown out at
//  the burst), and the milestone's second step, one preview of your new
//  look wearing the Globie frame and streak banner, with its medal.
//

import Foundation
import SwiftUI

/// Energy particles: drawn in toward the centre while charging, then flung out.
struct StreakPowerParticles: View {
    @Environment(\.animationsPaused) private var animationsPaused
    var tier: StreakTier
    var chargeStart: Date
    var burstStart: Date
    var charging: Bool
    /// True once the burst is over and nothing is left to draw.
    var finished = false

    var body: some View {
        TimelineView(OdysseyMotion.schedule(paused: animationsPaused || finished)) { timeline in
            Canvas { context, size in
                let now = timeline.date
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                var ctx = context
                ctx.addFilter(.shadow(color: glow, radius: 6))
                let sinceBurst = now.timeIntervalSince(burstStart)
                if sinceBurst < 0 {
                    guard charging else { return }
                    let t = now.timeIntervalSince(chargeStart)
                    for i in 0..<18 {
                        let delay = Double(i) * 0.07
                        let local = t - delay.truncatingRemainder(dividingBy: 0.6)
                        guard local > 0 else { continue }
                        let p = local.truncatingRemainder(dividingBy: 1.3) / 1.3
                        let opacity = p < 0.3 ? p / 0.3 : 1 - (p - 0.3) / 0.7
                        let reach = spread(i, 18)
                        let distance = reach * 1.3 + (20 - reach * 1.3) * (p * p)
                        draw(&ctx, index: i, count: 18, center: center, distance: distance, scale: 1 - 0.6 * p, opacity: opacity)
                    }
                } else {
                    for i in 0..<28 {
                        let delay = (Double(i) * 0.07).truncatingRemainder(dividingBy: 0.6) / 3
                        let p = min(1, max(0, (sinceBurst - delay) / 1.1))
                        guard p > 0, p < 1 else { continue }
                        let eased = 1 - pow(1 - p, 3)
                        let reach = spread(i, 28)
                        draw(&ctx, index: i, count: 28, center: center, distance: 30 + (reach * 1.8 - 30) * eased,
                             scale: 1.2 - 0.7 * eased, opacity: 1 - p)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var glow: Color {
        switch tier.id {
        case "fire": return Color(hex: "#ff3d00")
        case "galaxy", "eclipse": return .white
        case "crystal": return Color(hex: "#8fe3ff")
        case "gold": return Palette.gold
        case "supernova": return Color(hex: "#ffb703")
        default: return tier.color
        }
    }

    private func spread(_ i: Int, _ count: Int) -> Double { Double(110 + (i * 37) % 90) }

    private func draw(_ ctx: inout GraphicsContext, index i: Int, count: Int, center: CGPoint,
                      distance: Double, scale: Double, opacity: Double) {
        let degrees = 360 / Double(count) * Double(i) + Double(i % 3) * 7
        let rad = degrees * .pi / 180
        let point = CGPoint(x: Double(center.x) + sin(rad) * distance, y: Double(center.y) - cos(rad) * distance)
        var piece = ctx
        piece.opacity = max(0, min(1, opacity))
        piece.translateBy(x: point.x, y: point.y)
        piece.rotate(by: .radians(rad))
        piece.scaleBy(x: scale, y: scale)
        let (shape, color) = particle(i)
        piece.fill(shape, with: .color(color))
    }

    private func particle(_ i: Int) -> (Path, Color) {
        switch tier.id {
        case "fire":
            return (Path(roundedRect: CGRect(x: -4, y: -4, width: 8, height: 8), cornerRadius: 4), Color(hex: "#ff9a1f"))
        case "galaxy", "eclipse":
            return (Path(ellipseIn: CGRect(x: -2, y: -2, width: 4, height: 4)), .white)
        case "crystal":
            var diamond = Path()
            diamond.move(to: CGPoint(x: 0, y: -5))
            diamond.addLine(to: CGPoint(x: 5, y: 0))
            diamond.addLine(to: CGPoint(x: 0, y: 5))
            diamond.addLine(to: CGPoint(x: -5, y: 0))
            diamond.closeSubpath()
            return (diamond, Color(hex: "#e8fbff"))
        case "gold":
            return (Path(roundedRect: CGRect(x: -4, y: -4, width: 8, height: 8), cornerRadius: 2), Color(hex: "#ffd23f"))
        case "aurora":
            return (Path(roundedRect: CGRect(x: -2, y: -8, width: 4, height: 16), cornerRadius: 2), Color(hex: "#2ee6a6"))
        case "supernova":
            return (Path(ellipseIn: CGRect(x: -5, y: -5, width: 10, height: 10)), Color(hex: "#fff3c4"))
        case "legend":
            let colors = [Color(hex: "#ffd23f"), Color(hex: "#7cf7ff"), tier.color]
            return (Path(ellipseIn: CGRect(x: -4, y: -4, width: 8, height: 8)), colors[i % 3])
        default:
            return (Path(ellipseIn: CGRect(x: -4, y: -4, width: 8, height: 8)), tier.color)
        }
    }
}

/// Step two of a milestone: everything it unlocked on one screen. Your profile
/// wearing the new Globie frame on the new streak banner, then the frame and the
/// banner side by side, and one button that equips both.
struct StreakPowerUnlock: View {
    @Environment(AppStore.self) private var store
    @Environment(ToastCenter.self) private var toast
    var tier: StreakTier
    var canEquip: Bool
    var onFinish: () -> Void
    @State private var shown = false

    private var banner: Banner? { store.seed.banner("streak-\(tier.id)") }

    var body: some View {
        ZStack {
            tier.background.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer(minLength: 12)
                Text("\(tier.days) DAY STREAK").font(.system(size: 12, weight: .heavy)).tracking(1.4)
                    .foregroundStyle(tier.color)
                Text(banner == nil ? "You unlocked a new look" : "You unlocked 2 rewards")
                    .font(.system(size: 26, weight: .bold)).tracking(-0.6)
                    .padding(.top, 6)
                look.padding(.top, 20)
                HStack(spacing: 12) {
                    reward(title: "Profile frame") {
                        AvatarView(person: store.me, size: 64, frame: "globie-\(tier.id)")
                            .frame(height: 84)
                    }
                    if let banner {
                        reward(title: "Profile banner") {
                            PhotoView(path: banner.photo)
                                .frame(height: 84)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .frame(maxWidth: 300)
                .padding(.top, 16)
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : 16)
                Spacer(minLength: 12)
                VStack(spacing: 8) {
                    if canEquip {
                        Button(banner == nil ? "Equip" : "Equip both") {
                            store.equipTier(tier)
                            toast.show(banner == nil ? "Frame equipped" : "Frame and banner equipped", icon: "check")
                            onFinish()
                        }
                        .buttonStyle(.pill(.light, fill: true))
                    }
                    Button(canEquip ? "Not now" : "Close", action: onFinish)
                        .buttonStyle(.pill(.glass, fill: true))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 28)
        }
        .foregroundStyle(.white)
        .onAppear {
            Haptics.success()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { shown = true }
        }
    }

    /// One unlocked item: its preview over a small label.
    private func reward<Preview: View>(title: String, @ViewBuilder preview: () -> Preview) -> some View {
        VStack(spacing: 8) {
            preview()
            VStack(spacing: 1) {
                Text(tier.name).font(.system(size: 13, weight: .bold)).lineLimit(1).minimumScaleFactor(0.8)
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.65))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// Your profile header as it will look: the banner with you in the new frame on it.
    private var look: some View {
        VStack(spacing: 0) {
            Group {
                if let banner {
                    PhotoView(path: banner.photo)
                } else {
                    tier.color.opacity(0.4)
                }
            }
            .frame(height: 120)
            .clipped()
            VStack(spacing: 1) {
                Text(store.me.name).font(.system(size: 15, weight: .bold))
                Text("@\(store.me.handle)").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.6))
            }
            .frame(height: 92, alignment: .bottom)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: 300)
        .background(.white.opacity(0.08))
        .overlay(alignment: .top) {
            AvatarView(person: store.me, size: 84, frame: "globie-\(tier.id)")
                .offset(y: 120 - 42)
        }
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                Image(systemName: "flame.fill").font(.system(size: 12, weight: .bold))
                Text("\(tier.days)").font(.system(size: 13, weight: .heavy))
            }
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(tier.color, in: Circle())
            .shadow(color: tier.color, radius: 9)
            .padding(.trailing, 16)
            .padding(.bottom, 12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .scaleEffect(shown ? 1 : 0.9)
    }
}
