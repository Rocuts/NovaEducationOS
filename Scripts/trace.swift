import Foundation
import AppKit
import Vision

let imagePath = "Assets.xcassets/AppLogo.imageset/logo.png"
guard let image = NSImage(contentsOfFile: imagePath),
      let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let cgImage = bitmap.cgImage else {
    print("Could not load image")
    exit(1)
}

let w = CGFloat(cgImage.width)
let h = CGFloat(cgImage.height)

let contourRequest = VNDetectContoursRequest()
contourRequest.contrastAdjustment = 1.0
contourRequest.detectsDarkOnLight = true

let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
do {
    try handler.perform([contourRequest])
    guard let result = contourRequest.results?.first else { exit(0) }
    
    // Print all contours to figure out their roles
    func process(contour: VNContour, prefix: String) {
        let path = contour.normalizedPath
        let b = path.boundingBox
        // Flip Y since Vision uses standard Cartesian (origin bottom-left)
        // Convert to 1024x1024 top-left origin space
        let x0 = b.minX * w
        let y0 = (1.0 - b.maxY) * h
        let x1 = b.maxX * w
        let y1 = (1.0 - b.minY) * h
        
        print("\(prefix)Index \(contour.indexPath): [\(Int(x0)), \(Int(y0)), \(Int(x1)), \(Int(y1))] W:\(Int(x1-x0)) H:\(Int(y1-y0)) Points:\(contour.pointCount)")
        
        for child in contour.childContours {
            process(contour: child, prefix: prefix + "  ")
        }
    }
    
    for top in result.topLevelContours {
        process(contour: top, prefix: "")
    }
} catch {
    print("Error: \(error)")
}
