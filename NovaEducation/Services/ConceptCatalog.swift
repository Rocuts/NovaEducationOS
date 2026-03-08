import Foundation

// MARK: - Concept Catalog
// Deterministic mapping of Spanish educational concepts to render presets.
// This eliminates LLM dependency for known concepts, maximizing reliability.

struct ConceptEntry: Sendable {
    let preset: RenderPreset?
    let primitive: RenderPrimitive?
    let defaultMode: RenderMode
    let defaultColor: RenderColor
    let defaultAnimation: RenderAnimation
    let spanishCaption: String
    let englishImagePrompt: String
    let category: ConceptCategory

    enum ConceptCategory: String, Sendable {
        case geometry
        case astronomy
        case biology
        case chemistry
        case physics
        case geography
        case anatomy
    }

    func toRenderRequest(mode: RenderMode? = nil, color: RenderColor? = nil, size: RenderSize = .medium) -> RenderRequest {
        RenderRequest(
            mode: mode ?? defaultMode,
            concept: spanishCaption,
            preset: preset,
            primitive: primitive,
            color: color ?? defaultColor,
            material: .matte,
            style: .diagram,
            size: size,
            camera: .default,
            lighting: .default,
            animation: defaultAnimation,
            labelText: spanishCaption,
            locale: "es"
        )
    }
}

enum ConceptCatalog {

    // MARK: - Public API

    /// Attempts to match user text against known concepts.
    /// Returns the best ConceptEntry if found.
    static func match(_ text: String) -> ConceptEntry? {
        let normalized = normalize(text)

        // Direct lookup first (fastest path)
        if let entry = catalog[normalized] { return entry }

        // Try each registered key as a substring match
        for (key, entry) in catalog {
            if normalized.contains(key) { return entry }
        }

        // Try synonym lookup
        for (synonym, canonicalKey) in synonyms {
            if normalized.contains(synonym), let entry = catalog[canonicalKey] {
                return entry
            }
        }

        return nil
    }

    /// Quick check without returning the entry
    static func hasMatch(_ text: String) -> Bool {
        match(text) != nil
    }

    // MARK: - Normalization

