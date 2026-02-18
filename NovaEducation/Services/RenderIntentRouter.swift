import Foundation

// MARK: - RenderIntentRouter
// Deterministic detection of visual/render intents from Spanish user text.
// False negatives must be near-zero: better to over-detect than to miss a render request.
// The LLM does NOT decide whether to render — this router does.

enum RenderIntentRouter {

    // MARK: - Public API

    /// Detects whether the user text implies a visual render request.
    /// Returns a RouterResult with intent, detected mode, color, shape, and concept.
    static func detect(_ text: String) -> RouterResult {
        let normalized = normalize(text)
        let words = Set(normalized.split(separator: " ").map(String.init))

        // 1. Check for modification requests (references to previous render)
        let modification = detectModification(normalized, words: words)
        if modification.isModification {
            return modification
        }

        // 2. Detect render verb / visual request pattern
        let hasRenderVerb = renderVerbs.contains { normalized.contains($0) }
        let hasVisualPattern = visualPatterns.contains { normalized.contains($0) }
        let hasShowIntent = showIntentWords.contains { normalized.contains($0) }

        // 3. Detect known concept from catalog
        let hasConcept = ConceptCatalog.hasMatch(text)

        // 4. Detect geometric shape words
        let detectedPrimitive = detectPrimitive(normalized, words: words)
        let hasShape = detectedPrimitive != nil

        // 5. Detect color words
        let detectedColor = detectColor(normalized, words: words)

        // 6. Detect concept text (for LLM extraction fallback)
        let detectedConcept = extractConceptText(normalized)

        // 7. Determine if this is a render intent
        // Priority: explicit verb > visual pattern > shape + show intent > concept + show intent
        let isRender: Bool
        if hasRenderVerb || hasVisualPattern {
            isRender = true
        } else if hasShape && hasShowIntent {
            isRender = true
        } else if hasConcept && hasShowIntent {
            isRender = true
        } else if hasShape && detectedColor != nil {
            // "pirámide amarilla" without explicit verb — still a render intent
            isRender = true
        } else {
            isRender = false
        }

        guard isRender else { return .none }

        // 8. Determine render mode (2D vs 3D)
        let intent = determineIntent(normalized, words: words, hasShape: hasShape)

        return RouterResult(
            intent: intent,
            detectedColor: detectedColor,
            detectedPrimitive: detectedPrimitive,
            detectedConcept: detectedConcept,
            isModification: false,
            modificationSize: nil,
            modificationColor: nil
        )
    }

    // MARK: - Intent Mode Detection

    private static func determineIntent(
        _ normalized: String,
        words: Set<String>,
        hasShape: Bool
    ) -> RenderIntent {
        let has3D = indicators3D.contains { normalized.contains($0) }
        let has2D = indicators2D.contains { normalized.contains($0) }

        if has3D && !has2D { return .render3D }
        if has2D && !has3D { return .render2D }
        if has3D && has2D { return .render3D }   // 3D wins when ambiguous
        if hasShape { return .render3D }          // Geometric shapes default to 3D

        // Check concept catalog for default mode
        if let entry = ConceptCatalog.match(normalized) {
            return entry.defaultMode == .image ? .render2D : .render3D
        }

        return .ambiguousRender  // Defaults to 3D at execution
    }

    // MARK: - Modification Detection

    private static func detectModification(
        _ normalized: String,
        words: Set<String>
    ) -> RouterResult {
        // Size modifications
        let wantsBigger = sizeUpPatterns.contains { normalized.contains($0) }
        let wantsSmaller = sizeDownPatterns.contains { normalized.contains($0) }
        let sizeChange: RenderSize? = wantsBigger ? .large : (wantsSmaller ? .small : nil)

        // Color modifications
        var colorChange: RenderColor? = nil
        for pattern in colorChangePatterns {
            if normalized.contains(pattern) {
                colorChange = detectColor(normalized, words: words)
                break
            }
        }

        // Animation modifications
        let wantsRotate = rotatePatterns.contains { normalized.contains($0) }

        let isModification = sizeChange != nil || colorChange != nil || wantsRotate
        guard isModification else {
            return .none
        }

        return RouterResult(
            intent: .render3D,
            detectedColor: colorChange,
            detectedPrimitive: nil,
            detectedConcept: nil,
            isModification: true,
            modificationSize: sizeChange,
            modificationColor: colorChange
        )
    }

