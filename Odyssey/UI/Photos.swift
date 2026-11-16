//
//  Photos.swift
//  Odyssey
//
//  Every picture in the app: bundled photos referenced by their mockup path
//  (assets/media/places/doe-library.jpg) and photos the user took, stored
//  by file name. Missing images show a soft grey placeholder.
//

import Foundation
import SwiftUI
import UIKit

/// Bundled photos, decoded ahead of time. A photo is otherwise decoded on the main
/// thread the first time it is drawn, which drops frames right as a new card slides in.
nonisolated enum PhotoCache {
    private static let ready: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 120 * 1024 * 1024
        return cache
    }()
    private static let queue = DispatchQueue(label: "odyssey.photo-decode", qos: .userInitiated)
    private static let lock = NSLock()
    nonisolated(unsafe) private static var busy: Set<String> = []

    /// The photo for an asset name: the decoded copy when it is ready, the plain one otherwise.
    static func image(named name: String) -> UIImage? {
        ready.object(forKey: name as NSString) ?? UIImage(named: name)
    }

    /// Decode these photos in the background so they are ready before they scroll in.
    static func warm(_ paths: [String]) {
        for path in paths {
            let name = Media.name(for: path)
            guard ready.object(forKey: name as NSString) == nil else { continue }
            lock.lock()
            let fresh = busy.insert(name).inserted
            lock.unlock()
            guard fresh else { continue }
            queue.async {
                if let image = UIImage(named: name)?.preparingForDisplay() {
                    let cost = Int(image.size.width * image.scale * image.size.height * image.scale * 4)
                    ready.setObject(image, forKey: name as NSString, cost: cost)
                }
                lock.lock()
                busy.remove(name)
                lock.unlock()
            }
        }
    }
}

/// A bundled photo, filling its frame.
struct PhotoView: View {
    var path: String
    var placeholder: Color = Palette.surface3

    var body: some View {
        if let image = PhotoCache.image(named: Media.name(for: path)) {
            Color.clear
                .overlay { Image(uiImage: image).resizable().scaledToFill() }
                .clipped()
        } else {
            placeholder
        }
    }
}

/// A photo the user took, or a bundled fallback.
struct UserPhotoView: View {
    var file: String?
    var fallback: String?

    var body: some View {
        if let image = PhotoStore.load(file) {
            Color.clear
                .overlay { Image(uiImage: image).resizable().scaledToFill() }
                .clipped()
        } else if let fallback {
            PhotoView(path: fallback)
        } else {
            Palette.surface3
        }
    }
}

/// The place's photo.
struct PlacePhoto: View {
    var place: Place
    var body: some View { PhotoView(path: place.photo) }
}