    /// Normalize text: lowercase, remove diacritics, strip articles and common filler
    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
            .replacingOccurrences(of: "¿", with: "")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "¡", with: "")
            .replacingOccurrences(of: "!", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Synonym Table

    /// Maps alternate spellings, plurals, and colloquial forms to canonical keys
    private static let synonyms: [String: String] = [
        // Geometry synonyms
        "piramides": "piramide",
        "cubos": "cubo",
        "esferas": "esfera",
        "conos": "cono",
        "cilindros": "cilindro",
        "toroides": "toroide",
        "dona": "toroide",
        "donas": "toroide",
        "rosquilla": "toroide",
        "capsulas": "capsula",
        "prisma": "cubo",
        "rectangulo": "cubo",
        "rectangulos": "cubo",
        "dado": "cubo",
        "dados": "cubo",
        "pelota": "esfera",
        "pelotas": "esfera",
        "bola": "esfera",
        "bolas": "esfera",
        "globo": "esfera",
        "circulo": "esfera",
        "triangulo": "piramide",

        // Astronomy synonyms
        "la tierra": "tierra",
        "planeta tierra": "tierra",
        "planeta marte": "marte",
        "planeta saturno": "saturno",
        "planeta jupiter": "jupiter",
        "planetas": "sistema solar",
        "los planetas": "sistema solar",
        "via lactea": "estrella",
        "galaxia": "estrella",
        "cosmos": "sistema solar",
        "universo": "sistema solar",
        "astro": "estrella",
        "lucero": "estrella",
        "telescopios": "telescopio",
        "un telescopio": "telescopio",
        "astronomia": "telescopio",
        "agujeros negros": "agujero negro",
        "hoyo negro": "agujero negro",
        "cohetes": "cohete",
        "nave espacial": "cohete",
        "transbordador": "cohete",

        // Biology synonyms
        "atomos": "atomo",
        "el atomo": "atomo",
        "un atomo": "atomo",
        "modelo atomico": "atomo",
        "moleculas": "molecula",
        "celulas": "celula",
        "celula animal": "celula",
        "celula vegetal": "celula",
        "adn": "adn",
        "a d n": "adn",
        "codigo genetico": "adn",
        "genetica": "adn",
        "acido desoxirribonucleico": "adn",
        "cadena de adn": "adn",
        "doble helice": "adn",
        "h2o": "agua",
        "molecula de agua": "agua",
        "molecula del agua": "agua",
        "flores": "flor",
        "arboles": "arbol",
        "arbolito": "arbol",
        "hojas": "hoja",
        "planta": "arbol",
        "plantas": "arbol",
        "microscopios": "microscopio",
        "un microscopio": "microscopio",
        "fosiles": "fosil",
        "dinosaurio fosil": "fosil",
        "amonita": "fosil",

        // Anatomy synonyms
        "corazones": "corazon",
        "el corazon": "corazon",
        "organo corazon": "corazon",
        "pulmones": "pulmon",
        "los pulmones": "pulmon",
        "ojos": "ojo",
        "el ojo": "ojo",
        "el ojo humano": "ojo",
        "cerebros": "cerebro",
        "el cerebro": "cerebro",

        // Geography synonyms
        "volcanes": "volcan",
        "un volcan": "volcan",
        "el volcan": "volcan",
        "montanas": "montana",
        "cerro": "montana",
        "cerros": "montana",
        "brujulas": "brujula",
        "una brujula": "brujula",
        "norte sur": "brujula",

        // Physics synonyms
        "pendulos": "pendulo",
        "un pendulo": "pendulo",
        "imanes": "iman",
        "un iman": "iman",
        "el iman": "iman",
        "magnetismo": "iman",
        "ondas": "onda",
        "onda sonora": "onda",
        "onda electromagnetica": "onda",
        "baterias": "bateria",
        "pila": "bateria",
        "pilas": "bateria",
        "prismas": "prisma",
        "dispersion de luz": "prisma",
        "prisma optico": "prisma",

        // Chemistry synonyms
        "cristales": "cristal",
        "enlace quimico": "enlace",
        "enlaces quimicos": "enlace",
        "enlace covalente": "enlace",
        "enlace ionico": "enlace",
    ]

    // MARK: - Main Catalog (50+ concepts)

    private static let catalog: [String: ConceptEntry] = [

        // ── Geometry (10) ──────────────────────────────────────────────

        "piramide": ConceptEntry(
            preset: nil, primitive: .pyramid, defaultMode: .object3d,
            defaultColor: .yellow, defaultAnimation: .rotateSlow,
            spanishCaption: "Pirámide", englishImagePrompt: "Geometric pyramid shape",
            category: .geometry
        ),
        "cubo": ConceptEntry(
            preset: nil, primitive: .cube, defaultMode: .object3d,
            defaultColor: .blue, defaultAnimation: .rotateSlow,
            spanishCaption: "Cubo", englishImagePrompt: "Geometric cube",
            category: .geometry
        ),
        "esfera": ConceptEntry(
            preset: nil, primitive: .sphere, defaultMode: .object3d,
            defaultColor: .blue, defaultAnimation: .rotateSlow,
            spanishCaption: "Esfera", englishImagePrompt: "Geometric sphere",
            category: .geometry
        ),
        "cono": ConceptEntry(
            preset: nil, primitive: .cone, defaultMode: .object3d,
            defaultColor: .green, defaultAnimation: .rotateSlow,
            spanishCaption: "Cono", englishImagePrompt: "Geometric cone",
            category: .geometry
        ),
        "cilindro": ConceptEntry(
            preset: nil, primitive: .cylinder, defaultMode: .object3d,
            defaultColor: .orange, defaultAnimation: .rotateSlow,
            spanishCaption: "Cilindro", englishImagePrompt: "Geometric cylinder",
            category: .geometry
        ),
        "toroide": ConceptEntry(
            preset: nil, primitive: .torus, defaultMode: .object3d,
            defaultColor: .purple, defaultAnimation: .rotateSlow,
            spanishCaption: "Toroide", englishImagePrompt: "Torus shape",
            category: .geometry
        ),
        "capsula": ConceptEntry(
            preset: nil, primitive: .capsule, defaultMode: .object3d,
            defaultColor: .cyan, defaultAnimation: .rotateSlow,
            spanishCaption: "Cápsula", englishImagePrompt: "Capsule shape",
            category: .geometry
        ),
        "plano": ConceptEntry(
            preset: nil, primitive: .plane, defaultMode: .object3d,
            defaultColor: .gray, defaultAnimation: .none,
            spanishCaption: "Plano", englishImagePrompt: "Flat plane surface",
            category: .geometry
        ),
        "tetraedro": ConceptEntry(
            preset: nil, primitive: .pyramid, defaultMode: .object3d,
            defaultColor: .green, defaultAnimation: .rotateSlow,
            spanishCaption: "Tetraedro", englishImagePrompt: "Tetrahedron shape",
            category: .geometry
        ),
        "octaedro": ConceptEntry(
            preset: nil, primitive: .sphere, defaultMode: .object3d,
            defaultColor: .purple, defaultAnimation: .rotateSlow,
            spanishCaption: "Octaedro", englishImagePrompt: "Octahedron shape",
            category: .geometry
        ),

        // ── Astronomy (8) ─────────────────────────────────────────────

        "sistema solar": ConceptEntry(
            preset: .solarSystem, primitive: nil, defaultMode: .image,
            defaultColor: .yellow, defaultAnimation: .rotateSlow,
            spanishCaption: "Sistema Solar",
            englishImagePrompt: RenderPreset.solarSystem.englishImagePrompt,
            category: .astronomy
        ),
        "tierra": ConceptEntry(
            preset: .earth, primitive: nil, defaultMode: .object3d,
            defaultColor: .blue, defaultAnimation: .rotateSlow,
            spanishCaption: "Tierra",
            englishImagePrompt: RenderPreset.earth.englishImagePrompt,
            category: .astronomy
        ),
        "marte": ConceptEntry(
            preset: .mars, primitive: nil, defaultMode: .object3d,
            defaultColor: .red, defaultAnimation: .rotateSlow,
            spanishCaption: "Marte",
            englishImagePrompt: RenderPreset.mars.englishImagePrompt,
            category: .astronomy
        ),
        "saturno": ConceptEntry(
            preset: .saturn, primitive: nil, defaultMode: .object3d,
            defaultColor: .gold, defaultAnimation: .rotateSlow,
            spanishCaption: "Saturno",
            englishImagePrompt: RenderPreset.saturn.englishImagePrompt,
            category: .astronomy
        ),
        "jupiter": ConceptEntry(
            preset: .jupiter, primitive: nil, defaultMode: .object3d,
            defaultColor: .orange, defaultAnimation: .rotateSlow,
            spanishCaption: "Júpiter",
            englishImagePrompt: RenderPreset.jupiter.englishImagePrompt,
            category: .astronomy
        ),
        "luna": ConceptEntry(
            preset: .moon, primitive: nil, defaultMode: .object3d,
            defaultColor: .gray, defaultAnimation: .rotateSlow,
            spanishCaption: "Luna",
            englishImagePrompt: RenderPreset.moon.englishImagePrompt,
            category: .astronomy
        ),
        "sol": ConceptEntry(
            preset: .sun, primitive: nil, defaultMode: .object3d,
            defaultColor: .yellow, defaultAnimation: .pulse,
            spanishCaption: "Sol",
            englishImagePrompt: RenderPreset.sun.englishImagePrompt,
            category: .astronomy
        ),
        "estrella": ConceptEntry(
            preset: .star, primitive: nil, defaultMode: .object3d,
            defaultColor: .yellow, defaultAnimation: .pulse,
            spanishCaption: "Estrella",
            englishImagePrompt: RenderPreset.star.englishImagePrompt,
            category: .astronomy
        ),
        "telescopio": ConceptEntry(
            preset: .telescope, primitive: nil, defaultMode: .object3d,
            defaultColor: .black, defaultAnimation: .rotateSlow,
            spanishCaption: "Telescopio",
            englishImagePrompt: RenderPreset.telescope.englishImagePrompt,
            category: .astronomy
        ),
        "agujero negro": ConceptEntry(
            preset: .blackHole, primitive: nil, defaultMode: .object3d,
            defaultColor: .black, defaultAnimation: .pulse,
            spanishCaption: "Agujero Negro",
            englishImagePrompt: RenderPreset.blackHole.englishImagePrompt,
            category: .astronomy
        ),
        "cohete": ConceptEntry(
            preset: .rocket, primitive: nil, defaultMode: .object3d,
            defaultColor: .white, defaultAnimation: .bounce,
            spanishCaption: "Cohete Espacial",
            englishImagePrompt: RenderPreset.rocket.englishImagePrompt,
            category: .astronomy
        ),

        // ── Biology (10) ──────────────────────────────────────────────

        "atomo": ConceptEntry(
            preset: .atom, primitive: nil, defaultMode: .object3d,
            defaultColor: .blue, defaultAnimation: .rotateSlow,
            spanishCaption: "Átomo",
            englishImagePrompt: RenderPreset.atom.englishImagePrompt,
            category: .biology
        ),
        "molecula": ConceptEntry(
            preset: .molecule, primitive: nil, defaultMode: .object3d,
            defaultColor: .cyan, defaultAnimation: .rotateSlow,
            spanishCaption: "Molécula",
            englishImagePrompt: RenderPreset.molecule.englishImagePrompt,
            category: .biology
        ),
        "agua": ConceptEntry(
            preset: .waterMolecule, primitive: nil, defaultMode: .object3d,
            defaultColor: .cyan, defaultAnimation: .rotateSlow,
            spanishCaption: "Molécula de agua",
            englishImagePrompt: RenderPreset.waterMolecule.englishImagePrompt,
            category: .chemistry
        ),
        "celula": ConceptEntry(
            preset: .cell, primitive: nil, defaultMode: .image,
            defaultColor: .green, defaultAnimation: .rotateSlow,
            spanishCaption: "Célula",
            englishImagePrompt: RenderPreset.cell.englishImagePrompt,
            category: .biology
        ),
        "adn": ConceptEntry(
            preset: .dna, primitive: nil, defaultMode: .object3d,
            defaultColor: .purple, defaultAnimation: .rotateSlow,
            spanishCaption: "ADN",
            englishImagePrompt: RenderPreset.dna.englishImagePrompt,
            category: .biology
        ),
        "flor": ConceptEntry(
            preset: .flower, primitive: nil, defaultMode: .image,
            defaultColor: .red, defaultAnimation: .none,
            spanishCaption: "Flor",
            englishImagePrompt: RenderPreset.flower.englishImagePrompt,
            category: .biology
        ),
        "arbol": ConceptEntry(
            preset: .tree, primitive: nil, defaultMode: .image,
            defaultColor: .green, defaultAnimation: .none,
            spanishCaption: "Árbol",
            englishImagePrompt: RenderPreset.tree.englishImagePrompt,
            category: .biology
        ),
        "hoja": ConceptEntry(
            preset: .leaf, primitive: nil, defaultMode: .image,
            defaultColor: .green, defaultAnimation: .none,
            spanishCaption: "Hoja",
            englishImagePrompt: RenderPreset.leaf.englishImagePrompt,
            category: .biology
        ),
        "fotosintesis": ConceptEntry(
            preset: .leaf, primitive: nil, defaultMode: .image,
            defaultColor: .green, defaultAnimation: .none,
            spanishCaption: "Fotosíntesis",
            englishImagePrompt: "Photosynthesis process diagram sunlight plant",
            category: .biology
        ),
        "ecosistema": ConceptEntry(
            preset: nil, primitive: .sphere, defaultMode: .image,
            defaultColor: .green, defaultAnimation: .none,
            spanishCaption: "Ecosistema",
            englishImagePrompt: "Simple ecosystem diagram food chain",
            category: .biology
        ),
        "microscopio": ConceptEntry(
            preset: .microscope, primitive: nil, defaultMode: .object3d,
            defaultColor: .silver, defaultAnimation: .none,
            spanishCaption: "Microscopio",
            englishImagePrompt: RenderPreset.microscope.englishImagePrompt,
            category: .biology
        ),
        "fosil": ConceptEntry(
            preset: .fossil, primitive: nil, defaultMode: .object3d,
            defaultColor: .brown, defaultAnimation: .rotateSlow,
            spanishCaption: "Fósil",
            englishImagePrompt: RenderPreset.fossil.englishImagePrompt,
            category: .biology
        ),

        // ── Anatomy (4) ──────────────────────────────────────────────

        "corazon": ConceptEntry(
            preset: .heart, primitive: nil, defaultMode: .image,
            defaultColor: .red, defaultAnimation: .pulse,
            spanishCaption: "Corazón",
            englishImagePrompt: RenderPreset.heart.englishImagePrompt,
            category: .anatomy
        ),
        "pulmon": ConceptEntry(
            preset: .lung, primitive: nil, defaultMode: .image,
            defaultColor: .pink, defaultAnimation: .pulse,
            spanishCaption: "Pulmón",
            englishImagePrompt: RenderPreset.lung.englishImagePrompt,
            category: .anatomy
        ),
        "ojo": ConceptEntry(
            preset: .eye, primitive: nil, defaultMode: .image,
            defaultColor: .blue, defaultAnimation: .none,
            spanishCaption: "Ojo",
            englishImagePrompt: RenderPreset.eye.englishImagePrompt,
            category: .anatomy
        ),
        "cerebro": ConceptEntry(
            preset: .brain, primitive: nil, defaultMode: .image,
            defaultColor: .pink, defaultAnimation: .none,
            spanishCaption: "Cerebro",
            englishImagePrompt: RenderPreset.brain.englishImagePrompt,
            category: .anatomy
        ),

        // ── Geography (3) ─────────────────────────────────────────────

        "volcan": ConceptEntry(
            preset: .volcano, primitive: nil, defaultMode: .object3d,
            defaultColor: .red, defaultAnimation: .pulse,
            spanishCaption: "Volcán",
            englishImagePrompt: RenderPreset.volcano.englishImagePrompt,
            category: .geography
        ),
        "montana": ConceptEntry(
            preset: .mountain, primitive: nil, defaultMode: .object3d,
            defaultColor: .gray, defaultAnimation: .none,
            spanishCaption: "Montaña",
            englishImagePrompt: RenderPreset.mountain.englishImagePrompt,
            category: .geography
        ),
        "rio": ConceptEntry(
            preset: nil, primitive: .cylinder, defaultMode: .image,
            defaultColor: .blue, defaultAnimation: .none,
            spanishCaption: "Río",
            englishImagePrompt: "River flowing through landscape educational",
            category: .geography
        ),
        "brujula": ConceptEntry(
            preset: .compass, primitive: nil, defaultMode: .object3d,
            defaultColor: .gold, defaultAnimation: .none,
            spanishCaption: "Brújula",
            englishImagePrompt: RenderPreset.compass.englishImagePrompt,
            category: .geography
        ),

        // ── Physics (4) ──────────────────────────────────────────────

        "pendulo": ConceptEntry(
            preset: .pendulum, primitive: nil, defaultMode: .object3d,
            defaultColor: .gray, defaultAnimation: .bounce,
            spanishCaption: "Péndulo",
            englishImagePrompt: RenderPreset.pendulum.englishImagePrompt,
            category: .physics
        ),
        "iman": ConceptEntry(
            preset: .magnet, primitive: nil, defaultMode: .object3d,
            defaultColor: .red, defaultAnimation: .rotateSlow,
            spanishCaption: "Imán",
            englishImagePrompt: RenderPreset.magnet.englishImagePrompt,
            category: .physics
        ),
        "onda": ConceptEntry(
            preset: .wave, primitive: nil, defaultMode: .object3d,
            defaultColor: .blue, defaultAnimation: .bounce,
            spanishCaption: "Onda",
            englishImagePrompt: RenderPreset.wave.englishImagePrompt,
            category: .physics
        ),
        "circuito": ConceptEntry(
            preset: nil, primitive: .cube, defaultMode: .image,
            defaultColor: .green, defaultAnimation: .none,
            spanishCaption: "Circuito",
            englishImagePrompt: "Simple electrical circuit diagram with battery and bulb",
            category: .physics
        ),
        "prisma": ConceptEntry(
            preset: .prism, primitive: nil, defaultMode: .object3d,
            defaultColor: .white, defaultAnimation: .rotateSlow,
            spanishCaption: "Prisma",
            englishImagePrompt: RenderPreset.prism.englishImagePrompt,
            category: .physics
        ),
        "bateria": ConceptEntry(
            preset: .battery, primitive: nil, defaultMode: .object3d,
            defaultColor: .green, defaultAnimation: .rotateSlow,
            spanishCaption: "Batería",
            englishImagePrompt: RenderPreset.battery.englishImagePrompt,
            category: .physics
        ),

        // ── Chemistry (4) ─────────────────────────────────────────────

        "cristal": ConceptEntry(
            preset: .crystal, primitive: nil, defaultMode: .object3d,
            defaultColor: .cyan, defaultAnimation: .rotateSlow,
            spanishCaption: "Cristal",
            englishImagePrompt: RenderPreset.crystal.englishImagePrompt,
            category: .chemistry
        ),
        "enlace": ConceptEntry(
            preset: .chemicalBond, primitive: nil, defaultMode: .image,
            defaultColor: .blue, defaultAnimation: .none,
            spanishCaption: "Enlace químico",
            englishImagePrompt: RenderPreset.chemicalBond.englishImagePrompt,
            category: .chemistry
        ),
        "tabla periodica": ConceptEntry(
            preset: nil, primitive: .plane, defaultMode: .image,
            defaultColor: .blue, defaultAnimation: .none,
            spanishCaption: "Tabla periódica",
            englishImagePrompt: "Periodic table of elements simple educational",
            category: .chemistry
        ),
        "reaccion quimica": ConceptEntry(
            preset: nil, primitive: .sphere, defaultMode: .image,
            defaultColor: .orange, defaultAnimation: .none,
            spanishCaption: "Reacción química",
            englishImagePrompt: "Chemical reaction diagram with molecules",
            category: .chemistry
        ),

        // ── Additional educational concepts (7) ──────────────────────

        "dinosaurio": ConceptEntry(
            preset: nil, primitive: .capsule, defaultMode: .image,
            defaultColor: .green, defaultAnimation: .none,
            spanishCaption: "Dinosaurio",
            englishImagePrompt: "Dinosaur educational illustration T-Rex",
            category: .biology
        ),
        "esqueleto": ConceptEntry(
            preset: nil, primitive: .capsule, defaultMode: .image,
            defaultColor: .white, defaultAnimation: .none,
            spanishCaption: "Esqueleto",
            englishImagePrompt: "Human skeleton anatomy educational",
            category: .anatomy
        ),
        "bacteria": ConceptEntry(
            preset: nil, primitive: .sphere, defaultMode: .image,
            defaultColor: .green, defaultAnimation: .rotateSlow,
            spanishCaption: "Bacteria",
            englishImagePrompt: "Bacteria cell structure microscopic view",
            category: .biology
        ),
        "virus": ConceptEntry(
            preset: nil, primitive: .sphere, defaultMode: .image,
            defaultColor: .purple, defaultAnimation: .rotateSlow,
            spanishCaption: "Virus",
            englishImagePrompt: "Virus structure educational illustration",
            category: .biology
        ),
        "tornado": ConceptEntry(
            preset: nil, primitive: .cone, defaultMode: .image,
            defaultColor: .gray, defaultAnimation: .rotateSlow,
            spanishCaption: "Tornado",
            englishImagePrompt: "Tornado funnel cloud formation diagram",
            category: .geography
        ),
        "arcoiris": ConceptEntry(
            preset: nil, primitive: .torus, defaultMode: .image,
            defaultColor: .red, defaultAnimation: .none,
            spanishCaption: "Arcoíris",
            englishImagePrompt: "Rainbow light spectrum prism educational",
            category: .physics
        ),
        "reloj": ConceptEntry(
            preset: nil, primitive: .cylinder, defaultMode: .object3d,
            defaultColor: .gold, defaultAnimation: .rotateSlow,
            spanishCaption: "Reloj",
            englishImagePrompt: "Clock mechanism gears educational",
            category: .physics
        ),
    ]
}
