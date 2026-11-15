//
//  ShopUnboxView.swift
//  Odyssey
//
//  Unboxing after a purchase. A box in the item's rarity color shakes,
//  bursts open and the cosmetic rises out of it, already equipped. Tapping
//  skips straight to the reveal. Ported from unbox.js.
//

import Foundation
import SwiftUI

struct ShopUnboxView: View {
    var item: ShopItem

    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var shaking = false
    @State private var opened = false

    private var color: Color { Color.rarity(item.rarity) }

    private var label: String {
        switch item.type {
        case .frame: return "frame"
        case .banner: return "banner"
        case .effect: return "profile effect"
        case .title: return "title"
        }
    }

    var body: some View {
        ZStack {
            Palette.ink.ignoresSafeArea()
            Circle().fill(color.opacity(opened ? 0.35 : 0.22)).frame(width: 420).blur(radius: 70).offset(y: -120)
            VStack(spacing: 0) {
                Spacer()
                stage.frame(height: 300)
                if opened { details.transition(.move(edge: .bottom).combined(with: .opacity)) }
                else {
                    Text("Tap to open").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.6)).padding(.top, 30)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            if opened { ConfettiView(count: 60).ignoresSafeArea() }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeInOut(duration: 0.09).repeatCount(12, autoreverses: true)) { shaking = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) { open() }
        }
    }

    private var stage: some View {
        ZStack {
            ShopGiftBox(color: color, lidOpen: opened)
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(shaking && !opened ? 4 : 0))
                .scaleEffect(opened ? 0.85 : 1)
                .opacity(opened ? 0 : 1)
            ShopItemVisual(item: item, size: .big)
                .scaleEffect(opened ? 1 : 0.3)
                .offset(y: opened ? -10 : 40)
                .opacity(opened ? 1 : 0)
        }
    }

    private var details: some View {
        VStack(spacing: 8) {
            Text("\(item.rarity) \(label)".uppercased()).font(.system(size: 11, weight: .heavy)).tracking(1).foregroundStyle(color)
            Text(item.name).font(.system(size: 30, weight: .heavy)).tracking(-0.6).foregroundStyle(.white).multilineTextAlignment(.center)
            Label("Unlocked and equipped", systemImage: "checkmark").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
            VStack(spacing: 10) {
                ShareLink(item: URL(string: "https://pathy.app/explorers/\(store.me.handle)")!,
                          message: Text("My new \(label) on Odyssey: \(item.name)")) {
                    Label("Show your friends", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.pill(.light, fill: true))
                Button("See it on your profile") {
                    dismiss()
                    router.popToRoot()
                    router.select(.profile)
                }
                .buttonStyle(.pill(.glass, fill: true))
            }
            .padding(.top, 22)
        }
        .padding(.top, 24)
    }

    private func open() {
        guard !opened else { return }
        Haptics.heavy()
        withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { opened = true }
    }
}

/// The gift box: a lid with a bow, a body and a ribbon down the middle.
struct ShopGiftBox: View {
    var color: Color
    var lidOpen: Bool

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 160, y: size.height / 160)
            context.fill(Path(roundedRect: CGRect(x: 30, y: 70, width: 100, height: 70), cornerRadius: 8), with: .color(color))
            var shade = context
            shade.opacity = 0.18
            shade.fill(Path(roundedRect: CGRect(x: 30, y: 70, width: 100, height: 70), cornerRadius: 8), with: .color(.black))
            context.fill(Path(CGRect(x: 72, y: 70, width: 16, height: 70)), with: .color(.white.opacity(0.9)))
            var lid = context
            if lidOpen {
                lid.translateBy(x: 0, y: -40)
                lid.rotate(by: .degrees(-18))
            }
            lid.fill(Path(roundedRect: CGRect(x: 22, y: 44, width: 116, height: 26), cornerRadius: 6), with: .color(color))
            lid.fill(Path(CGRect(x: 72, y: 44, width: 16, height: 26)), with: .color(.white.opacity(0.9)))
            lid.stroke(SVGPath.path("M80 44C66 22 46 26 50 38C53 46 70 44 80 44C90 44 107 46 110 38C114 26 94 22 80 44Z"),
                       with: .color(.white), style: StrokeStyle(lineWidth: 6, lineJoin: .round))
        }
    }
}
