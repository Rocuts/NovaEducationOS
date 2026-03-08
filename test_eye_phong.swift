import Foundation
import SceneKit
import ModelIO
import SceneKit.ModelIO

let url = URL(fileURLWithPath: "NovaEducation/Resources/Models/eye.usdz")
do {
    let scene = try SCNScene(url: url, options: nil)
    scene.rootNode.enumerateChildNodes { (node, _) in
        if let geometry = node.geometry {
            for mat in geometry.materials {
                if mat.lightingModel == .physicallyBased {
                    mat.lightingModel = .phong
                }
                print("Final material lighting model: \(mat.lightingModel.rawValue)")
            }
        }
    }
} catch {
    print("Error loading: \(error)")
}
