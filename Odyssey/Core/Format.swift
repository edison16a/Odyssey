//
//  Format.swift
//  Odyssey
//
//  Numbers, distances and times read the same everywhere, worded exactly
//  like the mockup: "1,240", "210 m", "3 min walk", "34m", "Nov 11".
//

import CoreLocation
import Foundation

nonisolated enum Format {
    static func number(_ n: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: n.rounded())) ?? "\(Int(n))"
    }

    static func number(_ n: Int) -> String { number(Double(n)) }

    /// Dollars with cents only when there are any: $100, $8.33.
    static func money(_ n: Double) -> String {
        let cents = (n * 100).rounded() / 100
        if cents == cents.rounded() { return "$" + number(cents) }
        return String(format: "$%.2f", cents)
    }

    /// 1240 becomes "1.2k" for tight spots.
    static func compact(_ n: Int) -> String {
        if n < 1000 { return "\(n)" }
        if n < 10000 {
            let text = String(format: "%.1f", Double(n) / 1000)
            return (text.hasSuffix(".0") ? String(text.dropLast(2)) : text) + "k"
        }
        return "\(Int((Double(n) / 1000).rounded()))k"
    }

    static func distance(_ meters: Double) -> String {
        if meters < 1000 { return "\(Int((meters / 10).rounded()) * 10) m" }
        return String(format: "%.1f km", meters / 1000)
    }

    /// Walking time at a relaxed 80 m per minute.
    static func walkTime(_ meters: Double) -> String {
        "\(max(1, Int((meters / 80).rounded()))) min walk"
    }

    static func ordinal(_ n: Int) -> String {
        let suffixes = ["th", "st", "nd", "rd"]
        let v = n % 100
        let index = (v - 20) % 10
        if index >= 1 && index <= 3 && v > 20 { return "\(n)\(suffixes[index])" }
        if v >= 1 && v <= 3 { return "\(n)\(suffixes[v])" }
        return "\(n)th"
    }

    /// "2h" style labels for feeds and notifications.
    static func ago(_ minutes: Int) -> String {
        if minutes < 1 { return "now" }
        if minutes < 60 { return "\(minutes)m" }
        if minutes < 1440 { return "\(minutes / 60)h" }
        return "\(minutes / 1440)d"
    }

    /// "yyyy-MM-dd" for today in the local calendar. One check-in per place per day.
    static func today() -> String { WidgetDay.key(Date()) }

    /// "Nov 11".
    static func shortDate(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    /// "Feb 25, 2026" from "2026-02-25".
    static func longDate(_ key: String) -> String {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: key) else { return key }
        let output = DateFormatter()
        output.locale = Locale(identifier: "en_US")
        output.dateFormat = "MMM d, yyyy"
        return output.string(from: date)
    }

    static func clock(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

/// A latitude, longitude pair, stored as [lat, lng] like the mockup's data.
nonisolated struct Coord: Codable, Hashable, Sendable {
    var lat: Double
    var lng: Double

    init(_ lat: Double, _ lng: Double) {
        self.lat = lat
        self.lng = lng
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(coordinate.latitude, coordinate.longitude)
    }

    private enum Keys: String, CodingKey { case lat, lng }

    /// Saved data uses [lat, lng]; the server stores { lat, lng }. Read either.
    init(from decoder: Decoder) throws {
        if let keyed = try? decoder.container(keyedBy: Keys.self), keyed.contains(.lat) {
            lat = try keyed.decode(Double.self, forKey: .lat)
            lng = try keyed.decode(Double.self, forKey: .lng)
            return
        }
        var container = try decoder.unkeyedContainer()
        lat = try container.decode(Double.self)
        lng = try container.decode(Double.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(lat)
        try container.encode(lng)
    }

    var location: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lng) }

    /// Straight line distance in meters.
    func distance(to other: Coord) -> Double {
        let r = 6_371_000.0
        let rad = Double.pi / 180
        let dLat = (other.lat - lat) * rad
        let dLng = (other.lng - lng) * rad
        let h = pow(sin(dLat / 2), 2) + cos(lat * rad) * cos(other.lat * rad) * pow(sin(dLng / 2), 2)
        return 2 * r * asin(min(1, h.squareRoot()))
    }
}

/// FNV-1a over UTF-16 units, matching the mockup so seeded history and
/// photo picks come out the same as in the browser.
nonisolated enum StableHash {
    static func fnv(_ text: String) -> UInt32 {
        var h: UInt32 = 2_166_136_261
        for unit in text.utf16 {
            h = (h ^ UInt32(unit)) &* 16_777_619
        }
        return h
    }

    /// A repeatable random sequence in 0..<1 seeded from text.
    static func generator(_ text: String) -> () -> Double {
        var h = fnv(text)
        return {
            h = (h ^ (h >> 15)) &* 2_246_822_507
            return Double(h % 1000) / 1000
        }
    }
}
