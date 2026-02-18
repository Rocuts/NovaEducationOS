import Foundation
import FoundationModels

// MARK: - Render Mode

enum RenderMode: String, Codable, Sendable {
    case image
    case object3d
}

// MARK: - Render Intent (from Router)

enum RenderIntent: Sendable, Equatable {
    case none
    case render2D
    case render3D
    case ambiguousRender

    var hasRenderIntent: Bool { self != .none }

    var defaultMode: RenderMode {
        switch self {
        case .render2D: return .image
        case .render3D, .ambiguousRender: return .object3d
        case .none: return .object3d
        }
    }
}

// MARK: - Router Result

struct RouterResult: Sendable {
    let intent: RenderIntent
    let detectedColor: RenderColor?
    let detectedPrimitive: RenderPrimitive?
    let detectedConcept: String?
    let isModification: Bool
    let modificationSize: RenderSize?
    let modificationColor: RenderColor?

    var hasRenderIntent: Bool { intent.hasRenderIntent }

    static let none = RouterResult(
        intent: .none,
        detectedColor: nil,
        detectedPrimitive: nil,
        detectedConcept: nil,
        isModification: false,
        modificationSize: nil,
        modificationColor: nil
    )
}

// MARK: - Primitives

@Generable
enum RenderPrimitive: String, CaseIterable, Codable, Sendable {
    case cube
    case sphere
    case pyramid
    case cone
    case cylinder
    case torus
    case capsule
    case plane
}

// MARK: - Closed Color Palette

@Generable
enum RenderColor: String, CaseIterable, Codable, Sendable {
    case red
    case blue
    case green
    case yellow
    case orange
    case purple
    case pink
    case white
    case black
    case gray
    case brown
    case gold
    case silver
    case cyan

    /// Maps to SceneKit-compatible color names for GeometryView
    var sceneKitName: String {
        switch self {
        case .gold: return "yellow"
        case .silver: return "gray"
        case .cyan: return "blue"
        default: return rawValue
        }
    }
}

// MARK: - Material

enum RenderMaterial: String, Codable, Sendable {
    case matte
    case glossy
    case metal
    case glass
    case plastic
}

// MARK: - Style

enum RenderStyle: String, Codable, Sendable {
    case diagram
    case realistic
    case cartoon
    case minimal
}

// MARK: - Size

@Generable
enum RenderSize: String, CaseIterable, Codable, Sendable {
    case small
    case medium
    case large

    var scaleValue: Double {
        switch self {
        case .small: return 0.6
        case .medium: return 1.0
        case .large: return 1.5
        }
    }
}

// MARK: - Camera

enum CameraAngle: String, Codable, Sendable {
    case `default`
    case closeUp
    case wide
}

// MARK: - Lighting

enum LightingType: String, Codable, Sendable {
    case `default`
    case bright
    case soft
}

// MARK: - Animation

enum RenderAnimation: String, Codable, Sendable {
    case none
    case rotateSlow
    case orbit
    case pulse
    case bounce

    /// Maps to GeometryView animation names
    var sceneKitName: String {
        switch self {
        case .none: return "none"
        case .rotateSlow, .orbit: return "rotate"
        case .pulse: return "pulse"
        case .bounce: return "bounce"
        }
    }
}

// MARK: - Educational Presets

enum RenderPreset: String, Codable, Sendable {
    // Astronomy
    case solarSystem, earth, mars, saturn, jupiter, moon, sun, star
    // Biology
    case atom, molecule, waterMolecule
    case cell, dna
    case heart, lung, eye, brain
    case flower, tree, leaf
    // Geography
    case volcano, mountain
    // Physics
    case pendulum, magnet, wave
    // Chemistry
    case crystal, chemicalBond

    var defaultPrimitive: RenderPrimitive {
        switch self {
        case .atom, .molecule, .waterMolecule, .earth, .mars, .jupiter, .moon, .sun, .star,
             .eye, .cell, .solarSystem, .saturn, .heart, .lung, .brain, .flower, .tree, .leaf:
            return .sphere
        case .dna, .pendulum, .chemicalBond:
            return .cylinder
        case .crystal:
            return .cube
        case .volcano, .mountain:
            return .cone
        case .magnet:
            return .capsule
        case .wave:
            return .torus
        }
    }

    var defaultColor: RenderColor {
        switch self {
        case .earth: return .blue
        case .mars: return .red
        case .saturn: return .gold
        case .jupiter: return .orange
        case .moon: return .gray
        case .sun, .star, .solarSystem: return .yellow
        case .atom: return .blue
        case .molecule, .waterMolecule: return .cyan
        case .cell, .tree, .leaf: return .green
        case .dna: return .purple
        case .heart: return .red
        case .lung, .brain: return .pink
        case .eye: return .blue
        case .flower: return .red
        case .volcano: return .red
        case .mountain: return .gray
        case .pendulum: return .gray
        case .magnet: return .red
        case .wave: return .blue
        case .crystal: return .cyan
        case .chemicalBond: return .blue
        }
    }

    var defaultAnimation: RenderAnimation {
        switch self {
        case .atom, .molecule, .waterMolecule, .dna,
             .solarSystem, .earth, .mars, .saturn, .jupiter:
            return .rotateSlow
        case .pendulum, .wave:
            return .bounce
        case .heart:
            return .pulse
        default:
            return .rotateSlow
        }
    }

