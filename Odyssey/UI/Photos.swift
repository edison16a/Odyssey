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

/// A bundled photo, filling its frame.
struct PhotoView: View {
    var path: String
    var placeholder: Color = Palette.surface3

    var body: some View {
        if let image = UIImage(named: Media.name(for: path)) {
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
