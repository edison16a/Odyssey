//
//  HomeMapEngine.swift
//  Odyssey
//
//  Puts a HomeMapScene onto an MKMapView with as little work as possible.
//
//  Shapes: every polygon that shares a fill and stroke goes into one
//  MKMultiPolygon, every street into one MKMultiPolyline. A group is only
//  swapped when its contents really changed, so panning around redraws
//  nothing. Pins: one annotation each, drawn from a cached picture of the
//  SwiftUI marker, and only added, moved or removed when they differ.
//

import CoreLocation
import Foundation
import MapKit
import SwiftUI
import UIKit

/// How one group of shapes is painted.
struct HomeMapPaint: Hashable {
    var fill: Color?
    var stroke: Color
    var width: CGFloat
    var dash: [CGFloat] = []
    var round = false
}

/// One annotation on the home map: a place, an amenity, a city label, a bounty or you.
nonisolated final class HomeMapMark: NSObject, MKAnnotation, @unchecked Sendable {
    enum Content: Equatable {
        case pin(HomePin)
        case amenity(HomeAmenityPin)
        case label(name: String, explored: Bool)
        case bounty(Bounty)
        case me
    }

    let key: String
    var content: Content
    @objc dynamic var coordinate: CLLocationCoordinate2D

    init(key: String, content: Content, coordinate: CLLocationCoordinate2D) {
        self.key = key
        self.content = content
        self.coordinate = coordinate
    }
}

final class HomeMapEngine: NSObject, MKMapViewDelegate {
    var onCamera: (MKCoordinateRegion) -> Void = { _ in }
    var onPin: (String) -> Void = { _ in }
    var onBounty: (Bounty) -> Void = { _ in }
    var onAmenity: (String) -> Void = { _ in }
    var position: MapCameraPosition?
    var revision = -1

    private var groups: [String: (signature: Int, overlay: MKOverlay)] = [:]
    private var paints: [ObjectIdentifier: HomeMapPaint] = [:]
    private var marks: [String: HomeMapMark] = [:]
    private var dimsPins = false

    // MARK: Camera

    func move(_ map: MKMapView, to position: MapCameraPosition) {
        if let camera = position.camera {
            map.camera = MKMapCamera(lookingAtCenter: camera.centerCoordinate, fromDistance: camera.distance,
                                     pitch: camera.pitch, heading: camera.heading)
        } else if let region = position.region {
            map.setRegion(region, animated: false)
        }
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let region = mapView.region
        // This can fire while SwiftUI is still updating the view; report it right after.
        DispatchQueue.main.async { [weak self] in self?.onCamera(region) }
    }

    // MARK: Scene

    func apply(_ scene: HomeMapScene, to map: MKMapView) {
        applyShapes(scene, to: map)
        applyMarks(scene, to: map)
        if map.showsUserLocation != scene.showsUser { map.showsUserLocation = scene.showsUser }
    }

    /// One entry per overlay the scene needs, bottom first.
    private struct Group {
        var name: String
        var signature: Int
        var paint: HomeMapPaint
        var make: () -> MKOverlay
    }