    var spanishName: String {
        switch self {
        case .solarSystem: return "Sistema Solar"
        case .earth: return "Tierra"
        case .mars: return "Marte"
        case .saturn: return "Saturno"
        case .jupiter: return "Júpiter"
        case .moon: return "Luna"
        case .sun: return "Sol"
        case .star: return "Estrella"
        case .atom: return "Átomo"
        case .molecule: return "Molécula"
        case .waterMolecule: return "Molécula de agua"
        case .cell: return "Célula"
        case .dna: return "ADN"
        case .heart: return "Corazón"
        case .lung: return "Pulmón"
        case .eye: return "Ojo"
        case .brain: return "Cerebro"
        case .flower: return "Flor"
        case .tree: return "Árbol"
        case .leaf: return "Hoja"
        case .volcano: return "Volcán"
        case .mountain: return "Montaña"
        case .pendulum: return "Péndulo"
        case .magnet: return "Imán"
        case .wave: return "Onda"
        case .crystal: return "Cristal"
        case .chemicalBond: return "Enlace químico"
        }
    }

    var englishImagePrompt: String {
        switch self {
        case .solarSystem: return "Simple solar system diagram with sun and planets"
        case .earth: return "Planet Earth from space"
        case .mars: return "Planet Mars red surface"
        case .saturn: return "Planet Saturn with rings"
        case .jupiter: return "Planet Jupiter gas giant"
        case .moon: return "Earth Moon surface craters"
        case .sun: return "The Sun star"
        case .star: return "Bright star in space"
        case .atom: return "Atomic model with nucleus and electron orbits Bohr model"
        case .molecule: return "Simple molecule diagram with atoms and bonds"
        case .waterMolecule: return "Water molecule H2O structural diagram"
        case .cell: return "Animal cell with organelles"
        case .dna: return "DNA double helix structure"
        case .heart: return "Human heart anatomy educational illustration"
        case .lung: return "Human lungs anatomy educational"
        case .eye: return "Human eye cross section anatomy"
        case .brain: return "Human brain anatomy lobes"
        case .flower: return "Flower anatomy parts educational diagram"
        case .tree: return "Tree with roots trunk branches leaves"
        case .leaf: return "Leaf structure cross section chloroplast"
        case .volcano: return "Volcano cross section lava magma chamber"
        case .mountain: return "Mountain landscape geological layers"
        case .pendulum: return "Simple pendulum physics diagram"
        case .magnet: return "Bar magnet magnetic field lines"
        case .wave: return "Wave diagram wavelength amplitude"
        case .crystal: return "Crystal lattice structure"
        case .chemicalBond: return "Chemical bond atoms sharing electrons"
        }
    }
}

// MARK: - RenderRequest (validated, normalized, ready for execution)

struct RenderRequest: Sendable {
    var mode: RenderMode
    var concept: String
    var preset: RenderPreset?
    var primitive: RenderPrimitive?
    var color: RenderColor
    var material: RenderMaterial
    var style: RenderStyle
    var size: RenderSize
    var camera: CameraAngle
    var lighting: LightingType
    var animation: RenderAnimation
    var labelText: String?
    var locale: String

    var resolvedPrimitive: RenderPrimitive {
        if let p = primitive { return p }
        if let preset = preset { return preset.defaultPrimitive }
        return .cube
    }

    /// Fallback request that always works (blue cube)
    static let fallback = RenderRequest(
        mode: .object3d,
        concept: "figura",
        preset: nil,
        primitive: .cube,
        color: .blue,
        material: .matte,
        style: .diagram,
        size: .medium,
        camera: .default,
        lighting: .default,
        animation: .rotateSlow,
        labelText: nil,
        locale: "es"
    )
}

// MARK: - Render Output

struct RenderOutput: Sendable {
    let assetId: String
    let spokenSummary: String
    let renderMode: RenderMode
    let controlsEnabled: RenderControls
    let attachmentType: String
    let attachmentData: String?
    let imageURL: URL?

    struct RenderControls: Sendable {
        let rotate: Bool
        let zoom: Bool
        let pan: Bool
    }

    /// Fallback output when everything fails
    static let fallback = RenderOutput(
        assetId: UUID().uuidString,
        spokenSummary: "Te muestro una figura 3D. ¿Qué forma quieres exactamente?",
        renderMode: .object3d,
        controlsEnabled: .init(rotate: true, zoom: true, pan: true),
        attachmentType: "geometry_3d",
        attachmentData: "{\"shape\":\"cube\",\"color\":\"blue\",\"scale\":1.0,\"animation\":\"rotate\",\"caption\":\"\"}",
        imageURL: nil
    )
}

// MARK: - LLM Extraction Type (guided generation)

@Generable
struct RenderExtraction: Sendable {
    @Guide(description: "Object to render in English, e.g. pyramid, atom, heart")
    var objectName: String

    @Guide(description: "Color if mentioned by user")
    var color: RenderColor?

    @Guide(description: "Geometric shape if applicable")
    var shape: RenderPrimitive?
}
