//
//  CountryPanel.swift
//  Odyssey
//
//  The arrival payout: the Mega quest reward, every flag on your map with
//  the new one ringed in gold, and the next steps. Also the passport stamp,
//  built as SVG like country-art.js so its lettering follows the arc.
//  Ported from features/travel/country-scene.js and country-panel.css.
//

import Foundation
import SwiftUI

struct CountryPanel: View {
    var number: Int
    var trip: DemoTrip
    var explore: () -> Void
    @Environment(AppStore.self) private var store
    @State private var popped = false

    var body: some View {
        VStack(spacing: 12) {
            mega
            HStack(spacing: 8) {
                ForEach(Array(store.travelCountries.enumerated()), id: \.offset) { index, code in
                    let last = index == store.travelCountries.count - 1
                    TravelFlag(code: store.seed.countries[code]?.flag ?? "us", width: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(last ? Color(hex: "#ffd76a") : .white.opacity(0.5), lineWidth: 2))
                        .scaleEffect(last && !popped ? 0.4 : 1)
                        .opacity(last && !popped ? 0 : 1)
                }
            }
            VStack(spacing: 8) {
                Button(action: explore) { Label("Start exploring \(trip.city)", systemImage: "safari") }
                    .buttonStyle(.pill(.light, fill: true))
                ShareLink(item: "I just arrived in \(trip.city) on Odyssey: pathy.app/arrive/\(trip.country.lowercased())") {
                    Label("Share your arrival", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.pill(.glass, fill: true))
            }
        }
        .onAppear {
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.6).delay(0.3)) { popped = true }
        }
    }

    private var mega: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe.americas")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(hex: "#3a2600"))
                .frame(width: 44, height: 44)
                .background(Color(hex: "#ffd76a"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("Mega quest complete").font(.system(size: 11, weight: .bold)).tracking(0.9).textCase(.uppercase)
                    .foregroundStyle(Color(hex: "#ffd76a"))
                Text("Visit another country").font(.system(size: 15, weight: .bold))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    CoinIcon(size: 16)
                    Text(Format.number(5000)).font(.system(size: 15, weight: .bold)).monospacedDigit()
                }
                Text("+250 XP").font(.system(size: 11)).opacity(0.75)
            }
        }
        .padding(14)
        .background(Color(hex: "#120a24").opacity(0.82), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(Color(hex: "#ffd76a"), lineWidth: 2))
        .shadow(color: Color(hex: "#ffd76a").opacity(0.25), radius: 15, y: 10)
    }
}

/// The passport stamp, as SVG so the country name can follow the arc.
enum CountryStamp {
    static func svg(country: String, city: String, date: String) -> String {
        let font = "font-family=\"-apple-system, Helvetica, sans-serif\""
        // Joined from a typed array: a long chain of + on literals can time out the type checker.
        let parts: [String] = [
            "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 200 200\">",
            "<circle cx=\"100\" cy=\"100\" r=\"92\" fill=\"none\" stroke=\"#e5484d\" stroke-width=\"5\"/>",
            "<circle cx=\"100\" cy=\"100\" r=\"80\" fill=\"none\" stroke=\"#e5484d\" stroke-width=\"2\" stroke-dasharray=\"4 4\"/>",
            "<path id=\"cs-arc\" d=\"M30 100a70 70 0 0 1 140 0\" fill=\"none\"/>",
            "<text \(font) font-weight=\"900\" font-size=\"20\" letter-spacing=\"3\" fill=\"#e5484d\"><textPath href=\"#cs-arc\" startOffset=\"50%\" text-anchor=\"middle\">\(escape(country.uppercased()))</textPath></text>",
            "<text x=\"100\" y=\"108\" text-anchor=\"middle\" \(font) font-weight=\"900\" font-size=\"30\" fill=\"#e5484d\">\(escape(city.uppercased()))</text>",
            "<text x=\"100\" y=\"136\" text-anchor=\"middle\" \(font) font-weight=\"700\" font-size=\"13\" letter-spacing=\"2\" fill=\"#e5484d\">\(escape(date))</text>",
            "<text x=\"100\" y=\"160\" text-anchor=\"middle\" \(font) font-weight=\"800\" font-size=\"11\" letter-spacing=\"3\" fill=\"#e5484d\">ODYSSEY ARRIVAL</text>",
            "</svg>",
        ]
        return parts.joined()
    }

    /// "NOV 14, 2026", the way the mockup prints today's date on the stamp.
    static func today() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter.string(from: Date()).uppercased()
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
    }
}