    private func applyShapes(_ scene: HomeMapScene, to map: MKMapView) {
        var wanted: [Group] = []

        // Polygons, batched by look in the order each look first appears.
        var order: [HomeMapPaint] = []
        var byPaint: [HomeMapPaint: [HomeMapPolygon]] = [:]
        for polygon in scene.polygons {
            let paint = HomeMapPaint(fill: polygon.fill, stroke: polygon.stroke, width: polygon.width, dash: polygon.dash)
            if byPaint[paint] == nil { order.append(paint) }
            byPaint[paint, default: []].append(polygon)
        }
        for (index, paint) in order.enumerated() {
            let polygons = byPaint[paint] ?? []
            var signature = polygons.count
            for p in polygons { signature = signature &+ Self.hash(p.id, p.coords.first) }
            wanted.append(Group(name: "polygons-\(index)-\(paint.hashValue)", signature: signature, paint: paint) {
                MKMultiPolygon(polygons.map { MKPolygon(coordinates: $0.coords, count: $0.coords.count) })
            })
        }

        if !scene.footHexes.isEmpty {
            let hexes = scene.footHexes
            var signature = hexes.count
            for hex in hexes { signature = signature &+ Self.hash(hex.id, hex.coords.first) }
            let paint = HomeMapPaint(fill: HomeMapStyle.blue.opacity(0.4), stroke: HomeMapStyle.blue.opacity(0.75), width: 0.6)
            wanted.append(Group(name: "footprints", signature: signature, paint: paint) {
                MKMultiPolygon(hexes.map { MKPolygon(coordinates: $0.coords, count: $0.coords.count) })
            })
        }

        for circle in scene.circles {
            let paint = HomeMapPaint(fill: circle.fill, stroke: circle.stroke, width: circle.width, dash: circle.dash)
            let signature = Self.hash(circle.id, circle.center) &+ Int(circle.radius) &+ paint.hashValue
            wanted.append(Group(name: "circle-\(circle.id)", signature: signature, paint: paint) {
                MKCircle(center: circle.center, radius: circle.radius)
            })
        }

        var lineOrder: [HomeMapPaint] = []
        var linesByPaint: [HomeMapPaint: [HomeMapLine]] = [:]
        for line in scene.lines {
            let paint = HomeMapPaint(fill: nil, stroke: line.color, width: line.width, dash: line.dash, round: true)
            if linesByPaint[paint] == nil { lineOrder.append(paint) }
            linesByPaint[paint, default: []].append(line)
        }
        for (index, paint) in lineOrder.enumerated() {
            let lines = linesByPaint[paint] ?? []
            var signature = lines.count
            for line in lines { signature = signature &+ Self.hash(line.id, line.coords.first) &+ line.coords.count }
            wanted.append(Group(name: "lines-\(index)-\(paint.hashValue)", signature: signature, paint: paint) {
                MKMultiPolyline(lines.map { MKPolyline(coordinates: $0.coords, count: $0.coords.count) })
            })
        }

        for bounty in scene.bounties {
            let paint = HomeMapPaint(fill: Palette.gold.opacity(0.12), stroke: Palette.gold.opacity(0.9), width: 2, dash: [6, 6])
            let signature = Self.hash(bounty.id, bounty.center.location) &+ Int(bounty.radius)
            wanted.append(Group(name: "bounty-\(bounty.id)", signature: signature, paint: paint) {
                MKCircle(center: bounty.center.location, radius: bounty.radius)
            })
        }

        // Swap only what changed, keeping every overlay at its place in the stack.
        let names = Set(wanted.map(\.name))
        for (name, group) in groups where !names.contains(name) {
            map.removeOverlay(group.overlay)
            paints[ObjectIdentifier(group.overlay)] = nil
            groups[name] = nil
        }
        var below: MKOverlay?
        for group in wanted {
            if let current = groups[group.name], current.signature == group.signature {
                below = current.overlay
                continue
            }
            let overlay = group.make()
            paints[ObjectIdentifier(overlay)] = group.paint
            if let current = groups[group.name] {
                map.insertOverlay(overlay, above: current.overlay)
                map.removeOverlay(current.overlay)
                paints[ObjectIdentifier(current.overlay)] = nil
            } else if let below {
                map.insertOverlay(overlay, above: below)
            } else {
                map.insertOverlay(overlay, at: 0, level: .aboveRoads)
            }
            groups[group.name] = (group.signature, overlay)
            below = overlay
        }
    }

    private static func hash<ID: Hashable>(_ id: ID, _ first: CLLocationCoordinate2D?) -> Int {
        var hasher = Hasher()
        hasher.combine(id)
        hasher.combine(first?.latitude)
        hasher.combine(first?.longitude)
        return hasher.finalize()
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let paint = paints[ObjectIdentifier(overlay)] else { return MKOverlayRenderer(overlay: overlay) }
        let renderer: MKOverlayPathRenderer
        switch overlay {
        case let shape as MKMultiPolygon: renderer = MKMultiPolygonRenderer(multiPolygon: shape)
        case let shape as MKMultiPolyline: renderer = MKMultiPolylineRenderer(multiPolyline: shape)
        case let shape as MKCircle: renderer = MKCircleRenderer(circle: shape)
        default: return MKOverlayRenderer(overlay: overlay)
        }
        renderer.fillColor = paint.fill.map { UIColor($0) }
        renderer.strokeColor = UIColor(paint.stroke)
        renderer.lineWidth = paint.width
        if !paint.dash.isEmpty { renderer.lineDashPattern = paint.dash.map { NSNumber(value: Double($0)) } }
        if paint.round {
            renderer.lineCap = .round
            renderer.lineJoin = .round
        }
        return renderer
    }

