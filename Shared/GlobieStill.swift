//
//  GlobieStill.swift
//  Shared by the app and the widgets.
//
//  Globie as widgets draw it. The widget process cannot archive a Canvas
//  and has about 30 MB, so it never draws Globie itself. Every form and
//  mood ships as a ready picture in the widget's asset catalog, rendered
//  from the mockup's own Globie by tools/render-globies.mjs, and widgets
//  just show the one they need.
//

import Foundation
import SwiftUI
import UIKit

struct GlobieStill: View {
    var mood: GlobieMood
    var form: String

    var body: some View {
        if let image = SharedStore.image("asset:globie-\(form)-\(mood.rawValue)", maxSide: 400)
            ?? SharedStore.image("asset:globie-classic-\(mood.rawValue)", maxSide: 400) {
            Image(uiImage: image).resizable().scaledToFit()
        }
    }
}
