import Foundation
import SceneKit
import ModelIO
import SceneKit.ModelIO

let url = URL(fileURLWithPath: "NovaEducation/Resources/Models/solarSystem.usdz")
do {
    let scene = try SCNScene(url: url, options: nil)
    print("Successfully loaded. Root node children count: \(scene.rootNode.childNodes.count)")
    let (minBox, maxBox) = scene.rootNode.boundingBox
    print("Bounding box: min \(minBox), max \(maxBox)")
} catch {
    print("Error loading: \(error)")
}