    // MARK: Pins

    private func applyMarks(_ scene: HomeMapScene, to map: MKMapView) {
        var wanted: [(key: String, content: HomeMapMark.Content, at: CLLocationCoordinate2D)] = []
        for label in scene.labels {
            wanted.append(("label-" + label.id, .label(name: label.name, explored: label.explored), label.labelAt.location))
        }
        for bounty in scene.bounties {
            wanted.append(("bounty-" + bounty.id, .bounty(bounty), bounty.center.location))
        }
        for pin in scene.pins {
            wanted.append(("pin-" + pin.id, .pin(pin), pin.coord.location))
        }
        for pin in scene.amenities {
            wanted.append(("amenity-" + pin.id, .amenity(pin), pin.coord.location))
        }
        if !scene.showsUser { wanted.append(("me", .me, scene.me.location)) }

        let dimChanged = dimsPins != scene.dimsPins
        dimsPins = scene.dimsPins

        var seen = Set<String>()
        var added: [HomeMapMark] = []
        for item in wanted where seen.insert(item.key).inserted {
            guard let mark = marks[item.key] else {
                let mark = HomeMapMark(key: item.key, content: item.content, coordinate: item.at)
                marks[item.key] = mark
                added.append(mark)
                continue
            }
            let moved = mark.coordinate.latitude != item.at.latitude || mark.coordinate.longitude != item.at.longitude
            if moved { mark.coordinate = item.at }
            let changed = mark.content != item.content
            if changed { mark.content = item.content }
            if changed || dimChanged, let view = map.view(for: mark) as? HomeMapMarkerView {
                view.show(mark, dimmed: dimsPins)
            }
        }
        let gone = marks.filter { !seen.contains($0.key) }
        if !gone.isEmpty {
            map.removeAnnotations(Array(gone.values))
            for key in gone.keys { marks[key] = nil }
        }
        if !added.isEmpty { map.addAnnotations(added) }
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let mark = annotation as? HomeMapMark else { return nil }
        if mark.content == .me {
            return mapView.dequeueReusableAnnotationView(withIdentifier: HomeMapMeView.reuseID, for: mark)
        }
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: HomeMapMarkerView.reuseID, for: mark)
        (view as? HomeMapMarkerView)?.show(mark, dimmed: dimsPins)
        return view
    }

    func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
        mapView.deselectAnnotation(annotation, animated: false)
        guard let mark = annotation as? HomeMapMark else { return }
        switch mark.content {
        case .pin(let pin): onPin(pin.placeID)
        case .amenity(let pin): onAmenity(pin.id)
        case .bounty(let bounty): onBounty(bounty)
        case .label, .me: break
        }
    }
}

// MARK: Marker views

/// A place pin, amenity pin, name pill or bounty tag, shown as a picture of its SwiftUI view.
final class HomeMapMarkerView: MKAnnotationView {
    static let reuseID = "home-marker"