    // MARK: - Primitive Detection

    private static func detectPrimitive(
        _ normalized: String,
        words: Set<String>
    ) -> RenderPrimitive? {
        for (keywords, primitive) in primitiveMap {
            for keyword in keywords {
                if normalized.contains(keyword) { return primitive }
            }
        }
        return nil
    }

    // MARK: - Color Detection

    private static func detectColor(
        _ normalized: String,
        words: Set<String>
    ) -> RenderColor? {
        for (keywords, color) in colorMap {
            for keyword in keywords {
                if words.contains(keyword) || normalized.contains(keyword) {
                    return color
                }
            }
        }
        return nil
    }

    // MARK: - Concept Text Extraction

    /// Extracts the likely concept from the text (rough heuristic)
    private static func extractConceptText(_ normalized: String) -> String? {
        // Remove common prefixes to isolate the concept
        var concept = normalized
        for prefix in conceptPrefixes {
            if concept.hasPrefix(prefix) {
                concept = String(concept.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespaces)
                break
            }
            if let range = concept.range(of: prefix) {
                concept = String(concept[range.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                break
            }
        }

        // Remove articles
        for article in ["un ", "una ", "el ", "la ", "los ", "las ", "unos ", "unas "] {
            if concept.hasPrefix(article) {
                concept = String(concept.dropFirst(article.count))
            }
        }

        let trimmed = concept.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Normalization

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
            .replacingOccurrences(of: "¿", with: "")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "¡", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Word Lists

    /// Explicit render verbs — these alone trigger a render intent
    private static let renderVerbs: [String] = [
        // "show me"
        "muestrame", "muestreme", "muestra", "muestre", "mostrar",
        "ensename", "enseneme", "ensena", "ensene",
        // "draw me"
        "dibujame", "dibujeme", "dibuja", "dibuje", "dibujar",
        // "paint me"
        "pintame", "pinteme", "pinta", "pinte", "pintar",
        // "generate / create / render"
        "genera", "generar", "genera una imagen", "genera un modelo",
        "crea", "crear", "creame", "creeme",
        "renderiza", "renderizar",
        "visualiza", "visualizar",
        // "make / build"
        "haz", "hazme", "hacer",
        "construye", "construir", "construyeme",
    ]

    /// Visual request patterns — phrases that indicate visual intent
    private static let visualPatterns: [String] = [
        "quiero ver", "quiero verlo", "quiero verla",
        "dejame ver", "dejame verlo", "dejame verla",
        "puedo ver", "podria ver", "podrias mostrar",
        "dame una imagen", "dame un dibujo", "dame un modelo",
        "como se ve", "como luce", "como es",
        "necesito ver", "me gustaria ver",
        "pon una imagen", "pon un modelo",
        "genera imagen", "genera un objeto",
        "crear imagen", "crear modelo",
        "imagen de", "dibujo de", "modelo de",
        "en 3d", "en tres dimensiones",
        "objeto 3d", "modelo 3d", "figura 3d",
    ]

    /// Show intent words — weaker signal, needs concept/shape to trigger render
    private static let showIntentWords: [String] = [
        "muestram", "ensenam", "ver ", " ver", "mostrar", "ensena",
        "visualiz", "dibuj", "pint", "genera", "crea", "haz",
        "como se ve", "como luce", "quiero",
    ]

    /// 3D mode indicators
    private static let indicators3D: [String] = [
        "3d", "tres dimensiones", "tridimensional",
        "girar", "rotar", "mover", "interactiv",
        "modelo 3", "objeto 3", "figura 3",
        "que gire", "que rote", "que se mueva",
        "girarlo", "rotarlo", "moverlo",
    ]

    /// 2D mode indicators
    private static let indicators2D: [String] = [
        "imagen", "foto", "fotografia",
        "ilustracion", "dibujo", "pintura",
        "diagrama", "esquema", "grafico",
        "2d", "dos dimensiones", "plano",
        "lamina", "poster",
    ]

    /// Shape word → primitive mapping
    private static let primitiveMap: [([String], RenderPrimitive)] = [
        (["piramide", "piramides", "triangulo"], .pyramid),
        (["cubo", "cubos", "dado", "dados", "caja"], .cube),
        (["esfera", "esferas", "pelota", "bola", "globo", "circulo"], .sphere),
        (["cono", "conos"], .cone),
        (["cilindro", "cilindros", "tubo", "tubos"], .cylinder),
        (["toroide", "toro", "dona", "donas", "rosquilla", "aro"], .torus),
        (["capsula", "capsulas", "pastilla"], .capsule),
    ]

    /// Spanish color words → RenderColor mapping
    private static let colorMap: [([String], RenderColor)] = [
        (["rojo", "roja", "rojos", "rojas"], .red),
        (["azul", "azules"], .blue),
        (["verde", "verdes"], .green),
        (["amarillo", "amarilla", "amarillos", "amarillas"], .yellow),
        (["naranja", "naranjas", "anaranjado", "anaranjada"], .orange),
        (["morado", "morada", "morados", "moradas", "purpura", "violeta"], .purple),
        (["rosa", "rosado", "rosada", "rosados", "rosadas"], .pink),
        (["blanco", "blanca", "blancos", "blancas"], .white),
        (["negro", "negra", "negros", "negras"], .black),
        (["gris", "grises"], .gray),
        (["marron", "cafe", "cafes", "chocolate"], .brown),
        (["dorado", "dorada", "dorados", "doradas", "oro"], .gold),
        (["plateado", "plateada", "plateados", "plateadas", "plata"], .silver),
        (["cyan", "cian", "celeste", "turquesa"], .cyan),
    ]

    /// Size-up modification patterns
    private static let sizeUpPatterns: [String] = [
        "mas grande", "mas grande", "hazlo grande", "hazla grande",
        "agrandalo", "agrandala", "aumenta", "aumentalo",
        "mas grandote", "grandote", "enorme",
    ]

    /// Size-down modification patterns
    private static let sizeDownPatterns: [String] = [
        "mas pequeno", "mas pequena", "mas chico", "mas chica",
        "hazlo pequeno", "hazla pequena", "achicalo", "achicala",
        "reduce", "reducelo", "diminuto", "chiquito", "chiquita",
    ]

    /// Color-change modification patterns
    private static let colorChangePatterns: [String] = [
        "cambialo a ", "cambiala a ", "ponlo en ", "ponla en ",
        "cambiale el color", "de color ", "en color ",
        "hazlo ", "hazla ", "que sea ",
    ]

    /// Rotation modification patterns
    private static let rotatePatterns: [String] = [
        "giralo", "girala", "rotalo", "rotala",
        "que gire", "que rote", "hazlo girar",
        "quiero verlo girar", "quiero verla girar",
    ]

    /// Prefixes to strip when extracting concept text
    private static let conceptPrefixes: [String] = [
        "muestrame ", "muestreme ", "muestra ",
        "ensename ", "enseneme ", "ensena ",
        "dibujame ", "dibujeme ", "dibuja ",
        "pintame ", "pinteme ", "pinta ",
        "genera ", "crea ", "creame ",
        "hazme ", "haz ", "construye ",
        "renderiza ", "visualiza ",
        "quiero ver ", "dejame ver ",
        "dame una imagen de ", "dame un dibujo de ",
        "dame un modelo de ",
        "como se ve ", "como luce ",
        "necesito ver ", "me gustaria ver ",
    ]
}
