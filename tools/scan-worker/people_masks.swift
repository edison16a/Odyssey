// Finds the people in every frame with Apple's Vision framework and writes a
// mask per frame: white where the scene is, black where a person is. The 3D
// build ignores the black parts, so people do not end up in the space.
//
// It looks for human rectangles on the whole frame and on overlapping tiles,
// so small people far away are found too. (Vision's person segmentation was
// tried as well; in a crowd it only outlines one or two people, and not well.)
//
// usage: people_masks <images_dir> <colmap_masks_dir> <brush_masks_dir>
//   colmap_masks_dir gets "<image name>.png" (what COLMAP expects)
//   brush_masks_dir  gets "<image stem>.png" (what Brush expects)

import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

let args = CommandLine.arguments
guard args.count == 4 else {
    FileHandle.standardError.write("usage: people_masks <images> <colmap_masks> <brush_masks>\n".data(using: .utf8)!)
    exit(2)
}
let imagesDir = URL(fileURLWithPath: args[1])
let colmapDir = URL(fileURLWithPath: args[2])
let brushDir = URL(fileURLWithPath: args[3])
let fm = FileManager.default
try fm.createDirectory(at: colmapDir, withIntermediateDirectories: true)
try fm.createDirectory(at: brushDir, withIntermediateDirectories: true)

let names = try fm.contentsOfDirectory(atPath: imagesDir.path)
    .filter { $0.lowercased().hasSuffix(".jpg") || $0.lowercased().hasSuffix(".png") }
    .sorted()

let context = CIContext()
let gray = CGColorSpaceCreateDeviceGray()
let lock = NSLock()
var withPeople = 0

/// The whole frame, then a 2 by 3 grid of overlapping tiles (normalised, origin bottom left).
let regions: [CGRect] = {
    var out = [CGRect(x: 0, y: 0, width: 1, height: 1)]
    for col in 0..<2 {
        for row in 0..<3 {
            out.append(CGRect(x: Double(col) * 0.4, y: Double(row) * 0.3, width: 0.6, height: 0.4))
        }
    }
    return out
}()

func writePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

DispatchQueue.concurrentPerform(iterations: names.count) { i in
    let name = names[i]
    let url = imagesDir.appendingPathComponent(name)
    guard let image = CIImage(contentsOf: url), let cg = context.createCGImage(image, from: image.extent) else { return }
    let w = cg.width, h = cg.height
    guard let canvas = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                 space: gray, bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
    canvas.setFillColor(gray: 1, alpha: 1)
    canvas.fill(CGRect(x: 0, y: 0, width: w, height: h))
    var found = false

    // Rectangles around every person, grown a little.
    var requests: [VNDetectHumanRectanglesRequest] = []
    for region in regions {
        let r = VNDetectHumanRectanglesRequest()
        r.upperBodyOnly = false
        r.regionOfInterest = region
        requests.append(r)
    }
    let handler = VNImageRequestHandler(cgImage: cg, options: [:])
    try? handler.perform(requests)

    canvas.setFillColor(gray: 0, alpha: 1)
    for (r, region) in zip(requests, regions) {
        for person in r.results ?? [] where person.confidence > 0.3 {
            let b = person.boundingBox
            // The box is relative to the region it was found in.
            var box = CGRect(x: (region.minX + b.minX * region.width) * Double(w),
                             y: (region.minY + b.minY * region.height) * Double(h),
                             width: b.width * region.width * Double(w),
                             height: b.height * region.height * Double(h))
            box = box.insetBy(dx: -box.width * 0.15 - 6, dy: -box.height * 0.08 - 6)
            canvas.fill(box)
            found = true
        }
    }

    guard let mask = canvas.makeImage() else { return }
    if found { lock.lock(); withPeople += 1; lock.unlock() }
    let stem = (name as NSString).deletingPathExtension
    writePNG(mask, to: colmapDir.appendingPathComponent(name + ".png"))
    writePNG(mask, to: brushDir.appendingPathComponent(stem + ".png"))
}
print("masks \(names.count), frames with people \(withPeople)")
