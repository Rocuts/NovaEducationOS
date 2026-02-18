import SwiftUI
import SceneKit

struct GeometryView: UIViewRepresentable {
    let configJSON: String
    
    class Coordinator {
        var previousConfigJSON: String?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear // CRITICAL: Allows transparency
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = true
        view.antialiasingMode = .multisampling4X
        view.scene = setupScene(from: configJSON)
        context.coordinator.previousConfigJSON = configJSON
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        guard configJSON != context.coordinator.previousConfigJSON else { return }
        context.coordinator.previousConfigJSON = configJSON
        uiView.scene = setupScene(from: configJSON)
    }
    
    private func setupScene(from jsonString: String) -> SCNScene {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return SCNScene()
        }
        
        let shapeType = json["shape"] as? String ?? "sphere"
        let colorHex = json["color"] as? String ?? "blue"
        let scale = json["scale"] as? Double ?? 1.0
        let animationType = json["animation"] as? String ?? "none"
        
        // 1. Create Scene
        let newScene = SCNScene()
        newScene.background.contents = UIColor.clear // Transparent scene background
       
        // 2. Create Geometry
        let geometry: SCNGeometry
        switch shapeType {
        case "cube":
            geometry = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0.05)
        case "sphere":
            geometry = SCNSphere(radius: 0.5)
        case "cylinder":
            geometry = SCNCylinder(radius: 0.5, height: 1)
        case "pyramid":
            geometry = SCNPyramid(width: 1, height: 1, length: 1)
        case "torus":
            geometry = SCNTorus(ringRadius: 0.5, pipeRadius: 0.15)
        case "cone":
            geometry = SCNCone(topRadius: 0, bottomRadius: 0.5, height: 1)
        case "capsule":
            geometry = SCNCapsule(capRadius: 0.25, height: 1)
        default:
            geometry = SCNSphere(radius: 0.5)
        }
        
        // 3. Apply Material
        let material = SCNMaterial()
        material.diffuse.contents = colorFromAppColor(name: colorHex)
        material.specular.contents = UIColor.white
        material.shininess = 1.0 // Shiny plastic look
        geometry.materials = [material]
        
        // 4. Create Node
        let newNode = SCNNode(geometry: geometry)
        // Reduce base scale slightly so it doesn't fill the entire frame constantly
        let adjustedScale = scale * 0.8
        newNode.scale = SCNVector3(adjustedScale, adjustedScale, adjustedScale)
        
        // 5. Apply Animation
        applyAnimation(to: newNode, type: animationType)
        
        newScene.rootNode.addChildNode(newNode)
        
        return newScene
    }
    
    private func applyAnimation(to node: SCNNode, type: String) {
        node.removeAllActions()
        
        switch type {
        case "rotate":
            let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 10)
            let repeatAction = SCNAction.repeatForever(rotate)
            node.runAction(repeatAction)
            
        case "pulse":
            let scaleUp = SCNAction.scale(by: 1.2, duration: 1.0)
            let scaleDown = SCNAction.scale(by: 0.833, duration: 1.0) // 1 / 1.2
            let sequence = SCNAction.sequence([scaleUp, scaleDown])
            let repeatAction = SCNAction.repeatForever(sequence)
            node.runAction(repeatAction)
            
        case "bounce":
            let moveUp = SCNAction.moveBy(x: 0, y: 0.5, z: 0, duration: 0.5)
            moveUp.timingMode = .easeOut
            let moveDown = SCNAction.moveBy(x: 0, y: -0.5, z: 0, duration: 0.5)
            moveDown.timingMode = .easeIn
            let sequence = SCNAction.sequence([moveUp, moveDown])
            let repeatAction = SCNAction.repeatForever(sequence)
            node.runAction(repeatAction)
            
        default:
            // Idle slow rotation for 3D feel
            let idleRotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 20)
            let repeatAction = SCNAction.repeatForever(idleRotate)
            node.runAction(repeatAction)
        }
    }
    
    private func colorFromAppColor(name: String) -> UIColor {
        switch name.lowercased() {
        case "red": return .systemRed
        case "blue": return .systemBlue
        case "green": return .systemGreen
        case "orange": return .systemOrange
        case "purple": return .systemPurple
        case "pink": return .systemPink
        case "yellow": return .systemYellow
        case "gray": return .systemGray
        case "black": return .black
        case "white": return .white
        default:
            // Try to parse hex if needed, defaulting to blue
            return .systemBlue
        }
    }
}
