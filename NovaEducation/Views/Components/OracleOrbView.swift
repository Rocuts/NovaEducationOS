import SwiftUI
import SceneKit

struct OracleOrbView: UIViewRepresentable {
    var isThinking: Bool
    var isListening: Bool
    var audioLevel: Float
    var primaryColor: Color
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.scene = SCNScene()
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        scnView.antialiasingMode = .multisampling2X
        scnView.preferredFramesPerSecond = 30
        
        // Setup Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 5)
        scnView.scene?.rootNode.addChildNode(cameraNode)
        
        // Setup Orb
        let sphere = SCNSphere(radius: 1.0)
        sphere.segmentCount = 32 // Good balance of quality vs performance
        
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.metalness.contents = 0.8
        material.roughness.contents = 0.2
        material.diffuse.contents = UIColor(primaryColor)
        material.emission.contents = UIColor.black // Starts dark
        sphere.materials = [material]
        
        let orbNode = SCNNode(geometry: sphere)
        orbNode.name = "orb"
        scnView.scene?.rootNode.addChildNode(orbNode)
        
        // Outer Rings (Orbitals)
        let ring = SCNTorus(ringRadius: 1.4, pipeRadius: 0.02)
        let ringNode = SCNNode(geometry: ring)
        ringNode.name = "ring"
        ringNode.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 1, y: 1, z: 0, duration: 10)))
        orbNode.addChildNode(ringNode)
        
        // Lighting
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 500
        ambientLight.light?.color = UIColor.white
        scnView.scene?.rootNode.addChildNode(ambientLight)
        
        let omniLight = SCNNode()
        omniLight.light = SCNLight()
        omniLight.light?.type = .omni
        omniLight.light?.intensity = 1000
        omniLight.position = SCNVector3(5, 5, 5)
        scnView.scene?.rootNode.addChildNode(omniLight)
        
        // Delegate for animation loop
        scnView.delegate = context.coordinator
        
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        guard let orbNode = uiView.scene?.rootNode.childNode(withName: "orb", recursively: false) else { return }
        
        // Update Coordinator state
        context.coordinator.isThinking = isThinking
        context.coordinator.isListening = isListening
        context.coordinator.audioLevel = audioLevel
        
        // Smooth Color Transition
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        
        if isThinking {
            orbNode.geometry?.firstMaterial?.emission.contents = UIColor.purple
            orbNode.geometry?.firstMaterial?.diffuse.contents = UIColor.purple
        } else if isListening {
            // Pulse red based on audio level is handled in coordinator, but base color here
            orbNode.geometry?.firstMaterial?.emission.contents = UIColor.orange.withAlphaComponent(0.5)
            orbNode.geometry?.firstMaterial?.diffuse.contents = UIColor.orange
        } else {
            orbNode.geometry?.firstMaterial?.emission.contents = UIColor.black
            orbNode.geometry?.firstMaterial?.diffuse.contents = UIColor(primaryColor)
        }
        
        SCNTransaction.commit()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, SCNSceneRendererDelegate {
        var isThinking = false
        var isListening = false
        var audioLevel: Float = 0.0
        var time: Double = 0.0
        
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard let scene = renderer.scene,
                  let orbNode = scene.rootNode.childNode(withName: "orb", recursively: false) else { return }

            self.time = time

            // 1. Idle Animation (Breathing)
            let breatheScale = 1.0 + 0.05 * sin(time * 2.0)

            // 2. Audio Reaction (Pulse)
            var targetScale: SCNVector3

            if isListening {
                let audioScale = 1.0 + (Double(audioLevel) * 0.5)
                targetScale = SCNVector3(audioScale, audioScale, audioScale)
            } else if isThinking {
                let jitter = 0.02 * sin(time * 20.0)
                targetScale = SCNVector3(1.0 + jitter, 1.0 + jitter, 1.0 + jitter)
            } else {
                targetScale = SCNVector3(breatheScale, breatheScale, breatheScale)
            }

            // Smooth lerp to target scale
            let lerpFactor: Float = 0.15

            SCNTransaction.begin()
            SCNTransaction.disableActions = true

            if isThinking {
                orbNode.eulerAngles.y += 0.1
            }

            orbNode.scale = SCNVector3(
                orbNode.scale.x + (targetScale.x - orbNode.scale.x) * lerpFactor,
                orbNode.scale.y + (targetScale.y - orbNode.scale.y) * lerpFactor,
                orbNode.scale.z + (targetScale.z - orbNode.scale.z) * lerpFactor
            )

            SCNTransaction.commit()
        }
    }
}

#Preview {
    OracleOrbView(
        isThinking: true,
        isListening: false,
        audioLevel: 0.5,
        primaryColor: .blue
    )
    .frame(width: 200, height: 200)
    .background(Color.black)
}
