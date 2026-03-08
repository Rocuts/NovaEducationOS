import Foundation
import SceneKit
import ModelIO
import SceneKit.ModelIO

let url = URL(fileURLWithPath: "NovaEducation/Resources/Models/eye.usdz")
do {
    let scene = try SCNScene(url: url, options: nil)
    
    // Traverse and print material properties
    scene.rootNode.enumerateChildNodes { (node, stop) in
        if let geometry = node.geometry {
            for mat in geometry.materials {
                print("Before: \(mat.lightingModel.rawValue)")
                mat.lightingModel = .phong
                print("After: \(mat.lightingModel.rawValue)")
            }
        }
    }
} catch {
    print("Error loading: \(error)")
}
