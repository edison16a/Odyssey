// Finds the people in every frame with Apple's Vision framework and writes a
// mask per frame: white where the scene is, black where a person is. The 3D
// build ignores the black parts, so people do not end up in the space.
//
// It looks for human rectangles and body poses on the whole frame and on
// overlapping tiles, so small people far away and people sitting are found too. (Vision's person segmentation was
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

    // Two detectors per region. Rectangles find people standing and walking;
    // body poses also find people sitting at tables, which rectangles often miss.
    var boxes: [VNDetectHumanRectanglesRequest] = []
    var poses: [VNDetectHumanBodyPoseRequest] = []
    for region in regions {
        let b = VNDetectHumanRectanglesRequest()
        b.upperBodyOnly = false
        b.regionOfInterest = region
        boxes.append(b)
        let p = VNDetectHumanBodyPoseRequest()
        p.regionOfInterest = region
        poses.append(p)
    }
    let handler = VNImageRequestHandler(cgImage: cg, options: [:])
    try? handler.perform(boxes + poses)

    /// A box given relative to a region, in pixels of the whole frame.
    func pixels(_ b: CGRect, in region: CGRect) -> CGRect {
        CGRect(x: (region.minX + b.minX * region.width) * Double(w),
               y: (region.minY + b.minY * region.height) * Double(h),
               width: b.width * region.width * Double(w),
               height: b.height * region.height * Double(h))
    }

    canvas.setFillColor(gray: 0, alpha: 1)
    for (r, region) in zip(boxes, regions) {
        for person in r.results ?? [] where person.confidence > 0.3 {
            let box = pixels(person.boundingBox, in: region)
            canvas.fill(box.insetBy(dx: -box.width * 0.15 - 6, dy: -box.height * 0.08 - 6))
            found = true
        }
    }
    for (r, region) in zip(poses, regions) {
        for person in r.results ?? [] {
            guard let joints = try? person.recognizedPoints(.all) else { continue }
            let seen = joints.values.filter { $0.confidence > 0.2 }.map { $0.location }
            guard seen.count >= 4, let minX = seen.map(\.x).min(), let maxX = seen.map(\.x).max(),
                  let minY = seen.map(\.y).min(), let maxY = seen.map(\.y).max() else { continue }
            let box = pixels(CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY), in: region)
            // Joints stop at the eyes, shoulders and ankles, so grow further than for a rectangle.
            canvas.fill(box.insetBy(dx: -box.width * 0.3 - 10, dy: -box.height * 0.22 - 10))
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