    /// Pictures of markers already drawn. A pin looks the same every time it comes back on screen.
    private static let pictures: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 400
        return cache
    }()

    /// The part of the picture that takes taps (the pin, not the name beside it).
    private var touch: CGRect = .zero

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        displayPriority = .required
        collisionMode = .none
        canShowCallout = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    func show(_ mark: HomeMapMark, dimmed: Bool) {
        let scale = traitCollection.displayScale > 0 ? traitCollection.displayScale : 3
        // Room around every marker so its shadow is not cut off.
        var pad: CGFloat = 4
        var pinSide: CGFloat?
        let key: String
        let picture: () -> UIImage?
        switch mark.content {
        case .pin(let pin):
            key = "pin|\(pin.kind)|\(pin.glyph)|\(pin.label ? pin.name : "")"
            pinSide = 30
            picture = {
                Self.draw(HomePinView(pin: pin).frame(width: pin.label ? 166 : 30, height: 30, alignment: .leading), pad: pad, scale: scale)
            }
            zPriority = MKAnnotationViewZPriority(rawValue: 300)
            alpha = dimmed ? 0.4 : 1
            isEnabled = true
            accessibilityLabel = pin.name
        case .amenity(let pin):
            key = "amenity|\(pin.kind)|\(pin.icon)|\(pin.label ? pin.name : "")"
            pinSide = 30
            picture = {
                Self.draw(HomeAmenityPinView(pin: pin).frame(width: pin.label ? 154 : 30, height: 30, alignment: .leading), pad: pad, scale: scale)
            }
            zPriority = MKAnnotationViewZPriority(rawValue: 400)
            alpha = 1
            isEnabled = true
            accessibilityLabel = pin.name
        case .label(let name, let explored):
            key = "label|\(name)|\(explored)"
            picture = { Self.draw(HomeRegionPill(name: name, explored: explored), pad: pad, scale: scale) }
            zPriority = MKAnnotationViewZPriority(rawValue: 100)
            alpha = 1
            isEnabled = false
            accessibilityLabel = name
        case .bounty(let bounty):
            pad = 14
            key = "bounty|\(Format.money(bounty.pool))"
            picture = { Self.draw(BountyMapTag(bounty: bounty), pad: 14, scale: scale) }
            zPriority = MKAnnotationViewZPriority(rawValue: 200)
            alpha = 1
            isEnabled = true
            accessibilityLabel = bounty.sponsor
        case .me:
            return
        }
        isAccessibilityElement = true

        let cacheKey = "\(key)@\(scale)" as NSString
        var image = Self.pictures.object(forKey: cacheKey)
        if image == nil, let drawn = picture() {
            Self.pictures.setObject(drawn, forKey: cacheKey)
            image = drawn
        }
        self.image = image
        guard let size = image?.size else { return }
        if let pinSide {
            // The pin sits at the left of the picture; keep its middle on the coordinate.
            centerOffset = CGPoint(x: size.width / 2 - (pad + pinSide / 2), y: 0)
            touch = CGRect(x: pad - 4, y: pad - 4, width: pinSide + 8, height: pinSide + 8)
        } else {
            centerOffset = .zero
            touch = isEnabled ? CGRect(origin: .zero, size: size).insetBy(dx: pad - 4, dy: pad - 4) : .zero
        }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        touch.contains(point)
    }

    private static func draw<V: View>(_ view: V, pad: CGFloat, scale: CGFloat) -> UIImage? {
        let renderer = ImageRenderer(content: view.padding(pad))
        renderer.scale = scale
        return renderer.uiImage
    }
}

/// The blue "you are here" dot for the demo spot, with its slow pulse.
final class HomeMapMeView: MKAnnotationView {
    static let reuseID = "home-me"
    private let halo = CALayer()
    private let dot = CALayer()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        let blue = UIColor(Color(hex: "#1a73e8"))
        frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        displayPriority = .required
        collisionMode = .none
        isEnabled = false
        zPriority = MKAnnotationViewZPriority(rawValue: 500)

        halo.frame = CGRect(x: 11, y: 11, width: 22, height: 22)
        halo.cornerRadius = 11
        halo.backgroundColor = blue.withAlphaComponent(0.35).cgColor
        layer.addSublayer(halo)

        dot.frame = CGRect(x: 14, y: 14, width: 16, height: 16)
        dot.cornerRadius = 8
        dot.backgroundColor = blue.cgColor
        dot.borderColor = UIColor.white.cgColor
        dot.borderWidth = 3
        dot.shadowColor = UIColor.black.cgColor
        dot.shadowOpacity = 0.3
        dot.shadowRadius = 3
        dot.shadowOffset = CGSize(width: 0, height: 2)
        dot.shadowPath = UIBezierPath(ovalIn: dot.bounds).cgPath
        layer.addSublayer(dot)
        accessibilityLabel = "You"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        halo.removeAnimation(forKey: "pulse")
        guard window != nil else { return }
        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.fromValue = 1
        grow.toValue = 2
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        let pulse = CAAnimationGroup()
        pulse.animations = [grow, fade]
        pulse.duration = 2.2
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeOut)
        pulse.isRemovedOnCompletion = false
        halo.add(pulse, forKey: "pulse")
    }
}
