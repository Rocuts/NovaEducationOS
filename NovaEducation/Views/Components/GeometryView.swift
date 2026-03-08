import SwiftUI
import SceneKit
import os

private let logger = Logger(subsystem: "com.nova.education", category: "GeometryView")

struct GeometryView: UIViewRepresentable {
    let configJSON: String

    /// Extracts the shape name from the JSON config for accessibility
    private var shapeDescription: String {
        guard let data = configJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "figura 3D"
        }
        let preset = json["preset"] as? String
        let shape = json["shape"] as? String ?? "esfera"
        return Self.spanishName(for: preset ?? shape)
    }

    private static func spanishName(for key: String) -> String {
        switch key {
        case "atom": return "átomo"
        case "molecule": return "molécula"
        case "waterMolecule": return "molécula de agua"
        case "cell": return "célula"
        case "dna": return "ADN"
        case "heart": return "corazón"
        case "lung": return "pulmón"
        case "eye": return "ojo"
        case "brain": return "cerebro"
        case "flower": return "flor"
        case "tree": return "árbol"
        case "leaf": return "hoja"
        case "volcano": return "volcán"
        case "mountain": return "montaña"
        case "solarSystem": return "sistema solar"
        case "earth": return "Tierra"
        case "mars": return "Marte"
        case "saturn": return "Saturno"
        case "jupiter": return "Júpiter"
        case "moon": return "Luna"
        case "sun": return "Sol"
        case "star": return "estrella"
        case "pendulum": return "péndulo"
        case "magnet": return "imán"
        case "wave": return "onda"
        case "crystal": return "cristal"
        case "chemicalBond": return "enlace químico"
        case "microscope": return "microscopio"
        case "telescope": return "telescopio"
        case "compass": return "brújula"
        case "prism": return "prisma"
        case "blackHole": return "agujero negro"
        case "rocket": return "cohete"
        case "fossil": return "fósil"
        case "battery": return "batería"
        case "sphere": return "esfera"
        case "cube": return "cubo"
        case "cylinder": return "cilindro"
        case "cone": return "cono"
        case "torus": return "toro"
        case "pyramid": return "pirámide"
        default: return "figura 3D"
        }
    }

    class Coordinator {
        var previousConfigJSON: String?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = true
        view.antialiasingMode = .multisampling4X
        view.scene = setupScene(from: configJSON)
        context.coordinator.previousConfigJSON = configJSON
        view.isAccessibilityElement = true
        view.accessibilityLabel = "Modelo 3D: \(shapeDescription)"
        view.accessibilityTraits = .image
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        guard configJSON != context.coordinator.previousConfigJSON else { return }
        context.coordinator.previousConfigJSON = configJSON
        uiView.scene = setupScene(from: configJSON)
        uiView.accessibilityLabel = "Modelo 3D: \(shapeDescription)"
    }

    // MARK: - Scene Setup

    private func setupScene(from jsonString: String) -> SCNScene {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return SCNScene()
        }

        let shapeType = json["shape"] as? String ?? "sphere"
        let colorName = json["color"] as? String ?? "blue"
        let scale = json["scale"] as? Double ?? 1.0
        let animationType = json["animation"] as? String ?? "none"
        let preset = json["preset"] as? String

        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        // If a known preset exists, build a composite scene instead of a single primitive
        if let preset, let compositeNode = buildCompositeScene(preset: preset, color: colorName, scale: scale) {
            applyAnimation(to: compositeNode, type: animationType)
            scene.rootNode.addChildNode(compositeNode)
            addLighting(to: scene)
            return scene
        }

        // Fallback: single primitive shape
        let geometry = buildPrimitive(shapeType)
        let material = makeMaterial(color: colorFromName(colorName))
        geometry.materials = [material]

        let node = SCNNode(geometry: geometry)
        let adj = scale * 0.8
        node.scale = SCNVector3(adj, adj, adj)
        applyAnimation(to: node, type: animationType)
        scene.rootNode.addChildNode(node)

        return scene
    }

    // MARK: - Asset Loader

    /// Attempts to load an external high-fidelity 3D model from the app bundle.
    /// Supports .usdz, .usdc, and .scn files.
    private func loadExternalModel(for preset: String) -> SCNNode? {
        let extensions = ["usdz", "usdc", "scn"]
        
        for ext in extensions {
            if let url = Bundle.main.url(forResource: preset, withExtension: ext) {
                do {
                    let scene = try SCNScene(url: url, options: nil)
                    let modelNode = SCNNode()
                    for child in scene.rootNode.childNodes {
                        modelNode.addChildNode(child)
                    }
                    
                    // Normalize and center the loaded model
                    let (minVec, maxVec) = modelNode.boundingBox
                    let dx = maxVec.x - minVec.x
                    let dy = maxVec.y - minVec.y
                    let dz = maxVec.z - minVec.z
                    let maxDim = max(max(dx, dy), dz)
                    
                    if maxDim > 0 {
                        // Normalize scale to fit roughly within 1x1x1 unit box
                        let scaleCorrection = 1.0 / maxDim
                        modelNode.scale = SCNVector3(scaleCorrection, scaleCorrection, scaleCorrection)
                        
                        // Center the pivot
                        let centerX = (minVec.x + maxVec.x) / 2.0
                        let centerY = (minVec.y + maxVec.y) / 2.0
                        let centerZ = (minVec.z + maxVec.z) / 2.0
                        modelNode.pivot = SCNMatrix4MakeTranslation(centerX, centerY, centerZ)
                    }
                    
                    // Force PBR materials to adapt to standard lighting
                    modelNode.enumerateChildNodes { (node, _) in
                        if let geometry = node.geometry {
                            for mat in geometry.materials {
                                if mat.lightingModel == .physicallyBased {
                                    mat.lightingModel = .phong
                                }
                                // Ensure double-sided for thin shells
                                mat.isDoubleSided = true
                            }
                        }
                    }
                    
                    return modelNode
                } catch {
                    logger.error("Failed to load \(preset, privacy: .public).\(ext, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        return nil
    }

    // MARK: - Composite Scene Builders

    /// Routes preset name to the correct composite builder or loads an external model.
    private func buildCompositeScene(preset: String, color: String, scale: Double) -> SCNNode? {
        let root = SCNNode()
        let s = scale * 0.8

        // 1. Prioritize loading a high-fidelity external model if one exists in the bundle
        if let externalModel = loadExternalModel(for: preset) {
            root.addChildNode(externalModel)
            
            // Normalize scale (optional, but helps keep imported models consistent with internal scale logic)
            root.scale = SCNVector3(s, s, s)
            return root
        }

        // 2. Fallback to programmatic geometric primitives
        switch preset {
        case "atom":        buildAtom(root: root)
        case "molecule":    buildMolecule(root: root)
        case "waterMolecule": buildWaterMolecule(root: root)
        case "cell":        buildCell(root: root)
        case "dna":         buildDNA(root: root)
        case "heart":       buildHeart(root: root)
        case "lung":        buildLung(root: root)
        case "eye":         buildEye(root: root)
        case "brain":       buildBrain(root: root)
        case "flower":      buildFlower(root: root)
        case "tree":        buildTree(root: root)
        case "leaf":        buildLeaf(root: root)
        case "volcano":     buildVolcano(root: root)
        case "mountain":    buildMountain(root: root)
        case "solarSystem": buildSolarSystem(root: root)
        case "earth":       buildPlanet(root: root, mainColor: .systemBlue, hasRings: false, patches: true)
        case "mars":        buildPlanet(root: root, mainColor: .systemRed, hasRings: false, patches: false)
        case "saturn":      buildPlanet(root: root, mainColor: UIColor(red: 0.85, green: 0.75, blue: 0.5, alpha: 1), hasRings: true, patches: false)
        case "jupiter":     buildPlanet(root: root, mainColor: .systemOrange, hasRings: false, patches: false)
        case "moon":        buildPlanet(root: root, mainColor: .lightGray, hasRings: false, patches: false)
        case "sun":         buildSun(root: root)
        case "star":        buildStar(root: root)
        case "pendulum":    buildPendulum(root: root)
        case "magnet":      buildMagnet(root: root)
        case "wave":        buildWave(root: root)
        case "crystal":     buildCrystal(root: root)
        case "chemicalBond": buildChemicalBond(root: root)
        
        // New Advanced Objects
        case "microscope":  buildMicroscope(root: root)
        case "telescope":   buildTelescope(root: root)
        case "compass":     buildCompass(root: root)
        case "prism":       buildPrism(root: root)
        case "blackHole":   buildBlackHole(root: root)
        case "rocket":      buildRocket(root: root)
        case "fossil":      buildFossil(root: root)
        case "battery":     buildBattery(root: root)
        
        default: return nil
        }

        root.scale = SCNVector3(s, s, s)
        return root
    }

    // MARK: - Atom (Bohr Model)

    private func buildAtom(root: SCNNode) {
        // Nucleus: cluster of protons (red) and neutrons (gray)
        let nucleusNode = SCNNode()
        let protonR: CGFloat = 0.08
        for (pos, color) in [
            (SCNVector3(0, 0, 0), UIColor.systemRed),
            (SCNVector3(0.09, 0.07, 0), UIColor.gray),
            (SCNVector3(-0.06, 0.09, 0.05), UIColor.systemRed),
            (SCNVector3(0.04, -0.08, 0.06), UIColor.gray),
            (SCNVector3(-0.08, -0.04, -0.06), UIColor.systemRed),
            (SCNVector3(0.02, 0.04, -0.09), UIColor.gray),
        ] as [(SCNVector3, UIColor)] {
            let sphere = SCNSphere(radius: protonR)
            sphere.materials = [makeMaterial(color: color)]
            let n = SCNNode(geometry: sphere)
            n.position = pos
            nucleusNode.addChildNode(n)
        }
        root.addChildNode(nucleusNode)

        // Electron orbits: 3 tilted torus rings
        let orbitRadii: [CGFloat] = [0.45, 0.65, 0.85]
        let orbitTilts: [(x: Float, z: Float)] = [(0, 0), (Float.pi / 3, 0), (-Float.pi / 4, Float.pi / 5)]
        let orbitSpeeds: [TimeInterval] = [4, 6, 8]

        for i in 0..<3 {
            let ring = SCNTorus(ringRadius: orbitRadii[i], pipeRadius: 0.008)
            let ringMat = SCNMaterial()
            ringMat.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.4)
            ring.materials = [ringMat]
            let ringNode = SCNNode(geometry: ring)
            ringNode.eulerAngles.x = orbitTilts[i].x
            ringNode.eulerAngles.z = orbitTilts[i].z
            root.addChildNode(ringNode)

            // Electron on this orbit
            let electron = SCNSphere(radius: 0.04)
            electron.materials = [makeMaterial(color: .systemCyan)]
            let electronNode = SCNNode(geometry: electron)
            electronNode.position = SCNVector3(Float(orbitRadii[i]), 0, 0)

            // Orbit container that rotates
            let orbitContainer = SCNNode()
            orbitContainer.eulerAngles.x = orbitTilts[i].x
            orbitContainer.eulerAngles.z = orbitTilts[i].z
            orbitContainer.addChildNode(electronNode)

            let orbitAction = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: orbitSpeeds[i])
            orbitContainer.runAction(.repeatForever(orbitAction))
            root.addChildNode(orbitContainer)
        }
    }

    // MARK: - Molecule (Generic)

    private func buildMolecule(root: SCNNode) {
        let positions: [(SCNVector3, UIColor, CGFloat)] = [
            (SCNVector3(0, 0, 0), .systemCyan, 0.2),
            (SCNVector3(0.45, 0.25, 0), .systemBlue, 0.15),
            (SCNVector3(-0.4, 0.3, 0.1), .systemBlue, 0.15),
            (SCNVector3(0.1, -0.45, 0.15), .systemGreen, 0.12),
        ]

        for (pos, color, radius) in positions {
            let sphere = SCNSphere(radius: radius)
            sphere.materials = [makeMaterial(color: color, glossy: true)]
            let n = SCNNode(geometry: sphere)
            n.position = pos
            root.addChildNode(n)
        }

        // Bonds
        addBond(from: positions[0].0, to: positions[1].0, root: root)
        addBond(from: positions[0].0, to: positions[2].0, root: root)
        addBond(from: positions[0].0, to: positions[3].0, root: root)
    }

    // MARK: - Water Molecule (H2O)

    private func buildWaterMolecule(root: SCNNode) {
        // Oxygen (center, red, larger)
        let oxygen = SCNSphere(radius: 0.22)
        oxygen.materials = [makeMaterial(color: .systemRed, glossy: true)]
        let oNode = SCNNode(geometry: oxygen)
        root.addChildNode(oNode)

        // Hydrogens at ~104.5° angle
        let angle: Float = 104.5 * .pi / 180
        let bondLen: Float = 0.5

        let h1Pos = SCNVector3(bondLen * cos(angle / 2), bondLen * sin(angle / 2), 0)
        let h2Pos = SCNVector3(bondLen * cos(angle / 2), -bondLen * sin(angle / 2), 0)

        for pos in [h1Pos, h2Pos] {
            let hydrogen = SCNSphere(radius: 0.15)
            hydrogen.materials = [makeMaterial(color: .white, glossy: true)]
            let hNode = SCNNode(geometry: hydrogen)
            hNode.position = pos
            root.addChildNode(hNode)
            addBond(from: SCNVector3Zero, to: pos, root: root, thickness: 0.04)
        }

        // Label "H" and "O"
        addTextLabel("O", at: SCNVector3(0, 0.3, 0), color: .white, root: root)
        addTextLabel("H", at: SCNVector3(h1Pos.x, h1Pos.y + 0.22, 0), color: .lightGray, root: root)
        addTextLabel("H", at: SCNVector3(h2Pos.x, h2Pos.y - 0.22, 0), color: .lightGray, root: root)
    }

    // MARK: - Cell

    private func buildCell(root: SCNNode) {
        // Cell membrane (translucent)
        let membrane = SCNSphere(radius: 0.6)
        let membraneMat = SCNMaterial()
        membraneMat.diffuse.contents = UIColor.systemGreen.withAlphaComponent(0.2)
        membraneMat.transparency = 0.35
        membraneMat.isDoubleSided = true
        membrane.materials = [membraneMat]
        root.addChildNode(SCNNode(geometry: membrane))

        // Nucleus
        let nucleus = SCNSphere(radius: 0.2)
        nucleus.materials = [makeMaterial(color: .systemPurple)]
        let nucleusNode = SCNNode(geometry: nucleus)
        nucleusNode.position = SCNVector3(0.05, 0.05, 0)
        root.addChildNode(nucleusNode)

        // Nucleolus
        let nucleolus = SCNSphere(radius: 0.08)
        nucleolus.materials = [makeMaterial(color: UIColor(red: 0.6, green: 0.3, blue: 0.7, alpha: 1))]
        let nucleolusNode = SCNNode(geometry: nucleolus)
        nucleolusNode.position = SCNVector3(0.1, 0.1, 0)
        root.addChildNode(nucleolusNode)

        // Mitochondria (small capsules)
        for (x, y, z) in [(0.3, -0.2, 0.1), (-0.25, 0.3, -0.1), (0.15, -0.35, -0.15)] as [(CGFloat, CGFloat, CGFloat)] {
            let mito = SCNCapsule(capRadius: 0.05, height: 0.18)
            mito.materials = [makeMaterial(color: .systemOrange)]
            let mitoNode = SCNNode(geometry: mito)
            mitoNode.position = SCNVector3(x, y, z)
            mitoNode.eulerAngles.z = Float.random(in: -0.8...0.8)
            root.addChildNode(mitoNode)
        }

        // ER (rough endoplasmic reticulum — thin torus segments)
        let er = SCNTorus(ringRadius: 0.35, pipeRadius: 0.02)
        let erMat = SCNMaterial()
        erMat.diffuse.contents = UIColor.systemYellow.withAlphaComponent(0.6)
        er.materials = [erMat]
        let erNode = SCNNode(geometry: er)
        erNode.eulerAngles.x = Float.pi / 6
        root.addChildNode(erNode)
    }

    // MARK: - DNA Double Helix

    private func buildDNA(root: SCNNode) {
        let turns = 20
        let height: Float = 2.0
        let radius: Float = 0.25
        let step = height / Float(turns)

        let baseColors: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemYellow]

        for i in 0..<turns {
            let t = Float(i) / Float(turns) * Float.pi * 4 // 2 full turns
            let y = Float(i) * step - height / 2

            // Strand 1
            let x1 = radius * cos(t)
            let z1 = radius * sin(t)
            let bead1 = SCNSphere(radius: 0.035)
            bead1.materials = [makeMaterial(color: .systemPurple)]
            let n1 = SCNNode(geometry: bead1)
            n1.position = SCNVector3(x1, y, z1)
            root.addChildNode(n1)

            // Strand 2 (offset by pi)
            let x2 = radius * cos(t + .pi)
            let z2 = radius * sin(t + .pi)
            let bead2 = SCNSphere(radius: 0.035)
            bead2.materials = [makeMaterial(color: .systemPurple)]
            let n2 = SCNNode(geometry: bead2)
            n2.position = SCNVector3(x2, y, z2)
            root.addChildNode(n2)

            // Base pair connecting strands (every 2 steps)
            if i % 2 == 0 {
                let color = baseColors[i % baseColors.count]
                addBond(from: n1.position, to: n2.position, root: root, thickness: 0.02, color: color)
            }
        }
    }

    // MARK: - Heart

    private func buildHeart(root: SCNNode) {
        // Main ventricle body (deformed sphere instead of cone)
        let mainBody = SCNSphere(radius: 0.35)
        let bodyMat = SCNMaterial()
        bodyMat.diffuse.contents = UIColor(red: 0.8, green: 0.1, blue: 0.15, alpha: 1)
        bodyMat.specular.contents = UIColor.white
        bodyMat.shininess = 0.9
        mainBody.materials = [bodyMat]
        let bodyNode = SCNNode(geometry: mainBody)
        bodyNode.scale = SCNVector3(1.0, 1.2, 0.85) // Stretch it vertically and flatten slightly
        bodyNode.position = SCNVector3(0, -0.05, 0)
        root.addChildNode(bodyNode)

        // Atria (top lobes, slightly asymmetrical)
        let rightAtrium = SCNSphere(radius: 0.2)
        rightAtrium.materials = [makeMaterial(color: UIColor(red: 0.7, green: 0.1, blue: 0.2, alpha: 1), glossy: true)]
        let raNode = SCNNode(geometry: rightAtrium)
        raNode.position = SCNVector3(-0.18, 0.25, 0.05)
        root.addChildNode(raNode)

        let leftAtrium = SCNSphere(radius: 0.18)
        leftAtrium.materials = [makeMaterial(color: UIColor(red: 0.75, green: 0.15, blue: 0.2, alpha: 1), glossy: true)]
        let laNode = SCNNode(geometry: leftAtrium)
        laNode.position = SCNVector3(0.18, 0.2, -0.05)
        root.addChildNode(laNode)

        // Aorta (arching tube)
        let aorta = SCNTorus(ringRadius: 0.15, pipeRadius: 0.05)
        aorta.materials = [makeMaterial(color: UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1), glossy: true)]
        let aortaNode = SCNNode(geometry: aorta)
        aortaNode.position = SCNVector3(0.05, 0.4, 0)
        aortaNode.eulerAngles.x = Float.pi / 2
        // We only want the top half of the torus, but since we can't easily cut it, we hide the bottom inside the body
        root.addChildNode(aortaNode)

        // Pulmonary Artery (blueish)
        let pulmo = SCNCylinder(radius: 0.045, height: 0.3)
        pulmo.materials = [makeMaterial(color: UIColor(red: 0.2, green: 0.3, blue: 0.8, alpha: 1), glossy: true)]
        let pulmoNode = SCNNode(geometry: pulmo)
        pulmoNode.position = SCNVector3(-0.1, 0.35, 0.1)
        pulmoNode.eulerAngles.z = -Float.pi / 6
        pulmoNode.eulerAngles.x = Float.pi / 8
        root.addChildNode(pulmoNode)
        
        // Superior Vena Cava (blue)
        let venaCava = SCNCylinder(radius: 0.04, height: 0.25)
        venaCava.materials = [makeMaterial(color: UIColor(red: 0.1, green: 0.2, blue: 0.7, alpha: 1), glossy: true)]
        let venaNode = SCNNode(geometry: venaCava)
        venaNode.position = SCNVector3(-0.25, 0.35, -0.05)
        root.addChildNode(venaNode)

        // Coronary veins (small decorative tubes on the surface)
        for i in 0..<3 {
            let vein = SCNCapsule(capRadius: 0.008, height: 0.4)
            vein.materials = [makeMaterial(color: UIColor(red: 0.2, green: 0.2, blue: 0.8, alpha: 1), glossy: true)]
            let veinNode = SCNNode(geometry: vein)
            veinNode.position = SCNVector3(Float(i) * 0.1 - 0.1, 0, 0.34)
            veinNode.eulerAngles.z = Float.random(in: -0.2...0.2)
            veinNode.eulerAngles.x = Float.pi / 12
            root.addChildNode(veinNode)
        }
    }

    // MARK: - Lung

    private func buildLung(root: SCNNode) {
        // Two lungs (asymmetrical)
        // Right lung (3 lobes, slightly larger)
        let rightLung = SCNSphere(radius: 0.32)
        let lMat = SCNMaterial()
        lMat.diffuse.contents = UIColor(red: 0.95, green: 0.6, blue: 0.65, alpha: 1)
        lMat.normal.intensity = 0.5 // Adds slight fleshy texture
        rightLung.materials = [lMat]
        let rlNode = SCNNode(geometry: rightLung)
        rlNode.position = SCNVector3(-0.35, -0.05, 0)
        rlNode.scale = SCNVector3(0.85, 1.3, 0.8)
        root.addChildNode(rlNode)

        // Left lung (2 lobes, accommodates heart)
        let leftLung = SCNSphere(radius: 0.3)
        leftLung.materials = [lMat]
        let llNode = SCNNode(geometry: leftLung)
        llNode.position = SCNVector3(0.35, 0, 0)
        // "Cardiac notch" effect by scaling asymmetrically
        llNode.scale = SCNVector3(0.8, 1.25, 0.7)
        root.addChildNode(llNode)

        // Trachea (windpipe with cartilaginous rings)
        let trachea = SCNCylinder(radius: 0.06, height: 0.5)
        let tMat = SCNMaterial()
        tMat.diffuse.contents = UIColor(red: 0.9, green: 0.85, blue: 0.85, alpha: 1)
        trachea.materials = [tMat]
        let tracheaNode = SCNNode(geometry: trachea)
        tracheaNode.position = SCNVector3(0, 0.4, 0)
        root.addChildNode(tracheaNode)

        // Add rings to trachea
        for i in 0..<7 {
            let ring = SCNTorus(ringRadius: 0.062, pipeRadius: 0.005)
            ring.materials = [makeMaterial(color: .white)]
            let rNode = SCNNode(geometry: ring)
            rNode.position = SCNVector3(0, 0.15 + Float(i) * 0.07, 0)
            tracheaNode.addChildNode(rNode)
        }

        // Bronchi (angled main branches)
        for xSign: Float in [-1, 1] {
            let bronchus = SCNCylinder(radius: 0.035, height: 0.35)
            bronchus.materials = [tMat]
            let n = SCNNode(geometry: bronchus)
            n.position = SCNVector3(xSign * 0.15, 0.1, 0)
            n.eulerAngles.z = xSign * Float.pi / 4
            root.addChildNode(n)
            
            // Secondary bronchi branches reaching into the lung sphere
            let branch = SCNCylinder(radius: 0.015, height: 0.25)
            branch.materials = [tMat]
            let bNode = SCNNode(geometry: branch)
            bNode.position = SCNVector3(0, -0.15, 0)
            bNode.eulerAngles.z = xSign * Float.pi / 6
            n.addChildNode(bNode)
        }
    }

    // MARK: - Eye

    private func buildEye(root: SCNNode) {
        // Sclera (Eyeball main body)
        let eyeball = SCNSphere(radius: 0.4)
        let eyeMat = SCNMaterial()
        eyeMat.diffuse.contents = UIColor(white: 0.97, alpha: 1)
        // Add subtle redness/veins effect via emissive or subtle color shift, keep it clean for now
        eyeball.materials = [eyeMat]
        let eyeNode = SCNNode(geometry: eyeball)
        root.addChildNode(eyeNode)

        // Cornea (clear bulge at the front)
        let cornea = SCNSphere(radius: 0.22)
        let corneaMat = SCNMaterial()
        corneaMat.diffuse.contents = UIColor(white: 1.0, alpha: 0.1)
        corneaMat.specular.contents = UIColor.white
        corneaMat.transparent.contents = UIColor(white: 1.0, alpha: 0.2)
        corneaMat.shininess = 1.0
        cornea.materials = [corneaMat]
        let corneaNode = SCNNode(geometry: cornea)
        corneaNode.position = SCNVector3(0, 0, 0.3)
        // Flatten the cornea slightly
        corneaNode.scale = SCNVector3(1.0, 1.0, 0.6)
        root.addChildNode(corneaNode)

        // Iris (colored detailed disc)
        let iris = SCNCylinder(radius: 0.18, height: 0.01)
        let irisMat = SCNMaterial()
        // Provide a rich blue-green color to represent a detailed iris
        irisMat.diffuse.contents = UIColor(red: 0.1, green: 0.4, blue: 0.6, alpha: 1)
        irisMat.emission.contents = UIColor(red: 0.05, green: 0.2, blue: 0.3, alpha: 1) // Gives it depth
        iris.materials = [irisMat]
        let irisNode = SCNNode(geometry: iris)
        irisNode.position = SCNVector3(0, 0, 0.38)
        irisNode.eulerAngles.x = Float.pi / 2
        root.addChildNode(irisNode)

        // Pupil (deep black hole inside iris)
        let pupil = SCNCylinder(radius: 0.07, height: 0.015)
        let pupilMat = SCNMaterial()
        pupilMat.diffuse.contents = UIColor.black
        // Pure black for pupil
        pupil.materials = [pupilMat]
        let pupilNode = SCNNode(geometry: pupil)
        pupilNode.position = SCNVector3(0, 0, 0.385)
        pupilNode.eulerAngles.x = Float.pi / 2
        root.addChildNode(pupilNode)

        // Optic nerve (bundled fibers at the back)
        let nerveBundle = SCNNode()
        for _ in 0..<5 {
            let nerve = SCNCylinder(radius: 0.02, height: 0.35)
            nerve.materials = [makeMaterial(color: UIColor(red: 0.9, green: 0.8, blue: 0.4, alpha: 1))]
            let nNode = SCNNode(geometry: nerve)
            nNode.position = SCNVector3(Float.random(in: -0.02...0.02), 0, -0.45)
            nNode.eulerAngles.x = Float.pi / 2
            nNode.eulerAngles.z = Float.random(in: -0.1...0.1)
            nNode.eulerAngles.y = Float.random(in: -0.1...0.1)
            nerveBundle.addChildNode(nNode)
        }
        root.addChildNode(nerveBundle)
        
        // Superior rectus muscle (red strip on top)
        let muscle = SCNBox(width: 0.15, height: 0.02, length: 0.4, chamferRadius: 0.01)
        muscle.materials = [makeMaterial(color: UIColor(red: 0.7, green: 0.2, blue: 0.2, alpha: 1))]
        let mNode = SCNNode(geometry: muscle)
        mNode.position = SCNVector3(0, 0.35, -0.1)
        mNode.eulerAngles.x = Float.pi / 12
        root.addChildNode(mNode)
    }

    // MARK: - Brain

    private func buildBrain(root: SCNNode) {
        // Cortical folds effect via multiple overlapping capsules
        let brainMat = SCNMaterial()
        brainMat.diffuse.contents = UIColor(red: 0.9, green: 0.65, blue: 0.7, alpha: 1)
        brainMat.specular.contents = UIColor.white
        brainMat.shininess = 0.5 // Slightly glossy for a wet/organic look
        
        let leftHemi = SCNNode()
        let rightHemi = SCNNode()

        // Create gyri (folds) by placing many capsules
        for _ in 0..<45 {
            let fold = SCNCapsule(capRadius: 0.04, height: .random(in: 0.15...0.35))
            fold.materials = [brainMat]
            
            // Random positioning mapped to a rough hemisphere shape
            let theta = Float.random(in: 0...Float.pi)
            let phi = Float.random(in: -Float.pi/2...Float.pi/2)
            let r: Float = 0.28 // Base radius of hemisphere
            
            let x = r * cos(phi) * cos(theta)
            let y = r * sin(phi)
            let z = r * cos(phi) * sin(theta) * 1.2 // Elongate front-to-back
            
            // Clamp X so it stays on one side
            let clampedX = max(0.02, x)
            
            // Right hemisphere node
            let rNode = SCNNode(geometry: fold)
            rNode.position = SCNVector3(clampedX, y, z)
            // Align fold roughly to follow the surface curvature
            rNode.look(at: SCNVector3Zero, up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,1))
            rNode.eulerAngles.x += Float.pi / 2
            rightHemi.addChildNode(rNode)
            
            // Left hemisphere node (mirrored)
            let lNode = SCNNode(geometry: fold)
            lNode.position = SCNVector3(-clampedX, y, z)
            lNode.look(at: SCNVector3Zero, up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,1))
            lNode.eulerAngles.x += Float.pi / 2
            leftHemi.addChildNode(lNode)
        }
        
        // Add core spheres to prevent see-through gaps
        let coreR = SCNSphere(radius: 0.26)
        coreR.materials = [brainMat]
        let crNode = SCNNode(geometry: coreR)
        crNode.position = SCNVector3(0.1, 0, 0)
        crNode.scale = SCNVector3(1, 0.9, 1.2)
        rightHemi.addChildNode(crNode)
        
        let coreL = SCNSphere(radius: 0.26)
        coreL.materials = [brainMat]
        let clNode = SCNNode(geometry: coreL)
        clNode.position = SCNVector3(-0.1, 0, 0)
        clNode.scale = SCNVector3(1, 0.9, 1.2)
        leftHemi.addChildNode(clNode)

        root.addChildNode(leftHemi)
        root.addChildNode(rightHemi)

        // Cerebellum (striated structure at back-base)
        let cerebellumNode = SCNNode()
        let cbMat = SCNMaterial()
        cbMat.diffuse.contents = UIColor(red: 0.8, green: 0.5, blue: 0.55, alpha: 1)
        for i in -3...3 {
            let disc = SCNCylinder(radius: 0.12 - abs(CGFloat(i)) * 0.015, height: 0.02)
            disc.materials = [cbMat]
            let dNode = SCNNode(geometry: disc)
            dNode.position = SCNVector3(Float(i) * 0.03, 0, 0)
            dNode.eulerAngles.z = Float.pi / 2
            cerebellumNode.addChildNode(dNode)
        }
        cerebellumNode.position = SCNVector3(0, -0.25, -0.2)
        root.addChildNode(cerebellumNode)

        // Brain stem (medulla + spinal cord)
        let stem = SCNCapsule(capRadius: 0.05, height: 0.35)
        stem.materials = [makeMaterial(color: UIColor(red: 0.95, green: 0.85, blue: 0.8, alpha: 1))]
        let stemNode = SCNNode(geometry: stem)
        stemNode.position = SCNVector3(0, -0.35, -0.05)
        stemNode.eulerAngles.x = -Float.pi / 12
        root.addChildNode(stemNode)
    }

    // MARK: - Flower

    private func buildFlower(root: SCNNode) {
        // Center (pistil)
        let center = SCNSphere(radius: 0.12)
        center.materials = [makeMaterial(color: .systemYellow)]
        let centerNode = SCNNode(geometry: center)
        centerNode.position = SCNVector3(0, 0.5, 0)
        root.addChildNode(centerNode)

        // Petals (6 flattened spheres around center)
        let petalColors: [UIColor] = [.systemRed, .systemPink, .magenta, .systemRed, .systemPink, .magenta]
        for i in 0..<6 {
            let angle = Float(i) * Float.pi * 2 / 6
            let petal = SCNSphere(radius: 0.15)
            petal.materials = [makeMaterial(color: petalColors[i])]
            let n = SCNNode(geometry: petal)
            n.position = SCNVector3(0.22 * cos(angle), 0.5 + 0.22 * sin(angle) * 0.3, 0.22 * sin(angle))
            n.scale = SCNVector3(1.0, 0.3, 1.0)
            root.addChildNode(n)
        }

        // Stem
        let stem = SCNCylinder(radius: 0.03, height: 0.6)
        stem.materials = [makeMaterial(color: UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1))]
        let stemNode = SCNNode(geometry: stem)
        stemNode.position = SCNVector3(0, 0.15, 0)
        root.addChildNode(stemNode)

        // Leaves
        for xSign: Float in [-1, 1] {
            let leaf = SCNSphere(radius: 0.1)
            leaf.materials = [makeMaterial(color: .systemGreen)]
            let lNode = SCNNode(geometry: leaf)
            lNode.position = SCNVector3(xSign * 0.15, 0.1, 0)
            lNode.scale = SCNVector3(1.5, 0.2, 0.8)
            root.addChildNode(lNode)
        }
    }

    // MARK: - Tree

    private func buildTree(root: SCNNode) {
        // Trunk
        let trunk = SCNCylinder(radius: 0.08, height: 0.7)
        trunk.materials = [makeMaterial(color: UIColor(red: 0.45, green: 0.25, blue: 0.1, alpha: 1))]
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position = SCNVector3(0, -0.1, 0)
        root.addChildNode(trunkNode)

        // Canopy (layered spheres for fullness)
        let canopyPositions: [(Float, Float, Float, CGFloat)] = [
            (0, 0.5, 0, 0.35),
            (-0.15, 0.4, 0.1, 0.22),
            (0.18, 0.4, -0.08, 0.22),
            (0, 0.35, -0.15, 0.2),
        ]
        for (x, y, z, r) in canopyPositions {
            let sphere = SCNSphere(radius: r)
            sphere.materials = [makeMaterial(color: .systemGreen)]
            let n = SCNNode(geometry: sphere)
            n.position = SCNVector3(x, y, z)
            root.addChildNode(n)
        }
    }

    // MARK: - Leaf

    private func buildLeaf(root: SCNNode) {
        // Leaf body (flattened ellipsoid)
        let body = SCNSphere(radius: 0.4)
        body.materials = [makeMaterial(color: .systemGreen)]
        let bodyNode = SCNNode(geometry: body)
        bodyNode.scale = SCNVector3(0.7, 0.1, 1.0)
        root.addChildNode(bodyNode)

        // Central vein
        let vein = SCNCylinder(radius: 0.012, height: 0.7)
        vein.materials = [makeMaterial(color: UIColor(red: 0.1, green: 0.4, blue: 0.1, alpha: 1))]
        let veinNode = SCNNode(geometry: vein)
        veinNode.eulerAngles.z = Float.pi / 2
        root.addChildNode(veinNode)

        // Side veins
        for i in stride(from: -2, through: 2, by: 1) where i != 0 {
            let sideVein = SCNCylinder(radius: 0.008, height: 0.2)
            sideVein.materials = [makeMaterial(color: UIColor(red: 0.15, green: 0.45, blue: 0.15, alpha: 1))]
            let svNode = SCNNode(geometry: sideVein)
            svNode.position = SCNVector3(Float(i) * 0.12, 0, 0)
            svNode.eulerAngles.z = Float(i > 0 ? 1 : -1) * Float.pi / 4
            root.addChildNode(svNode)
        }

        // Petiole (stem)
        let petiole = SCNCylinder(radius: 0.015, height: 0.25)
        petiole.materials = [makeMaterial(color: UIColor(red: 0.15, green: 0.45, blue: 0.15, alpha: 1))]
        let petNode = SCNNode(geometry: petiole)
        petNode.position = SCNVector3(0, 0, -0.4)
        petNode.eulerAngles.x = Float.pi / 2
        root.addChildNode(petNode)
    }

    // MARK: - Volcano

    private func buildVolcano(root: SCNNode) {
        // Mountain base (cone)
        let mountain = SCNCone(topRadius: 0.15, bottomRadius: 0.6, height: 0.8)
        mountain.materials = [makeMaterial(color: UIColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1))]
        let mNode = SCNNode(geometry: mountain)
        mNode.position = SCNVector3(0, -0.1, 0)
        root.addChildNode(mNode)

        // Snow cap (white ring near top)
        let snow = SCNTorus(ringRadius: 0.17, pipeRadius: 0.03)
        snow.materials = [makeMaterial(color: .white)]
        let snowNode = SCNNode(geometry: snow)
        snowNode.position = SCNVector3(0, 0.2, 0)
        root.addChildNode(snowNode)

        // Lava (red/orange glow in crater)
        let lava = SCNSphere(radius: 0.12)
        let lavaMat = SCNMaterial()
        lavaMat.diffuse.contents = UIColor.systemOrange
        lavaMat.emission.contents = UIColor(red: 1.0, green: 0.3, blue: 0, alpha: 1)
        lava.materials = [lavaMat]
        let lavaNode = SCNNode(geometry: lava)
        lavaNode.position = SCNVector3(0, 0.35, 0)
        root.addChildNode(lavaNode)

        // Smoke particles (stacked translucent spheres)
        for i in 0..<4 {
            let smoke = SCNSphere(radius: CGFloat(0.06 + Double(i) * 0.03))
            let smokeMat = SCNMaterial()
            smokeMat.diffuse.contents = UIColor.gray.withAlphaComponent(CGFloat(0.4 - Double(i) * 0.08))
            smoke.materials = [smokeMat]
            let sNode = SCNNode(geometry: smoke)
            sNode.position = SCNVector3(Float.random(in: -0.05...0.05), 0.45 + Float(i) * 0.12, 0)
            root.addChildNode(sNode)
        }
    }

    // MARK: - Mountain

    private func buildMountain(root: SCNNode) {
        let mountain = SCNCone(topRadius: 0.02, bottomRadius: 0.7, height: 1.0)
        mountain.materials = [makeMaterial(color: UIColor(red: 0.5, green: 0.45, blue: 0.4, alpha: 1))]
        let mNode = SCNNode(geometry: mountain)
        root.addChildNode(mNode)

        // Snow cap
        let snowCap = SCNCone(topRadius: 0.01, bottomRadius: 0.15, height: 0.2)
        snowCap.materials = [makeMaterial(color: .white)]
        let snowNode = SCNNode(geometry: snowCap)
        snowNode.position = SCNVector3(0, 0.4, 0)
        root.addChildNode(snowNode)

        // Secondary peak
        let peak2 = SCNCone(topRadius: 0.02, bottomRadius: 0.4, height: 0.6)
        peak2.materials = [makeMaterial(color: UIColor(red: 0.45, green: 0.4, blue: 0.35, alpha: 1))]
        let p2Node = SCNNode(geometry: peak2)
        p2Node.position = SCNVector3(0.4, -0.2, 0.1)
        root.addChildNode(p2Node)
    }

    // MARK: - Solar System

    private func buildSolarSystem(root: SCNNode) {
        // Sun (center, highly emissive with corona)
        let sun = SCNSphere(radius: 0.18)
        let sunMat = SCNMaterial()
        sunMat.diffuse.contents = UIColor.systemYellow
        sunMat.emission.contents = UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1)
        sun.materials = [sunMat]
        let sunNode = SCNNode(geometry: sun)
        root.addChildNode(sunNode)
        
        // Sun Corona
        let corona = SCNSphere(radius: 0.22)
        let coronaMat = SCNMaterial()
        coronaMat.diffuse.contents = UIColor.systemOrange.withAlphaComponent(0.2)
        coronaMat.emission.contents = UIColor(red: 1, green: 0.5, blue: 0, alpha: 0.4)
        coronaMat.isDoubleSided = true
        corona.materials = [coronaMat]
        sunNode.addChildNode(SCNNode(geometry: corona))

        // Planets: (orbitRadius, planetRadius, color, speed, hasRings)
        let planets: [(CGFloat, CGFloat, UIColor, TimeInterval, Bool)] = [
            (0.30, 0.02, .gray, 3, false),                                          // Mercury
            (0.42, 0.035, UIColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 1), 5, false), // Venus
            (0.55, 0.04, .systemBlue, 7, false),                                     // Earth
            (0.68, 0.03, .systemRed, 9, false),                                      // Mars
            (0.85, 0.075, UIColor(red: 0.8, green: 0.5, blue: 0.3, alpha: 1), 14, false),// Jupiter
            (1.05, 0.065, UIColor(red: 0.85, green: 0.75, blue: 0.5, alpha: 1), 18, true), // Saturn
            (1.25, 0.05, .systemCyan, 24, false),                                    // Uranus
            (1.40, 0.048, .systemBlue, 30, false)                                    // Neptune
        ]

        for (orbitR, planetR, color, speed, hasRings) in planets {
            // Orbit ring (faint)
            let ring = SCNTorus(ringRadius: orbitR, pipeRadius: 0.0015)
            let ringMat = SCNMaterial()
            ringMat.diffuse.contents = UIColor.white.withAlphaComponent(0.2)
            ringMat.emission.contents = UIColor.white.withAlphaComponent(0.1)
            ring.materials = [ringMat]
            let orbitRingNode = SCNNode(geometry: ring)
            
            // Randomize orbit tilt slightly for realism
            orbitRingNode.eulerAngles.x = Float.random(in: -0.05...0.05)
            root.addChildNode(orbitRingNode)

            // Planet Node
            let planet = SCNSphere(radius: planetR)
            let planetMat = SCNMaterial()
            planetMat.diffuse.contents = color
            planetMat.specular.contents = UIColor(white: 0.2, alpha: 1)
            planetMat.shininess = 0.2
            planet.materials = [planetMat]
            let planetNode = SCNNode(geometry: planet)
            planetNode.position = SCNVector3(Float(orbitR), 0, 0)

            // Saturn's rings
            if hasRings {
                let saturnRing1 = SCNTorus(ringRadius: planetR * 1.8, pipeRadius: planetR * 0.15)
                let sRingMat = SCNMaterial()
                sRingMat.diffuse.contents = UIColor(red: 0.8, green: 0.7, blue: 0.5, alpha: 0.7)
                saturnRing1.materials = [sRingMat]
                let srNode1 = SCNNode(geometry: saturnRing1)
                srNode1.eulerAngles.x = Float.pi / 6
                planetNode.addChildNode(srNode1)
                
                let saturnRing2 = SCNTorus(ringRadius: planetR * 2.3, pipeRadius: planetR * 0.08)
                saturnRing2.materials = [sRingMat]
                let srNode2 = SCNNode(geometry: saturnRing2)
                srNode2.eulerAngles.x = Float.pi / 6
                planetNode.addChildNode(srNode2)
            }
            
            // Earth details (green patches + moon)
            if color == .systemBlue {
                // Add tiny moon
                let moon = SCNSphere(radius: planetR * 0.25)
                moon.materials = [makeMaterial(color: .lightGray)]
                let moonNode = SCNNode(geometry: moon)
                moonNode.position = SCNVector3(Float(planetR * 2.5), 0, 0)
                
                let moonOrbit = SCNNode()
                moonOrbit.addChildNode(moonNode)
                moonOrbit.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 2)))
                planetNode.addChildNode(moonOrbit)
            }

            // Container to revolve around sun
            let container = SCNNode()
            container.eulerAngles.x = orbitRingNode.eulerAngles.x // Match orbit tilt
            container.addChildNode(planetNode)
            
            // Start at a random angle along the orbit
            container.eulerAngles.y = Float.random(in: 0...(2 * .pi))
            
            let orbit = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: speed)
            container.runAction(.repeatForever(orbit))
            root.addChildNode(container)
        }
    }

    // MARK: - Planet (generic with optional rings)

    private func buildPlanet(root: SCNNode, mainColor: UIColor, hasRings: Bool, patches: Bool) {
        let isMoon = mainColor == .lightGray && !patches
        let isJupiter = mainColor == .systemOrange && !hasRings && !patches && !isMoon
        let isMars = mainColor == .systemRed
        
        // Base Planet Sphere
        let sphere = SCNSphere(radius: 0.45)
        let planetMat = SCNMaterial()
        planetMat.diffuse.contents = mainColor
        planetMat.specular.contents = UIColor(white: 0.2, alpha: 1)
        planetMat.shininess = 0.1
        sphere.materials = [planetMat]
        let planetNode = SCNNode(geometry: sphere)
        root.addChildNode(planetNode)

        if patches {
            // Earth-like: distinct continents using flattened spheres
            let continentColor = UIColor(red: 0.1, green: 0.6, blue: 0.2, alpha: 1) // Rich green
            for _ in 0..<12 {
                let patch = SCNSphere(radius: CGFloat.random(in: 0.1...0.2))
                patch.materials = [makeMaterial(color: continentColor)]
                let pNode = SCNNode(geometry: patch)
                let theta = Float.random(in: 0...(2 * .pi))
                let phi = Float.random(in: -Float.pi/2.5...Float.pi/2.5) // Avoid exact poles
                let r: Float = 0.44 // Slightly less than radius so it merges smoothly
                pNode.position = SCNVector3(r * cos(phi) * cos(theta), r * sin(phi), r * cos(phi) * sin(theta))
                // Squish the patch flat against the surface
                pNode.look(at: SCNVector3Zero, up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,1))
                pNode.eulerAngles.x += Float.pi / 2
                pNode.scale = SCNVector3(1.0, 0.2, 1.0)
                root.addChildNode(pNode)
            }
            
            // Polar Ice Caps
            for ySign: Float in [-1, 1] {
                let ice = SCNSphere(radius: 0.15)
                ice.materials = [makeMaterial(color: .white)]
                let iceNode = SCNNode(geometry: ice)
                iceNode.position = SCNVector3(0, ySign * 0.42, 0)
                iceNode.scale = SCNVector3(1.2, 0.3, 1.2)
                root.addChildNode(iceNode)
            }

            // Atmosphere (translucent outer layer)
            let atmo = SCNSphere(radius: 0.48)
            let atmoMat = SCNMaterial()
            atmoMat.diffuse.contents = UIColor.systemCyan.withAlphaComponent(0.15)
            atmoMat.emission.contents = UIColor.systemCyan.withAlphaComponent(0.05) // Slight glow
            atmoMat.isDoubleSided = true
            atmo.materials = [atmoMat]
            root.addChildNode(SCNNode(geometry: atmo))
            
            // Clouds (Random white patches in atmosphere)
            for _ in 0..<15 {
                let cloud = SCNSphere(radius: CGFloat.random(in: 0.05...0.12))
                let cMat = SCNMaterial()
                cMat.diffuse.contents = UIColor(white: 1.0, alpha: 0.4)
                cloud.materials = [cMat]
                let cNode = SCNNode(geometry: cloud)
                let theta = Float.random(in: 0...(2 * .pi))
                let phi = Float.random(in: -Float.pi/3...Float.pi/3)
                let r: Float = 0.485
                cNode.position = SCNVector3(r * cos(phi) * cos(theta), r * sin(phi), r * cos(phi) * sin(theta))
                cNode.look(at: SCNVector3Zero, up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,1))
                cNode.scale = SCNVector3(1.5, 0.1, 1.0)
                root.addChildNode(cNode)
            }
        } else if isJupiter {
            // Gas Giant Bands
            let bandColors: [UIColor] = [
                UIColor(red: 0.8, green: 0.6, blue: 0.4, alpha: 1),
                UIColor(red: 0.9, green: 0.8, blue: 0.7, alpha: 1),
                UIColor(red: 0.7, green: 0.4, blue: 0.3, alpha: 1), // Dark belt
                UIColor(red: 0.9, green: 0.8, blue: 0.7, alpha: 1),
                UIColor(red: 0.8, green: 0.5, blue: 0.3, alpha: 1)
            ]
            for (i, bColor) in bandColors.enumerated() {
                let bandH: Float = 0.15
                let bandY = Float(i) * bandH - (Float(bandColors.count) * bandH) / 2.0
                // Calculate radius at this Y using pythagoras
                let rSq = pow(0.455, 2) - pow(Double(bandY), 2)
                if rSq > 0 {
                    let r = CGFloat(sqrt(rSq))
                    let band = SCNCylinder(radius: r, height: CGFloat(bandH))
                    band.materials = [makeMaterial(color: bColor)]
                    let bNode = SCNNode(geometry: band)
                    bNode.position = SCNVector3(0, bandY, 0)
                    root.addChildNode(bNode)
                }
            }
            // Great Red Spot
            let grs = SCNSphere(radius: 0.1)
            grs.materials = [makeMaterial(color: UIColor(red: 0.8, green: 0.3, blue: 0.2, alpha: 1))]
            let grsNode = SCNNode(geometry: grs)
            grsNode.position = SCNVector3(0.4, -0.1, 0.15)
            // Flatten onto surface
            grsNode.scale = SCNVector3(0.3, 1.0, 1.5)
            grsNode.look(at: SCNVector3Zero)
            root.addChildNode(grsNode)
            
        } else if isMoon {
            // Craters for the Moon
            for _ in 0..<30 {
                let crRadius = CGFloat.random(in: 0.03...0.08)
                // We make craters by placing a slightly darker torus and a depressed inner sphere
                let craterRim = SCNTorus(ringRadius: crRadius, pipeRadius: crRadius * 0.2)
                let cMat = SCNMaterial()
                cMat.diffuse.contents = UIColor(white: 0.6, alpha: 1)
                craterRim.materials = [cMat]
                
                let cNode = SCNNode(geometry: craterRim)
                let theta = Float.random(in: 0...(2 * .pi))
                let phi = Float.random(in: -Float.pi/2...Float.pi/2)
                let r: Float = 0.45
                cNode.position = SCNVector3(r * cos(phi) * cos(theta), r * sin(phi), r * cos(phi) * sin(theta))
                cNode.look(at: SCNVector3Zero, up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,1))
                cNode.eulerAngles.x += Float.pi / 2
                
                // Dimple inside
                let dimple = SCNSphere(radius: crRadius * 0.9)
                let dMat = SCNMaterial()
                dMat.diffuse.contents = UIColor(white: 0.5, alpha: 1) // Darker inside
                dimple.materials = [dMat]
                let dNode = SCNNode(geometry: dimple)
                dNode.position = SCNVector3(0, -Float(crRadius * 0.2), 0)
                dNode.scale = SCNVector3(1, 0.2, 1)
                cNode.addChildNode(dNode)

                root.addChildNode(cNode)
            }
        } else if isMars {
            // Mars Ice Caps
            for ySign: Float in [-1, 1] {
                let ice = SCNSphere(radius: 0.15)
                ice.materials = [makeMaterial(color: UIColor(white: 0.9, alpha: 1))]
                let iceNode = SCNNode(geometry: ice)
                iceNode.position = SCNVector3(0, ySign * 0.43, 0)
                iceNode.scale = SCNVector3(1.2, 0.2, 1.2)
                root.addChildNode(iceNode)
            }
            
            // Darker terrain patches
            for _ in 0..<10 {
                let patch = SCNSphere(radius: CGFloat.random(in: 0.1...0.25))
                patch.materials = [makeMaterial(color: UIColor(red: 0.7, green: 0.2, blue: 0.1, alpha: 1))]
                let pNode = SCNNode(geometry: patch)
                let theta = Float.random(in: 0...(2 * .pi))
                let phi = Float.random(in: -Float.pi/2.5...Float.pi/2.5)
                let r: Float = 0.44
                pNode.position = SCNVector3(r * cos(phi) * cos(theta), r * sin(phi), r * cos(phi) * sin(theta))
                pNode.look(at: SCNVector3Zero, up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,1))
                pNode.eulerAngles.x += Float.pi / 2
                pNode.scale = SCNVector3(1.0, 0.2, 1.0)
                root.addChildNode(pNode)
            }
        }

        if hasRings {
            let ringColors = [
                UIColor(red: 0.8, green: 0.7, blue: 0.5, alpha: 0.8),
                UIColor(red: 0.6, green: 0.5, blue: 0.4, alpha: 0.6),
                UIColor(red: 0.85, green: 0.75, blue: 0.6, alpha: 0.9)
            ]
            let radii: [CGFloat] = [0.65, 0.75, 0.88]
            let widths: [CGFloat] = [0.03, 0.05, 0.02]
            
            for i in 0..<3 {
                // To make a flat ring, use a cylinder scaled flat, or a torus
                let ring = SCNCylinder(radius: radii[i], height: 0.001)
                let ringMat = SCNMaterial()
                ringMat.diffuse.contents = ringColors[i]
                ringMat.isDoubleSided = true
                ring.materials = [ringMat]
                
                let ringNode = SCNNode(geometry: ring)
                ringNode.eulerAngles.x = Float.pi / 6 // Tilt the rings
                
                // Subtract the inner hole by making it a torus effectively
                let innerRadius = radii[i] - widths[i]
                if innerRadius > 0 {
                    // Easier to just use a torus
                    let tRing = SCNTorus(ringRadius: radii[i] - widths[i]/2, pipeRadius: widths[i]/2)
                    tRing.materials = [ringMat]
                    let tNode = SCNNode(geometry: tRing)
                    tNode.eulerAngles.x = Float.pi / 6
                    // Squish the torus flat
                    tNode.scale = SCNVector3(1, 0.05, 1)
                    root.addChildNode(tNode)
                }
            }
        }
    }

    // MARK: - Sun

    private func buildSun(root: SCNNode) {
        let sun = SCNSphere(radius: 0.45)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.systemYellow
        mat.emission.contents = UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1)
        sun.materials = [mat]
        root.addChildNode(SCNNode(geometry: sun))

        // Corona (translucent glow)
        let corona = SCNSphere(radius: 0.55)
        let coronaMat = SCNMaterial()
        coronaMat.diffuse.contents = UIColor.systemOrange.withAlphaComponent(0.15)
        coronaMat.isDoubleSided = true
        corona.materials = [coronaMat]
        root.addChildNode(SCNNode(geometry: corona))

        // Solar flares (small bright spots)
        for _ in 0..<5 {
            let flare = SCNSphere(radius: 0.05)
            let flareMat = SCNMaterial()
            flareMat.emission.contents = UIColor(red: 1, green: 0.5, blue: 0, alpha: 1)
            flareMat.diffuse.contents = UIColor.systemOrange
            flare.materials = [flareMat]
            let fNode = SCNNode(geometry: flare)
            let theta = Float.random(in: 0...(2 * .pi))
            let phi = Float.random(in: -Float.pi/2...Float.pi/2)
            let r: Float = 0.47
            fNode.position = SCNVector3(r * cos(phi) * cos(theta), r * sin(phi), r * cos(phi) * sin(theta))
            root.addChildNode(fNode)
        }
    }

    // MARK: - Star

    private func buildStar(root: SCNNode) {
        let star = SCNSphere(radius: 0.35)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.systemYellow
        mat.emission.contents = UIColor(red: 1, green: 1, blue: 0.8, alpha: 1)
        star.materials = [mat]
        root.addChildNode(SCNNode(geometry: star))

        // Glow
        let glow = SCNSphere(radius: 0.45)
        let glowMat = SCNMaterial()
        glowMat.diffuse.contents = UIColor.systemYellow.withAlphaComponent(0.1)
        glowMat.isDoubleSided = true
        glow.materials = [glowMat]
        root.addChildNode(SCNNode(geometry: glow))

        // Star points (elongated spikes)
        for i in 0..<4 {
            let spike = SCNCone(topRadius: 0, bottomRadius: 0.04, height: 0.4)
            spike.materials = [makeMaterial(color: .systemYellow)]
            let sNode = SCNNode(geometry: spike)
            let angle = Float(i) * Float.pi / 2
            sNode.position = SCNVector3(0.4 * cos(angle), 0.4 * sin(angle), 0)
            sNode.eulerAngles.z = angle - Float.pi / 2
            root.addChildNode(sNode)
        }
    }

    // MARK: - Pendulum

    private func buildPendulum(root: SCNNode) {
        // Pivot point
        let pivot = SCNSphere(radius: 0.04)
        pivot.materials = [makeMaterial(color: .darkGray)]
        let pivotNode = SCNNode(geometry: pivot)
        pivotNode.position = SCNVector3(0, 0.5, 0)
        root.addChildNode(pivotNode)

        // Rod
        let rod = SCNCylinder(radius: 0.015, height: 0.7)
        rod.materials = [makeMaterial(color: .lightGray)]
        let rodNode = SCNNode(geometry: rod)
        rodNode.position = SCNVector3(0, 0.15, 0)
        root.addChildNode(rodNode)

        // Weight (bob)
        let bob = SCNSphere(radius: 0.12)
        bob.materials = [makeMaterial(color: .systemGray)]
        let bobNode = SCNNode(geometry: bob)
        bobNode.position = SCNVector3(0, -0.22, 0)
        root.addChildNode(bobNode)

        // Support bar
        let bar = SCNCylinder(radius: 0.02, height: 0.6)
        bar.materials = [makeMaterial(color: .darkGray)]
        let barNode = SCNNode(geometry: bar)
        barNode.position = SCNVector3(0, 0.5, 0)
        barNode.eulerAngles.z = Float.pi / 2
        root.addChildNode(barNode)
    }

    // MARK: - Magnet

    private func buildMagnet(root: SCNNode) {
        // U-shape: two vertical bars + connecting arc
        // Left bar (North pole, red)
        let leftBar = SCNBox(width: 0.15, height: 0.6, length: 0.15, chamferRadius: 0.02)
        leftBar.materials = [makeMaterial(color: .systemRed)]
        let leftNode = SCNNode(geometry: leftBar)
        leftNode.position = SCNVector3(-0.2, -0.1, 0)
        root.addChildNode(leftNode)

        // Right bar (South pole, blue)
        let rightBar = SCNBox(width: 0.15, height: 0.6, length: 0.15, chamferRadius: 0.02)
        rightBar.materials = [makeMaterial(color: .systemBlue)]
        let rightNode = SCNNode(geometry: rightBar)
        rightNode.position = SCNVector3(0.2, -0.1, 0)
        root.addChildNode(rightNode)

        // Connecting piece (gray)
        let connector = SCNBox(width: 0.55, height: 0.15, length: 0.15, chamferRadius: 0.02)
        connector.materials = [makeMaterial(color: .systemGray)]
        let connNode = SCNNode(geometry: connector)
        connNode.position = SCNVector3(0, 0.22, 0)
        root.addChildNode(connNode)

        // Labels
        addTextLabel("N", at: SCNVector3(-0.2, -0.45, 0.1), color: .white, root: root)
        addTextLabel("S", at: SCNVector3(0.2, -0.45, 0.1), color: .white, root: root)
    }

    // MARK: - Wave

    private func buildWave(root: SCNNode) {
        let segments = 40
        let length: Float = 2.0
        let amplitude: Float = 0.2
        let wavelength: Float = 0.8

        for i in 0..<segments {
            let x = Float(i) / Float(segments) * length - length / 2
            let y = amplitude * sin(2 * .pi * x / wavelength)
            let sphere = SCNSphere(radius: 0.03)
            sphere.materials = [makeMaterial(color: .systemBlue)]
            let n = SCNNode(geometry: sphere)
            n.position = SCNVector3(x, y, 0)
            root.addChildNode(n)
        }

        // Axis line
        let axis = SCNCylinder(radius: 0.005, height: CGFloat(length))
        let axisMat = SCNMaterial()
        axisMat.diffuse.contents = UIColor.white.withAlphaComponent(0.3)
        axis.materials = [axisMat]
        let axisNode = SCNNode(geometry: axis)
        axisNode.eulerAngles.z = Float.pi / 2
        root.addChildNode(axisNode)

        // Amplitude markers
        for yMark: Float in [-amplitude, amplitude] {
            let marker = SCNCylinder(radius: 0.003, height: CGFloat(length * 0.5))
            marker.materials = [axisMat]
            let mNode = SCNNode(geometry: marker)
            mNode.position = SCNVector3(0, yMark, 0)
            mNode.eulerAngles.z = Float.pi / 2
            root.addChildNode(mNode)
        }
    }

    // MARK: - Crystal Lattice

    private func buildCrystal(root: SCNNode) {
        let spacing: Float = 0.25
        let atomR: CGFloat = 0.05
        let bondR: CGFloat = 0.01

        for x in -1...1 {
            for y in -1...1 {
                for z in -1...1 {
                    let pos = SCNVector3(Float(x) * spacing, Float(y) * spacing, Float(z) * spacing)
                    let atom = SCNSphere(radius: atomR)
                    atom.materials = [makeMaterial(color: .systemCyan, glossy: true)]
                    let n = SCNNode(geometry: atom)
                    n.position = pos
                    root.addChildNode(n)

                    // Bonds to neighbors (only positive direction to avoid duplicates)
                    if x < 1 {
                        let neighbor = SCNVector3(Float(x + 1) * spacing, Float(y) * spacing, Float(z) * spacing)
                        addBond(from: pos, to: neighbor, root: root, thickness: bondR)
                    }
                    if y < 1 {
                        let neighbor = SCNVector3(Float(x) * spacing, Float(y + 1) * spacing, Float(z) * spacing)
                        addBond(from: pos, to: neighbor, root: root, thickness: bondR)
                    }
                    if z < 1 {
                        let neighbor = SCNVector3(Float(x) * spacing, Float(y) * spacing, Float(z + 1) * spacing)
                        addBond(from: pos, to: neighbor, root: root, thickness: bondR)
                    }
                }
            }
        }
    }

    // MARK: - Chemical Bond

    private func buildChemicalBond(root: SCNNode) {
        // Two atoms connected by a bond
        let atom1 = SCNSphere(radius: 0.2)
        atom1.materials = [makeMaterial(color: .systemBlue, glossy: true)]
        let n1 = SCNNode(geometry: atom1)
        n1.position = SCNVector3(-0.35, 0, 0)
        root.addChildNode(n1)

        let atom2 = SCNSphere(radius: 0.18)
        atom2.materials = [makeMaterial(color: .systemRed, glossy: true)]
        let n2 = SCNNode(geometry: atom2)
        n2.position = SCNVector3(0.35, 0, 0)
        root.addChildNode(n2)

        // Double bond (two cylinders)
        addBond(from: SCNVector3(-0.15, 0.04, 0), to: SCNVector3(0.15, 0.04, 0), root: root, thickness: 0.025)
        addBond(from: SCNVector3(-0.15, -0.04, 0), to: SCNVector3(0.15, -0.04, 0), root: root, thickness: 0.025)

        // Electron cloud (translucent)
        let cloud = SCNSphere(radius: 0.3)
        let cloudMat = SCNMaterial()
        cloudMat.diffuse.contents = UIColor.systemPurple.withAlphaComponent(0.08)
        cloudMat.isDoubleSided = true
        cloud.materials = [cloudMat]
        let cloudNode = SCNNode(geometry: cloud)
        root.addChildNode(cloudNode)
    }

    // MARK: - Helpers

    /// Creates a bond (thin cylinder) between two points.
    private func addBond(from: SCNVector3, to: SCNVector3, root: SCNNode, thickness: CGFloat = 0.03, color: UIColor = .lightGray) {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let dz = to.z - from.z
        let distance = sqrt(dx * dx + dy * dy + dz * dz)
        guard distance > 0.001 else { return }

        let bond = SCNCylinder(radius: thickness, height: CGFloat(distance))
        bond.materials = [makeMaterial(color: color)]
        let bondNode = SCNNode(geometry: bond)

        // Position at midpoint
        bondNode.position = SCNVector3((from.x + to.x) / 2, (from.y + to.y) / 2, (from.z + to.z) / 2)

        // Orient toward the target
        let up = SCNVector3(0, 1, 0)
        let dir = SCNVector3(dx, dy, dz)
        let cross = SCNVector3(up.y * dir.z - up.z * dir.y, up.z * dir.x - up.x * dir.z, up.x * dir.y - up.y * dir.x)
        let dot = up.x * dir.x + up.y * dir.y + up.z * dir.z
        let crossLen = sqrt(cross.x * cross.x + cross.y * cross.y + cross.z * cross.z)
        let angle = atan2(crossLen, dot)
        if crossLen > 0.0001 {
            bondNode.rotation = SCNVector4(cross.x / crossLen, cross.y / crossLen, cross.z / crossLen, angle)
        }

        root.addChildNode(bondNode)
    }

    /// Adds a small 3D text label.
    private func addTextLabel(_ text: String, at position: SCNVector3, color: UIColor, root: SCNNode) {
        let textGeom = SCNText(string: text, extrusionDepth: 0.02)
        textGeom.font = UIFont.systemFont(ofSize: 0.12, weight: .bold)
        textGeom.materials = [makeMaterial(color: color)]
        textGeom.flatness = 0.3
        let textNode = SCNNode(geometry: textGeom)
        // Center the text
        let (min, max) = textNode.boundingBox
        textNode.pivot = SCNMatrix4MakeTranslation((max.x - min.x) / 2 + min.x, (max.y - min.y) / 2 + min.y, 0)
        textNode.position = position
        root.addChildNode(textNode)
    }

    /// Creates a standard SceneKit material.
    private func makeMaterial(color: UIColor, glossy: Bool = false) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.specular.contents = UIColor.white
        mat.shininess = glossy ? 0.8 : 0.3
        if glossy {
            mat.lightingModel = .phong
        }
        return mat
    }

    /// Builds a single primitive geometry from shape name.
    private func buildPrimitive(_ shapeType: String) -> SCNGeometry {
        switch shapeType {
        case "cube":     return SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0.05)
        case "sphere":   return SCNSphere(radius: 0.5)
        case "cylinder": return SCNCylinder(radius: 0.5, height: 1)
        case "pyramid":  return SCNPyramid(width: 1, height: 1, length: 1)
        case "torus":    return SCNTorus(ringRadius: 0.5, pipeRadius: 0.15)
        case "cone":     return SCNCone(topRadius: 0, bottomRadius: 0.5, height: 1)
        case "capsule":  return SCNCapsule(capRadius: 0.25, height: 1)
        default:         return SCNSphere(radius: 0.5)
        }
    }

    // MARK: - Lighting

    /// Adds better lighting for composite scenes.
    private func addLighting(to scene: SCNScene) {
        // Key light
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 1000
        keyLight.color = UIColor.white
        let keyNode = SCNNode()
        keyNode.light = keyLight
        keyNode.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
        scene.rootNode.addChildNode(keyNode)

        // Fill light (softer, from opposite side)
        let fillLight = SCNLight()
        fillLight.type = .directional
        fillLight.intensity = 400
        fillLight.color = UIColor(white: 0.8, alpha: 1)
        let fillNode = SCNNode()
        fillNode.light = fillLight
        fillNode.eulerAngles = SCNVector3(Float.pi / 6, -Float.pi / 3, 0)
        scene.rootNode.addChildNode(fillNode)
        
        // Ambient Light (Crucial for PBR materials in USDZ models)
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 800 // High enough to reveal dark textures
        ambientLight.color = UIColor(white: 1.0, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
    }

    // MARK: - Animation

    private func applyAnimation(to node: SCNNode, type: String) {
        node.removeAllActions()

        switch type {
        case "rotate":
            let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 10)
            node.runAction(.repeatForever(rotate))

        case "pulse":
            let up = SCNAction.scale(by: 1.15, duration: 1.0)
            let down = SCNAction.scale(by: 1.0 / 1.15, duration: 1.0)
            node.runAction(.repeatForever(.sequence([up, down])))

        case "bounce":
            let moveUp = SCNAction.moveBy(x: 0, y: 0.3, z: 0, duration: 0.6)
            moveUp.timingMode = .easeOut
            let moveDown = SCNAction.moveBy(x: 0, y: -0.3, z: 0, duration: 0.6)
            moveDown.timingMode = .easeIn
            node.runAction(.repeatForever(.sequence([moveUp, moveDown])))

        default:
            // Idle slow rotation
            let idle = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 20)
            node.runAction(.repeatForever(idle))
        }
    }

    // MARK: - New Advanced Objects

    private func buildMicroscope(root: SCNNode) {
        // Base
        let base = SCNBox(width: 0.4, height: 0.05, length: 0.6, chamferRadius: 0.02)
        base.materials = [makeMaterial(color: .darkGray)]
        let baseNode = SCNNode(geometry: base)
        baseNode.position = SCNVector3(0, -0.4, 0)
        root.addChildNode(baseNode)

        // Arm (curved back)
        let arm = SCNTorus(ringRadius: 0.25, pipeRadius: 0.06)
        arm.materials = [makeMaterial(color: .systemGray)]
        let armNode = SCNNode(geometry: arm)
        armNode.position = SCNVector3(0, 0, -0.1)
        armNode.eulerAngles.y = Float.pi / 2
        // We really want a half torus, but this gives the shape if we hide the bottom
        root.addChildNode(armNode)
        
        // Stage (where slides go)
        let stage = SCNBox(width: 0.35, height: 0.02, length: 0.35, chamferRadius: 0.01)
        stage.materials = [makeMaterial(color: .black)]
        let stageNode = SCNNode(geometry: stage)
        stageNode.position = SCNVector3(0, -0.15, 0.1)
        root.addChildNode(stageNode)

        // Tube and Eyepiece
        let topTube = SCNCylinder(radius: 0.06, height: 0.4)
        topTube.materials = [makeMaterial(color: .systemGray)]
        let tubeNode = SCNNode(geometry: topTube)
        tubeNode.position = SCNVector3(0, 0.2, 0.1)
        tubeNode.eulerAngles.x = Float.pi / 12
        root.addChildNode(tubeNode)
        
        // Objective Lenses (3 small cylinders going down towards the stage)
        let lensColors: [UIColor] = [.systemRed, .systemYellow, .systemBlue]
        for i in 0..<3 {
            let lens = SCNCylinder(radius: 0.02, height: 0.1)
            lens.materials = [makeMaterial(color: .lightGray)]
            let lNode = SCNNode(geometry: lens)
            let angle = Float(i) * Float.pi * 2 / 3
            let r: Float = 0.06
            lNode.position = SCNVector3(r * cos(angle), -0.2, 0.1 + r * sin(angle))
            
            // Colored strip to indicate magnification
            let strip = SCNCylinder(radius: 0.021, height: 0.02)
            strip.materials = [makeMaterial(color: lensColors[i])]
            let sNode = SCNNode(geometry: strip)
            lNode.addChildNode(sNode)

            root.addChildNode(lNode)
        }
    }

    private func buildTelescope(root: SCNNode) {
        // Main Tube
        let tube = SCNCylinder(radius: 0.1, height: 0.8)
        tube.materials = [makeMaterial(color: .white, glossy: true)]
        let tubeNode = SCNNode(geometry: tube)
        tubeNode.position = SCNVector3(0, 0.2, 0)
        tubeNode.eulerAngles.x = Float.pi / 4 // Angled up
        root.addChildNode(tubeNode)

        // Eyepiece (black end)
        let eyepiece = SCNCylinder(radius: 0.04, height: 0.1)
        eyepiece.materials = [makeMaterial(color: .black)]
        let eyeNode = SCNNode(geometry: eyepiece)
        eyeNode.position = SCNVector3(0, -0.45, 0)
        tubeNode.addChildNode(eyeNode)

        // Lens end (blue glass)
        let lens = SCNCylinder(radius: 0.095, height: 0.02)
        lens.materials = [makeMaterial(color: .systemCyan)]
        let lensNode = SCNNode(geometry: lens)
        lensNode.position = SCNVector3(0, 0.4, 0)
        tubeNode.addChildNode(lensNode)
        
        // Finder scope (small tube on top side)
        let finder = SCNCylinder(radius: 0.025, height: 0.25)
        finder.materials = [makeMaterial(color: .white)]
        let finderNode = SCNNode(geometry: finder)
        finderNode.position = SCNVector3(0.12, -0.1, 0)
        tubeNode.addChildNode(finderNode)

        // Tripod (3 legs)
        for i in 0..<3 {
            let leg = SCNCylinder(radius: 0.02, height: 0.7)
            leg.materials = [makeMaterial(color: .black)]
            let legNode = SCNNode(geometry: leg)
            let angle = Float(i) * Float.pi * 2 / 3
            legNode.position = SCNVector3(0.25 * cos(angle), -0.25, 0.25 * sin(angle))
            // Angle legs inwards towards mount point
            legNode.eulerAngles.x = 0.3 * sin(angle)
            legNode.eulerAngles.z = -0.3 * cos(angle)
            root.addChildNode(legNode)
        }
    }

    private func buildCompass(root: SCNNode) {
        // Outer case (gold ring)
        let caseTorus = SCNTorus(ringRadius: 0.4, pipeRadius: 0.04)
        caseTorus.materials = [makeMaterial(color: UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 1.0), glossy: true)]
        let caseNode = SCNNode(geometry: caseTorus)
        // Lay flat
        caseNode.eulerAngles.x = Float.pi / 2
        root.addChildNode(caseNode)

        // Base plate (white dial)
        let dial = SCNCylinder(radius: 0.39, height: 0.02)
        dial.materials = [makeMaterial(color: .white)]
        let dialNode = SCNNode(geometry: dial)
        dialNode.eulerAngles.x = Float.pi / 2
        dialNode.position = SCNVector3(0, 0, -0.02)
        root.addChildNode(dialNode)
        
        // Cardinal direction labels
        addTextLabel("N", at: SCNVector3(0, 0.25, 0.02), color: .systemRed, root: root)
        addTextLabel("S", at: SCNVector3(0, -0.25, 0.02), color: .black, root: root)
        addTextLabel("E", at: SCNVector3(0.25, 0, 0.02), color: .black, root: root)
        addTextLabel("W", at: SCNVector3(-0.25, 0, 0.02), color: .black, root: root)

        // Needle Pivot
        let pivot = SCNSphere(radius: 0.03)
        pivot.materials = [makeMaterial(color: UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 1.0))]
        let pivotNode = SCNNode(geometry: pivot)
        pivotNode.position = SCNVector3(0, 0, 0.05)
        root.addChildNode(pivotNode)

        // Needle Node (to hold north and south points)
        let needleRoot = SCNNode()
        needleRoot.position = SCNVector3(0, 0, 0.05)

        // North Needle (red)
        let northNeedle = SCNPyramid(width: 0.1, height: 0.35, length: 0.02)
        northNeedle.materials = [makeMaterial(color: .systemRed)]
        let nNode = SCNNode(geometry: northNeedle)
        // Lay it flat, tip pointing along +Y (which is North before rotation)
        nNode.position = SCNVector3(0, 0.175, 0)
        needleRoot.addChildNode(nNode)

        // South Needle (silver)
        let southNeedle = SCNPyramid(width: 0.1, height: 0.35, length: 0.02)
        southNeedle.materials = [makeMaterial(color: .lightGray)]
        let sNode = SCNNode(geometry: southNeedle)
        sNode.eulerAngles.z = Float.pi // Point down
        sNode.position = SCNVector3(0, -0.175, 0)
        needleRoot.addChildNode(sNode)

        // Add a gentle idle rotation to the needle finding north
        let wobble1 = SCNAction.rotateBy(x: 0, y: 0, z: 0.1, duration: 1)
        wobble1.timingMode = .easeInEaseOut
        let wobble2 = SCNAction.rotateBy(x: 0, y: 0, z: -0.2, duration: 1)
        wobble2.timingMode = .easeInEaseOut
        let wobble3 = SCNAction.rotateBy(x: 0, y: 0, z: 0.1, duration: 0.5)
        wobble3.timingMode = .easeInEaseOut
        needleRoot.runAction(.repeatForever(.sequence([wobble1, wobble2, wobble3, .wait(duration: 2.0)])))
        
        root.addChildNode(needleRoot)
    }

    private func buildPrism(root: SCNNode) {
        // Prism body (translucent pyramid with 3 sides representing a triangular block)
        let prism = SCNPyramid(width: 0.5, height: 0.6, length: 0.5)
        let pMat = SCNMaterial()
        pMat.diffuse.contents = UIColor(white: 1.0, alpha: 0.2)
        pMat.specular.contents = UIColor.white
        pMat.transparent.contents = UIColor(white: 1.0, alpha: 0.3)
        pMat.shininess = 1.0
        prism.materials = [pMat]
        let pNode = SCNNode(geometry: prism)
        pNode.position = SCNVector3(0, -0.3, 0)
        root.addChildNode(pNode)

        // Incoming white light ray
        let inRay = SCNCylinder(radius: 0.015, height: 0.6)
        let inMat = SCNMaterial()
        inMat.emission.contents = UIColor.white
        inRay.materials = [inMat]
        let inNode = SCNNode(geometry: inRay)
        inNode.eulerAngles.z = -Float.pi / 4
        inNode.position = SCNVector3(-0.4, 0, 0)
        root.addChildNode(inNode)

        // Outgoing rainbow spectrum (6 colored rays)
        let colors: [UIColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue, .systemPurple]
        for i in 0..<6 {
            let outRay = SCNCylinder(radius: 0.01, height: 0.8)
            let outMat = SCNMaterial()
            outMat.emission.contents = colors[i]
            outRay.materials = [outMat]
            let oNode = SCNNode(geometry: outRay)
            // Fan them out slightly
            let angle = Float.pi / 12 + Float(i) * 0.05
            oNode.eulerAngles.z = angle
            oNode.position = SCNVector3(0.4, -0.1 - Float(i) * 0.02, 0)
            root.addChildNode(oNode)
        }
    }

    private func buildBlackHole(root: SCNNode) {
        // Core Singularity (pure black)
        let core = SCNSphere(radius: 0.15)
        let coreMat = SCNMaterial()
        coreMat.diffuse.contents = UIColor.black
        coreMat.emission.contents = UIColor.black
        core.materials = [coreMat]
        let coreNode = SCNNode(geometry: core)
        root.addChildNode(coreNode)

        // Photon ring (intense white/orange inner glow directly on the horizon)
        let horizon = SCNSphere(radius: 0.17)
        let hMat = SCNMaterial()
        hMat.emission.contents = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 0.8)
        hMat.transparent.contents = UIColor(white: 1.0, alpha: 0.5)
        hMat.isDoubleSided = true
        horizon.materials = [hMat]
        let hNode = SCNNode(geometry: horizon)
        root.addChildNode(hNode)

        // Accretion Disk (glowing swirly toruses)
        let ringColors: [UIColor] = [
            UIColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 0.9),
            UIColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 0.7),
            UIColor(red: 0.8, green: 0.4, blue: 0.1, alpha: 0.4)
        ]
        
        let container = SCNNode()
        
        for i in 0..<3 {
            let ringRadius = 0.3 + CGFloat(i) * 0.15
            let pipeRadius = 0.05 - CGFloat(i) * 0.01
            let disk = SCNTorus(ringRadius: ringRadius, pipeRadius: pipeRadius)
            let dMat = SCNMaterial()
            dMat.diffuse.contents = UIColor.black
            dMat.emission.contents = ringColors[i]
            dMat.transparent.contents = ringColors[i]
            disk.materials = [dMat]
            let dNode = SCNNode(geometry: disk)
            // Flatten the disk
            dNode.scale = SCNVector3(1, 0.1, 1)
            
            // Add slight wobble to inner rings for chaotic effect
            if i == 0 {
                let wobble = SCNAction.rotateBy(x: 0.1, y: 0.1, z: 0, duration: 1)
                dNode.runAction(.repeatForever(wobble))
            }
            container.addChildNode(dNode)
        }
        
        // Tilt the whole accretion disk
        container.eulerAngles.x = Float.pi / 5
        container.eulerAngles.z = Float.pi / 8
        
        // Spin the accretion disk super fast
        container.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 1)))
        
        root.addChildNode(container)
    }

    private func buildRocket(root: SCNNode) {
        let rocketBody = SCNNode()

        // Main Fuselage (White Cylinder)
        let fuselage = SCNCylinder(radius: 0.15, height: 0.7)
        fuselage.materials = [makeMaterial(color: .white, glossy: true)]
        let fNode = SCNNode(geometry: fuselage)
        rocketBody.addChildNode(fNode)

        // Nose Cone (Red Cone)
        let nose = SCNCone(topRadius: 0, bottomRadius: 0.15, height: 0.25)
        nose.materials = [makeMaterial(color: .systemRed, glossy: true)]
        let nNode = SCNNode(geometry: nose)
        nNode.position = SCNVector3(0, 0.475, 0)
        rocketBody.addChildNode(nNode)

        // Window (Cyan glass)
        let window = SCNCylinder(radius: 0.05, height: 0.02)
        window.materials = [makeMaterial(color: .systemCyan)]
        let wNode = SCNNode(geometry: window)
        wNode.position = SCNVector3(0, 0.15, 0.14)
        wNode.eulerAngles.x = Float.pi / 2
        rocketBody.addChildNode(wNode)
        
        // Fins (3 red fins)
        for i in 0..<3 {
            let fin = SCNBox(width: 0.02, height: 0.2, length: 0.2, chamferRadius: 0.01)
            fin.materials = [makeMaterial(color: .systemRed, glossy: true)]
            let finNode = SCNNode(geometry: fin)
            let angle = Float(i) * Float.pi * 2 / 3
            finNode.position = SCNVector3(0.15 * cos(angle), -0.25, 0.15 * sin(angle))
            finNode.eulerAngles.y = angle
            rocketBody.addChildNode(finNode)
        }
        
        // Engine Nozzle
        let nozzle = SCNCone(topRadius: 0.08, bottomRadius: 0.12, height: 0.1)
        nozzle.materials = [makeMaterial(color: .darkGray)]
        let nozNode = SCNNode(geometry: nozzle)
        nozNode.position = SCNVector3(0, -0.4, 0)
        rocketBody.addChildNode(nozNode)
        
        // Fire / Exhaust
        let exhaust = SCNCone(topRadius: 0.1, bottomRadius: 0, height: 0.35)
        let flameMat = SCNMaterial()
        flameMat.emission.contents = UIColor.systemOrange
        flameMat.diffuse.contents = UIColor.systemYellow
        exhaust.materials = [flameMat]
        let eNode = SCNNode(geometry: exhaust)
        eNode.position = SCNVector3(0, -0.6, 0)
        
        let flicker = SCNAction.sequence([
            .scale(to: 1.2, duration: 0.1),
            .scale(to: 0.8, duration: 0.1)
        ])
        eNode.runAction(.repeatForever(flicker))
        rocketBody.addChildNode(eNode)

        // Tilt rocket
        rocketBody.eulerAngles.z = -Float.pi / 8
        root.addChildNode(rocketBody)
    }

    private func buildFossil(root: SCNNode) {
        // Rock Base
        let rock = SCNBox(width: 0.6, height: 0.1, length: 0.6, chamferRadius: 0.05)
        let rockMat = SCNMaterial()
        rockMat.diffuse.contents = UIColor(red: 0.5, green: 0.45, blue: 0.4, alpha: 1)
        rock.materials = [rockMat]
        let rockNode = SCNNode(geometry: rock)
        rockNode.position = SCNVector3(0, -0.05, 0)
        root.addChildNode(rockNode)
        
        // Ammonite Fossil (Spiral made of decreasing spheres)
        let spiralRoot = SCNNode()
        let steps = 40
        var radius: Float = 0.25
        var angle: Float = 0
        
        for _ in 0..<steps {
            let sphere = SCNSphere(radius: CGFloat(radius * 0.25))
            let boneMat = SCNMaterial()
            boneMat.diffuse.contents = UIColor(red: 0.8, green: 0.75, blue: 0.65, alpha: 1)
            sphere.materials = [boneMat]
            let sNode = SCNNode(geometry: sphere)
            
            sNode.position = SCNVector3(radius * cos(angle), 0, radius * sin(angle))
            spiralRoot.addChildNode(sNode)
            
            angle += 0.4
            radius *= 0.94 // Shrink radius inwards
        }
        
        spiralRoot.position = SCNVector3(0, 0.02, 0) // Embed slightly in rock
        root.addChildNode(spiralRoot)
    }

    private func buildBattery(root: SCNNode) {
        // Main Body (Cylinder)
        let body = SCNCylinder(radius: 0.2, height: 0.7)
        let bodyMat = SCNMaterial()
        bodyMat.diffuse.contents = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        body.materials = [bodyMat]
        let bodyNode = SCNNode(geometry: body)
        root.addChildNode(bodyNode)
        
        // Top and Bottom Wrappers (Green)
        for ySign: Float in [-1, 1] {
            // Leave a strip in the middle black, tops and bottoms green
            let wrap = SCNCylinder(radius: 0.205, height: 0.25)
            wrap.materials = [makeMaterial(color: .systemGreen)]
            let wNode = SCNNode(geometry: wrap)
            wNode.position = SCNVector3(0, ySign * 0.2, 0)
            root.addChildNode(wNode)
        }
        
        // Positive Terminal (Silver bump on top)
        let posTerminal = SCNCylinder(radius: 0.06, height: 0.05)
        posTerminal.materials = [makeMaterial(color: .lightGray)]
        let posNode = SCNNode(geometry: posTerminal)
        posNode.position = SCNVector3(0, 0.375, 0)
        root.addChildNode(posNode)
        
        // Labels
        addTextLabel("+", at: SCNVector3(0, 0.2, 0.22), color: .white, root: root)
        addTextLabel("-", at: SCNVector3(0, -0.2, 0.22), color: .white, root: root)
    }

    // MARK: - Color Mapping

    private func colorFromName(_ name: String) -> UIColor {
        switch name.lowercased() {
        case "red":    return .systemRed
        case "blue":   return .systemBlue
        case "green":  return .systemGreen
        case "orange": return .systemOrange
        case "purple": return .systemPurple
        case "pink":   return .systemPink
        case "yellow": return .systemYellow
        case "gray":   return .systemGray
        case "black":  return .black
        case "white":  return .white
        case "brown":  return .brown
        case "gold":   return UIColor(red: 0.85, green: 0.75, blue: 0.45, alpha: 1)
        case "silver": return UIColor(red: 0.75, green: 0.75, blue: 0.78, alpha: 1)
        case "cyan":   return .systemCyan
        default:       return .systemBlue
        }
    }
}
