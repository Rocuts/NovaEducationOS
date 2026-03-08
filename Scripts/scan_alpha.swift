import Foundation
import AppKit

let imagePath = "Assets.xcassets/AppLogo.imageset/logo.png"
guard let image = NSImage(contentsOfFile: imagePath),
      let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData) else {
    exit(1)
}

let w = bitmap.pixelsWide
let h = bitmap.pixelsHigh

print("Scanning Hat...")
// Scan top down for the first non-transparent pixel (Top of diamond)
var hatTop: (Int, Int)? = nil
for y in 0..<h {
    for x in 0..<w {
        if bitmap.colorAt(x: x, y: y)!.alphaComponent > 0.5 {
            hatTop = (x, y); break
        }
    }
    if hatTop != nil { break }
}

print("Hat Top: \(String(describing: hatTop))")

// Scan for the leftmost and rightmost points in the top 300 pixels
var leftHat = (w, 0)
var rightHat = (0, 0)
for y in 0..<300 {
    for x in 0..<w {
        if bitmap.colorAt(x: x, y: y)!.alphaComponent > 0.5 {
            if x < leftHat.0 { leftHat = (x, y) }
            if x > rightHat.0 { rightHat = (x, y) }
        }
    }
}
print("Hat Left: \(leftHat)")
print("Hat Right: \(rightHat)")

// Scan for the shape of the Speech Bubble Tail
// The tail is on the bottom left of the bubble.
// The bubble is approx Y:308 to 669. Let's scan the left edge of the silhouette between Y: 500 and 700.
print("Scanning Tail Edge...")
for y in stride(from: 500, to: 700, by: 10) {
    for x in 0..<w {
        if bitmap.colorAt(x: x, y: y)!.alphaComponent > 0.5 {
            print("Y: \(y), LeftEdge X: \(x)")
            break
        }
    }
}

// Bottom edge of the tail
for x in stride(from: 200, to: 400, by: 10) {
    for y in (500..<700).reversed() {
        if bitmap.colorAt(x: x, y: y)!.alphaComponent > 0.5 {
            print("X: \(x), BottomEdge Y: \(y)")
            break
        }
    }
}
