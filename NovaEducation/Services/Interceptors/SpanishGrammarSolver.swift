import Foundation

// MARK: - SpanishGrammarSolver
// Deterministic Spanish grammar interceptor: verb conjugation (regular + 30 irregular),
// orthographic rules. "App decide, LLM ensena" — the solver computes conjugation tables
// and grammar rules BEFORE the LLM, which then only explains pedagogically.

struct SpanishGrammarSolver: SubjectInterceptor, Sendable {

    let interceptorId = "spanish_grammar_solver"
    let supportedSubjects: Set<Subject> = [.language, .open]

    // MARK: - Tense & Person Definitions

    enum Tense: String, CaseIterable, Sendable {
        case presente
        case preterito
        case imperfecto
        case futuro
        case condicional
        case subjuntivo_presente
        case subjuntivo_imperfecto
        case imperativo

        var displayName: String {
            switch self {
            case .presente: return "Presente"
            case .preterito: return "Preterito Indefinido"
            case .imperfecto: return "Imperfecto"
            case .futuro: return "Futuro"
            case .condicional: return "Condicional"
            case .subjuntivo_presente: return "Subjuntivo Presente"
            case .subjuntivo_imperfecto: return "Subjuntivo Imperfecto"
            case .imperativo: return "Imperativo"
            }
        }
    }

    static let persons: [String] = [
        "yo", "tu", "el/ella", "nosotros", "ustedes", "ellos/ellas"
    ]

    // MARK: - Detection

    func detect(_ text: String, subject: Subject) -> Bool {
        let normalized = normalize(text)

        // Conjugation keywords
        let hasConjugationVerb = Self.conjugationKeywords.contains { normalized.contains($0) }

        // Tense names
        let hasTenseName = Self.tenseKeywords.contains { normalized.contains($0) }

        // Infinitive pattern after conjugation keyword
        let hasInfinitiveAfterKeyword = hasConjugationVerb && Self.infinitivePattern
            .firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)) != nil

        // Orthographic keywords
        let hasOrthoKeyword = Self.orthographicKeywords.contains { normalized.contains($0) }

        // Letter-pair rules
        let hasLetterPair = Self.letterPairKeywords.contains { normalized.contains($0) }

        return hasInfinitiveAfterKeyword
            || (hasConjugationVerb && hasTenseName)
            || hasOrthoKeyword
            || hasLetterPair
    }

    // MARK: - Solve

    func solve(_ text: String, subject: Subject) async -> InterceptorResult {
        let normalized = normalize(text)

        // 1. Conjugation request
        if let result = solveConjugation(normalized) {
            return result
        }

        // 2. Orthographic rule
        if let result = solveOrthographicRule(normalized) {
            return result
        }

        return .passthrough(text)
    }

    // MARK: - Conjugation Engine

    private func solveConjugation(_ text: String) -> InterceptorResult? {
        // Extract the infinitive verb
        guard let infinitive = extractInfinitive(text) else { return nil }

        // Determine the requested tense (default to presente)
        let tense = extractTense(text) ?? .presente

        // Conjugate
        let (forms, isIrregular) = conjugate(infinitive: infinitive, tense: tense)
        guard !forms.isEmpty else { return nil }

        // Build JSON attachment
        let personsJSON = zip(Self.persons, forms).map { person, form in
            "{\"person\":\"\(person)\",\"form\":\"\(form)\"}"
        }.joined(separator: ",")

        let attachmentData = "{\"verb\":\"\(infinitive)\",\"tense\":\"\(tense.displayName)\",\"persons\":[\(personsJSON)]}"

        // Build readable answer
        let tableLines = zip(Self.persons, forms).map { "\($0): \($1)" }.joined(separator: ", ")
        let answer = "\(infinitive) (\(tense.displayName)): \(tableLines)"

        let confidence: Double = isIrregular ? 1.0 : 0.9

        return InterceptorResult(
            answer: answer,
            teacherInstruction: "[RESULTADO: tabla de conjugacion de \(infinitive) en \(tense.displayName)] Explica las terminaciones y cualquier irregularidad.",
            category: isIrregular ? .catalogHit : .computed,
            attachmentType: "conjugation_table",
            attachmentData: attachmentData,
            confidence: confidence
        )
    }

    private func extractInfinitive(_ text: String) -> String? {
        // First check if any known irregular verb appears in the text
        for verb in Self.irregularVerbs.keys {
            if text.contains(verb) {
                return verb
            }
        }

        // Then try to find a word ending in -ar, -er, -ir
        let words = text.split(separator: " ").map { String($0) }
        for word in words {
            if word.hasSuffix("ar") || word.hasSuffix("er") || word.hasSuffix("ir") {
                // Skip words that are detection keywords themselves
                if Self.conjugationKeywords.contains(word) { continue }
                if Self.tenseKeywords.contains(word) { continue }
                if word.count < 3 { continue }
                // Skip common non-verb words
                if Self.nonVerbWords.contains(word) { continue }
                return word
            }
        }

        return nil
    }

    private func extractTense(_ text: String) -> Tense? {
        if text.contains("subjuntivo") && text.contains("imperfecto") {
            return .subjuntivo_imperfecto
        }
        if text.contains("subjuntivo") && text.contains("presente") {
            return .subjuntivo_presente
        }
        if text.contains("subjuntivo") {
            return .subjuntivo_presente
        }
        if text.contains("imperativo") {
            return .imperativo
        }
        if text.contains("preterito") || text.contains("pasado") || text.contains("indefinido") {
            return .preterito
        }
        if text.contains("imperfecto") {
            return .imperfecto
        }
        if text.contains("futuro") {
            return .futuro
        }
        if text.contains("condicional") {
            return .condicional
        }
        if text.contains("presente") {
            return .presente
        }
        return nil
    }

    /// Returns (conjugated forms for 6 persons, isIrregular)
    private func conjugate(infinitive: String, tense: Tense) -> ([String], Bool) {
        // Check irregular verbs first
        if let irregularTenses = Self.irregularVerbs[infinitive],
           let forms = irregularTenses[tense] {
            return (forms, true)
        }

        // Regular conjugation by verb ending
        guard let forms = conjugateRegular(infinitive: infinitive, tense: tense) else {
            return ([], false)
        }
        return (forms, false)
    }

    private func conjugateRegular(infinitive: String, tense: Tense) -> [String]? {
        let stem: String
        let ending: VerbEnding

        if infinitive.hasSuffix("ar") {
            stem = String(infinitive.dropLast(2))
            ending = .ar
        } else if infinitive.hasSuffix("er") {
            stem = String(infinitive.dropLast(2))
            ending = .er
        } else if infinitive.hasSuffix("ir") {
            stem = String(infinitive.dropLast(2))
            ending = .ir
        } else {
            return nil
        }

        let suffixes: [String]

        switch (ending, tense) {
        // -AR verbs
        case (.ar, .presente):
            suffixes = ["o", "as", "a", "amos", "an", "an"]
        case (.ar, .preterito):
            suffixes = ["e", "aste", "o", "amos", "aron", "aron"]
        case (.ar, .imperfecto):
            suffixes = ["aba", "abas", "aba", "abamos", "aban", "aban"]
        case (.ar, .subjuntivo_presente):
            suffixes = ["e", "es", "e", "emos", "en", "en"]
        case (.ar, .subjuntivo_imperfecto):
            suffixes = ["ara", "aras", "ara", "aramos", "aran", "aran"]
        case (.ar, .imperativo):
            suffixes = ["-", "a", "e", "emos", "en", "en"]

        // -ER verbs
        case (.er, .presente):
            suffixes = ["o", "es", "e", "emos", "en", "en"]
        case (.er, .preterito):
            suffixes = ["i", "iste", "io", "imos", "ieron", "ieron"]
        case (.er, .imperfecto):
            suffixes = ["ia", "ias", "ia", "iamos", "ian", "ian"]
        case (.er, .subjuntivo_presente):
            suffixes = ["a", "as", "a", "amos", "an", "an"]
        case (.er, .subjuntivo_imperfecto):
            suffixes = ["iera", "ieras", "iera", "ieramos", "ieran", "ieran"]
        case (.er, .imperativo):
            suffixes = ["-", "e", "a", "amos", "an", "an"]

        // -IR verbs
        case (.ir, .presente):
            suffixes = ["o", "es", "e", "imos", "en", "en"]
        case (.ir, .preterito):
            suffixes = ["i", "iste", "io", "imos", "ieron", "ieron"]
        case (.ir, .imperfecto):
            suffixes = ["ia", "ias", "ia", "iamos", "ian", "ian"]
        case (.ir, .subjuntivo_presente):
            suffixes = ["a", "as", "a", "amos", "an", "an"]
        case (.ir, .subjuntivo_imperfecto):
            suffixes = ["iera", "ieras", "iera", "ieramos", "ieran", "ieran"]
        case (.ir, .imperativo):
            suffixes = ["-", "e", "a", "amos", "an", "an"]

        // Futuro and condicional are formed from the full infinitive
        case (_, .futuro):
            return [
                infinitive + "e",
                infinitive + "as",
                infinitive + "a",
                infinitive + "emos",
                infinitive + "an",
                infinitive + "an"
            ]
        case (_, .condicional):
            return [
                infinitive + "ia",
                infinitive + "ias",
                infinitive + "ia",
                infinitive + "iamos",
                infinitive + "ian",
                infinitive + "ian"
            ]
        }

        return suffixes.map { suffix in
            if suffix == "-" { return "-" }
            return stem + suffix
        }
    }

    private enum VerbEnding {
        case ar, er, ir
    }

    // MARK: - Orthographic Rules

    private func solveOrthographicRule(_ text: String) -> InterceptorResult? {
        // Check letter-pair rules first (most specific)
        if text.contains("b o v") || text.contains("b y v")
            || text.contains("uso de b") || text.contains("uso de v")
            || (text.contains("se escribe con b") || text.contains("se escribe con v")) {
            return buildOrthographicResult(rule: Self.orthographicRules[0])
        }

        if text.contains("g o j") || text.contains("g y j")
            || text.contains("uso de g") || text.contains("uso de j") {
            return buildOrthographicResult(rule: Self.orthographicRules[1])
        }

        if text.contains("uso de h") || text.contains("cuando se usa h")
            || text.contains("la h") {
            return buildOrthographicResult(rule: Self.orthographicRules[2])
        }

        if text.contains("acentuacion") || text.contains("acento")
            || text.contains("agudas") || text.contains("graves") || text.contains("esdrujulas")
            || text.contains("regla de acentuacion") || text.contains("reglas de acentuacion") {
            return buildOrthographicResult(rule: Self.orthographicRules[3])
        }

        if text.contains("mayusculas") || text.contains("uso de mayusculas")
            || text.contains("cuando se usa mayuscula") {
            return buildOrthographicResult(rule: Self.orthographicRules[4])
        }

        if text.contains("signos de puntuacion") || text.contains("puntuacion")
            || text.contains("coma") || text.contains("punto y coma") {
            return buildOrthographicResult(rule: Self.orthographicRules[5])
        }

        if text.contains("c o s o z") || text.contains("c s z")
            || text.contains("uso de c") || text.contains("uso de s") || text.contains("uso de z")
            || text.contains("se escribe con c o s") || text.contains("se escribe con s o z") {
            return buildOrthographicResult(rule: Self.orthographicRules[6])
        }

        if text.contains("ll o y") || text.contains("ll y y")
            || text.contains("uso de ll") || text.contains("uso de y")
            || text.contains("yeismo") {
            return buildOrthographicResult(rule: Self.orthographicRules[7])
        }

        if text.contains("r o rr") || text.contains("r y rr")
            || text.contains("uso de rr") || text.contains("doble r") {
            return buildOrthographicResult(rule: Self.orthographicRules[8])
        }

        if text.contains("m antes de b") || text.contains("m antes de p")
            || text.contains("uso de m") || text.contains("m antes de b y p") {
            return buildOrthographicResult(rule: Self.orthographicRules[9])
        }

        if text.contains("diptongo") || text.contains("hiato")
            || text.contains("diptongos") || text.contains("hiatos") {
            return buildOrthographicResult(rule: Self.orthographicRules[10])
        }

        if text.contains("tilde diacritica") || text.contains("si o si")
            || text.contains("el o el") || text.contains("tu o tu")
            || text.contains("tilde en monosilabos") {
            return buildOrthographicResult(rule: Self.orthographicRules[11])
        }

        if text.contains("homofonas") || text.contains("homofona")
            || text.contains("palabras que suenan igual") {
            return buildOrthographicResult(rule: Self.orthographicRules[12])
        }

        if text.contains("prefijo") || text.contains("sufijo")
            || text.contains("prefijos") || text.contains("sufijos") {
            return buildOrthographicResult(rule: Self.orthographicRules[13])
        }

        if text.contains("signos de exclamacion") || text.contains("signos de interrogacion")
            || text.contains("exclamacion e interrogacion")
            || text.contains("signos de admiracion") {
            return buildOrthographicResult(rule: Self.orthographicRules[14])
        }

        // Generic orthography request - return the B/V rule as overview + mention others
        if text.contains("ortografia") || text.contains("regla de") || text.contains("reglas de ortografia") {
            // Try to match a specific rule by scanning rule names
            for rule in Self.orthographicRules {
                let ruleNorm = normalize(rule.ruleName)
                if text.contains(ruleNorm) {
                    return buildOrthographicResult(rule: rule)
                }
            }
            // Default: return acentuacion as the most commonly asked
            return buildOrthographicResult(rule: Self.orthographicRules[3])
        }

        return nil
    }

    private func buildOrthographicResult(rule: OrthographicRule) -> InterceptorResult {
        let examplesJSON = rule.examples.map { "\"\($0)\"" }.joined(separator: ",")
        let attachmentData = "{\"ruleId\":\"\(rule.id)\",\"ruleName\":\"\(rule.ruleName)\",\"description\":\"\(escapeJSON(rule.description))\",\"examples\":[\(examplesJSON)]}"

        let answer = "\(rule.ruleName): \(rule.description)"

        return InterceptorResult(
            answer: answer,
            teacherInstruction: "[RESULTADO: regla de \(rule.ruleName)] Explica la regla con mas ejemplos.",
            category: .grammarRule,
            attachmentType: "grammar_rule",
            attachmentData: attachmentData,
            confidence: 1.0
        )
    }

    // MARK: - Helpers

    private func normalize(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func escapeJSON(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    // MARK: - Detection Keywords

    private static let conjugationKeywords: [String] = [
        "conjuga", "conjugar", "conjugacion", "conjugame",
        "conjugaciones", "conjugue", "conjugando",
    ]

    private static let tenseKeywords: [String] = [
        "presente", "preterito", "pasado", "imperfecto",
        "futuro", "condicional", "subjuntivo", "imperativo",
        "indefinido",
    ]

    private static let orthographicKeywords: [String] = [
        "cuando se usa", "regla de", "reglas de",
        "ortografia", "se escribe con",
        "acentuacion", "tilde",
    ]

    private static let letterPairKeywords: [String] = [
        "b o v", "g o j", "c o s o z", "ll o y", "r o rr",
        "b y v", "g y j", "c s z", "ll y y", "r y rr",
    ]

    private static let infinitivePattern: NSRegularExpression = {
        // Matches words ending in -ar, -er, -ir (Spanish infinitives)
        try! NSRegularExpression(pattern: #"\b\w{2,}(?:ar|er|ir)\b"#)
    }()

    /// Common Spanish words ending in -ar/-er/-ir that are NOT verbs
    private static let nonVerbWords: Set<String> = [
        "par", "bar", "mar", "hogar", "lugar", "collar", "pilar",
        "mujer", "ayer", "ver", "poder", "ser", "placer",
        "ir", "sir", "elixir",
    ]

    // MARK: - Orthographic Rules Catalog

    struct OrthographicRule: Sendable {
        let id: String
        let ruleName: String
        let description: String
        let examples: [String]
    }

    static let orthographicRules: [OrthographicRule] = [
        // 0 - B/V
        OrthographicRule(
            id: "bv",
            ruleName: "Uso de B y V",
            description: "Se escribe B antes de consonante (br, bl), despues de m (cambio, tambien), en verbos terminados en -bir (escribir, recibir, excepto hervir, servir, vivir), en terminaciones -aba del preterito imperfecto (cantaba, jugaba), y en prefijos bi-, bis-, biz- (bicolor, bisabuelo). Se escribe V despues de n (enviar, invierno), en adjetivos terminados en -ivo/-iva (activo, positiva), despues de ol- (olvidar, volver) y en prefijos vice- (vicepresidente).",
            examples: [
                "escribir (b antes de consonante r)",
                "cambio (b despues de m)",
                "cantaba (terminacion -aba)",
                "enviar (v despues de n)",
                "activo (terminacion -ivo)",
            ]
        ),
        // 1 - G/J
        OrthographicRule(
            id: "gj",
            ruleName: "Uso de G y J",
            description: "Se escribe G ante e, i en palabras que contienen gen (gente, origen, excepto jengibre), en verbos terminados en -ger, -gir (proteger, dirigir, excepto tejer, crujir), y en terminaciones -gia, -gio, -gion (magia, region). Se escribe J ante e, i en palabras terminadas en -aje, -eje (viaje, equipaje), en preteritos de verbos irregulares con sonido j (dije de decir, traje de traer), y en terminaciones -jero, -jeria (cajero, relojeria).",
            examples: [
                "gente (gen)",
                "proteger (verbo en -ger)",
                "viaje (terminacion -aje)",
                "dije (preterito de decir)",
                "cajero (terminacion -jero)",
            ]
        ),
        // 2 - H
        OrthographicRule(
            id: "h",
            ruleName: "Uso de H",
            description: "Se escribe H al inicio de palabras que empiezan con hie-, hue- (hielo, huevo), en prefijos hiper-, hipo-, hidro- (hipermercado, hipotesis, hidraulico), en palabras que comienzan con hum- seguido de vocal (humano, humedad), en formas del verbo haber (he, has, ha, hay), y en interjecciones (oh, ah, eh). La H es muda en espanol y no se pronuncia.",
            examples: [
                "hielo (hie-)",
                "huevo (hue-)",
                "hipotesis (hipo-)",
                "humano (hum- + vocal)",
                "hay (verbo haber)",
            ]
        ),
        // 3 - Acentuacion
        OrthographicRule(
            id: "acentuacion",
            ruleName: "Acentuacion",
            description: "Las palabras agudas llevan tilde cuando terminan en n, s o vocal (cafe, corazon, compas). Las palabras graves o llanas llevan tilde cuando NO terminan en n, s o vocal (arbol, dificil, lapiz). Las palabras esdrujulas SIEMPRE llevan tilde (musica, pajaro, matematicas). Las palabras sobresdrujulas SIEMPRE llevan tilde (digamelo, rapidamente).",
            examples: [
                "cafe (aguda terminada en vocal)",
                "corazon (aguda terminada en n)",
                "arbol (grave no terminada en n, s, vocal)",
                "musica (esdrujula, siempre tilde)",
                "digamelo (sobresdrujula, siempre tilde)",
            ]
        ),
        // 4 - Mayusculas
        OrthographicRule(
            id: "mayusculas",
            ruleName: "Uso de mayusculas",
            description: "Se escribe con mayuscula la primera palabra de una oracion y despues de punto, los nombres propios de personas, lugares y organizaciones (Maria, Mexico, ONU), los titulos de obras (El Quijote), las siglas (UNESCO, OMS), los nombres de festividades (Navidad, Semana Santa), y al inicio de cartas o documentos formales (Estimado Sr.).",
            examples: [
                "Maria fue a Mexico. (nombres propios)",
                "La ONU se reunio. (siglas)",
                "Feliz Navidad. (festividades)",
                "Estimado Sr. Director: (cartas formales)",
                "El Quijote es una obra maestra. (titulo de obra)",
            ]
        ),
        // 5 - Puntuacion
        OrthographicRule(
            id: "puntuacion",
            ruleName: "Signos de puntuacion",
            description: "El punto (.) cierra oraciones y se usa en abreviaturas. La coma (,) separa elementos de una enumeracion, marca incisos explicativos y se usa despues de conectores (sin embargo, ademas). El punto y coma (;) separa oraciones relacionadas y elementos complejos en enumeraciones. Los dos puntos (:) preceden enumeraciones, citas y explicaciones. Los puntos suspensivos (...) indican omision o suspenso.",
            examples: [
                "Compro manzanas, peras y uvas. (coma en enumeracion)",
                "Mi hermano, que vive en Madrid, llego ayer. (coma en inciso)",
                "Llueve mucho; no saldremos. (punto y coma)",
                "Necesitas: lapiz, cuaderno y goma. (dos puntos)",
                "No se si ir... (puntos suspensivos)",
            ]
        ),
        // 6 - C/S/Z
        OrthographicRule(
            id: "csz",
            ruleName: "Uso de C, S y Z",
            description: "Se escribe C ante e, i (cena, cine) y en terminaciones -cion cuando la palabra base tiene t (cancion de canto, atencion de atento). Se escribe S en terminaciones -sion cuando la palabra base tiene s (expresion de expreso, confusion de confuso), en adjetivos terminados en -oso/-osa (hermoso, preciosa) y en superlativos -isimo (bellisimo). Se escribe Z ante a, o, u (zapato, zona, azucar), en terminaciones -ez, -eza (vejez, belleza) y en aumentativos -azo (golpazo).",
            examples: [
                "cancion (de canto, terminacion -cion)",
                "expresion (de expreso, terminacion -sion)",
                "hermoso (adjetivo en -oso)",
                "zapato (z ante a)",
                "belleza (terminacion -eza)",
            ]
        ),
        // 7 - LL/Y
        OrthographicRule(
            id: "lly",
            ruleName: "Uso de LL y Y",
            description: "Se escribe LL en palabras con diminutivos -illo/-illa (anillo, silla), en verbos terminados en -allar, -ellar, -illar, -ullar, -ullir (callar, sellar, bullir), y en sustantivos terminados en -alla, -ella, -ello (batalla, estrella). Se escribe Y al final de palabras terminadas en diptongo (ley, rey, hoy, muy), como conjuncion copulativa (pan y agua), en formas del verbo ir (voy, fui), y en verbos cuyo infinitivo no tiene ll ni y (cayendo de caer, leyendo de leer).",
            examples: [
                "anillo (diminutivo -illo)",
                "callar (verbo en -allar)",
                "ley (diptongo final con y)",
                "pan y agua (conjuncion y)",
                "leyendo (gerundio de leer)",
            ]
        ),
        // 8 - R/RR
        OrthographicRule(
            id: "rrr",
            ruleName: "Uso de R y RR",
            description: "Se escribe R simple al inicio de palabra con sonido fuerte (rojo, rata), despues de l, n, s con sonido fuerte (alrededor, enriquecer, Israel), y entre vocales con sonido suave (cara, pero). Se escribe RR (doble r) SOLO entre vocales para representar el sonido fuerte (perro, carro, tierra). Nunca se escribe rr al inicio de palabra ni despues de consonante.",
            examples: [
                "rojo (r inicial, sonido fuerte)",
                "perro (rr entre vocales, sonido fuerte)",
                "pero (r simple entre vocales, sonido suave)",
                "alrededor (r despues de l, sonido fuerte)",
                "carro (rr entre vocales, sonido fuerte)",
            ]
        ),
        // 9 - M antes de B/P
        OrthographicRule(
            id: "mbp",
            ruleName: "M antes de B y P",
            description: "Siempre se escribe M antes de B y P (nunca N). Esta es una regla sin excepciones en espanol. Antes de V se escribe N (nunca M). Ejemplos: campo (m+p), hombre (m+b), enviar (n+v), invierno (n+v). Es una de las reglas mas consistentes del espanol.",
            examples: [
                "campo (m antes de p)",
                "hombre (m antes de b)",
                "tambien (m antes de b)",
                "siempre (m antes de p)",
                "enviar (n antes de v, nunca m)",
            ]
        ),
        // 10 - Diptongos e hiatos
        OrthographicRule(
            id: "diptongo_hiato",
            ruleName: "Diptongos e hiatos",
            description: "Un diptongo es la union de dos vocales en una misma silaba: vocal abierta (a,e,o) + vocal cerrada atona (i,u), o dos vocales cerradas distintas (ui, iu). Ejemplos: cielo (ie), causa (au), ciudad (iu). Un hiato es la separacion de dos vocales en silabas distintas: dos vocales abiertas (ae, eo, oa), o vocal cerrada tonica + vocal abierta (dia, rio). La tilde en hiatos con vocal cerrada rompe el diptongo: dia (di-a), rio (ri-o).",
            examples: [
                "cielo (diptongo ie)",
                "causa (diptongo au)",
                "dia (hiato, tilde rompe diptongo)",
                "poeta (hiato oe, dos vocales abiertas)",
                "rio (hiato, tilde en vocal cerrada)",
            ]
        ),
        // 11 - Tilde diacritica
        OrthographicRule(
            id: "tilde_diacritica",
            ruleName: "Tilde diacritica",
            description: "La tilde diacritica distingue palabras que se escriben igual pero tienen distinto significado y funcion. Principales pares: el (articulo) / el (pronombre), tu (posesivo) / tu (pronombre personal), mi (posesivo) / mi (pronombre personal), si (conjuncion) / si (afirmacion/pronombre), de (preposicion) / de (verbo dar), se (pronombre) / se (verbo saber/ser), te (pronombre) / te (sustantivo, infusion), mas (conjuncion adversativa) / mas (adverbio de cantidad).",
            examples: [
                "el libro / el lo sabe (articulo vs pronombre)",
                "tu casa / tu decides (posesivo vs pronombre)",
                "si llueve / si, acepto (conjuncion vs afirmacion)",
                "de madera / de usted permiso (preposicion vs verbo)",
                "se fue / yo se la verdad (pronombre vs verbo saber)",
            ]
        ),
        // 12 - Homofonas
        OrthographicRule(
            id: "homofonas",
            ruleName: "Palabras homofonas",
            description: "Las palabras homofonas suenan igual pero se escriben diferente y tienen distinto significado. Principales pares: haber (verbo) / a ver (preposicion + verbo), hecho (participio de hacer) / echo (verbo echar), hay (verbo haber) / ahi (adverbio de lugar) / ay (interjeccion), vaya (verbo ir) / valla (cerca) / baya (fruto), hola (saludo) / ola (del mar), hora (tiempo) / ora (conjuncion/verbo orar).",
            examples: [
                "haber / a ver (puede haber errores / vamos a ver)",
                "hecho / echo (he hecho la tarea / te echo de menos)",
                "hay / ahi / ay (hay comida / ahi esta / ay, me duele)",
                "hola / ola (hola, amigo / la ola del mar)",
                "vaya / valla / baya (vaya al parque / salta la valla / una baya roja)",
            ]
        ),
        // 13 - Prefijos y sufijos
        OrthographicRule(
            id: "prefijos_sufijos",
            ruleName: "Prefijos y sufijos",
            description: "Los prefijos se unen directamente a la palabra sin guion: anti- (antivirus), des- (deshacer), in-/im- (imposible, increible), pre- (predecir), re- (rehacer), sub- (submarino), super- (supermercado). Se usa guion cuando preceden a siglas o numeros (anti-COVID, sub-21). Los sufijos comunes incluyen: -cion/-sion (accion, expresion), -mente (rapidamente), -ista (futbolista), -ble (amable), -dad/-tad (verdad, libertad), -oso/-osa (hermoso).",
            examples: [
                "deshacer (prefijo des-)",
                "imposible (prefijo im- ante p)",
                "rapidamente (sufijo -mente)",
                "futbolista (sufijo -ista)",
                "anti-COVID (prefijo + sigla, con guion)",
            ]
        ),
        // 14 - Signos de exclamacion e interrogacion
        OrthographicRule(
            id: "excl_interr",
            ruleName: "Signos de exclamacion e interrogacion",
            description: "En espanol se usan signos de apertura y cierre tanto para exclamaciones como para interrogaciones. Los signos de apertura son obligatorios y no deben omitirse. Interrogacion: abrir con (?) y cerrar con (?). Exclamacion: abrir con (!) y cerrar con (!). Se pueden combinar (?) para preguntas exclamativas. Despues del signo de cierre NO se escribe punto. Se puede escribir coma o punto y coma despues del cierre.",
            examples: [
                "?Como te llamas? (interrogacion con apertura y cierre)",
                "!Que alegria! (exclamacion con apertura y cierre)",
                "?Vienes o no? No me has dicho. (sin punto tras cierre)",
                "!Increible!, dijo Maria. (coma despues del cierre)",
                "?!Que hiciste!? (combinacion interrogacion-exclamacion)",
            ]
        ),
    ]

    // MARK: - Irregular Verbs (30+)

    /// Dictionary: infinitive -> [tense -> [6 conjugated forms]]
    /// Forms order: yo, tu, el/ella, nosotros, ustedes, ellos/ellas
    static let irregularVerbs: [String: [Tense: [String]]] = [
        "ser": [
            .presente: ["soy", "eres", "es", "somos", "son", "son"],
            .preterito: ["fui", "fuiste", "fue", "fuimos", "fueron", "fueron"],
            .imperfecto: ["era", "eras", "era", "eramos", "eran", "eran"],
            .futuro: ["sere", "seras", "sera", "seremos", "seran", "seran"],
            .condicional: ["seria", "serias", "seria", "seriamos", "serian", "serian"],
            .subjuntivo_presente: ["sea", "seas", "sea", "seamos", "sean", "sean"],
            .subjuntivo_imperfecto: ["fuera", "fueras", "fuera", "fueramos", "fueran", "fueran"],
            .imperativo: ["-", "se", "sea", "seamos", "sean", "sean"],
        ],
        "estar": [
            .presente: ["estoy", "estas", "esta", "estamos", "estan", "estan"],
            .preterito: ["estuve", "estuviste", "estuvo", "estuvimos", "estuvieron", "estuvieron"],
            .imperfecto: ["estaba", "estabas", "estaba", "estabamos", "estaban", "estaban"],
            .futuro: ["estare", "estaras", "estara", "estaremos", "estaran", "estaran"],
            .condicional: ["estaria", "estarias", "estaria", "estariamos", "estarian", "estarian"],
            .subjuntivo_presente: ["este", "estes", "este", "estemos", "esten", "esten"],
            .subjuntivo_imperfecto: ["estuviera", "estuvieras", "estuviera", "estuvieramos", "estuvieran", "estuvieran"],
            .imperativo: ["-", "esta", "este", "estemos", "esten", "esten"],
        ],
        "ir": [
            .presente: ["voy", "vas", "va", "vamos", "van", "van"],
            .preterito: ["fui", "fuiste", "fue", "fuimos", "fueron", "fueron"],
            .imperfecto: ["iba", "ibas", "iba", "ibamos", "iban", "iban"],
            .futuro: ["ire", "iras", "ira", "iremos", "iran", "iran"],
            .condicional: ["iria", "irias", "iria", "iriamos", "irian", "irian"],
            .subjuntivo_presente: ["vaya", "vayas", "vaya", "vayamos", "vayan", "vayan"],
            .subjuntivo_imperfecto: ["fuera", "fueras", "fuera", "fueramos", "fueran", "fueran"],
            .imperativo: ["-", "ve", "vaya", "vayamos", "vayan", "vayan"],
        ],
        "haber": [
            .presente: ["he", "has", "ha", "hemos", "han", "han"],
            .preterito: ["hube", "hubiste", "hubo", "hubimos", "hubieron", "hubieron"],
            .imperfecto: ["habia", "habias", "habia", "habiamos", "habian", "habian"],
            .futuro: ["habre", "habras", "habra", "habremos", "habran", "habran"],
            .condicional: ["habria", "habrias", "habria", "habriamos", "habrian", "habrian"],
            .subjuntivo_presente: ["haya", "hayas", "haya", "hayamos", "hayan", "hayan"],
            .subjuntivo_imperfecto: ["hubiera", "hubieras", "hubiera", "hubieramos", "hubieran", "hubieran"],
            .imperativo: ["-", "he", "haya", "hayamos", "hayan", "hayan"],
        ],
        "tener": [
            .presente: ["tengo", "tienes", "tiene", "tenemos", "tienen", "tienen"],
            .preterito: ["tuve", "tuviste", "tuvo", "tuvimos", "tuvieron", "tuvieron"],
            .imperfecto: ["tenia", "tenias", "tenia", "teniamos", "tenian", "tenian"],
            .futuro: ["tendre", "tendras", "tendra", "tendremos", "tendran", "tendran"],
            .condicional: ["tendria", "tendrias", "tendria", "tendriamos", "tendrian", "tendrian"],
            .subjuntivo_presente: ["tenga", "tengas", "tenga", "tengamos", "tengan", "tengan"],
            .subjuntivo_imperfecto: ["tuviera", "tuvieras", "tuviera", "tuvieramos", "tuvieran", "tuvieran"],
            .imperativo: ["-", "ten", "tenga", "tengamos", "tengan", "tengan"],
        ],
        "poder": [
            .presente: ["puedo", "puedes", "puede", "podemos", "pueden", "pueden"],
            .preterito: ["pude", "pudiste", "pudo", "pudimos", "pudieron", "pudieron"],
            .imperfecto: ["podia", "podias", "podia", "podiamos", "podian", "podian"],
            .futuro: ["podre", "podras", "podra", "podremos", "podran", "podran"],
            .condicional: ["podria", "podrias", "podria", "podriamos", "podrian", "podrian"],
            .subjuntivo_presente: ["pueda", "puedas", "pueda", "podamos", "puedan", "puedan"],
            .subjuntivo_imperfecto: ["pudiera", "pudieras", "pudiera", "pudieramos", "pudieran", "pudieran"],
            .imperativo: ["-", "puede", "pueda", "podamos", "puedan", "puedan"],
        ],
        "querer": [
            .presente: ["quiero", "quieres", "quiere", "queremos", "quieren", "quieren"],
            .preterito: ["quise", "quisiste", "quiso", "quisimos", "quisieron", "quisieron"],
            .imperfecto: ["queria", "querias", "queria", "queriamos", "querian", "querian"],
            .futuro: ["querre", "querras", "querra", "querremos", "querran", "querran"],
            .condicional: ["querria", "querrias", "querria", "querriamos", "querrian", "querrian"],
            .subjuntivo_presente: ["quiera", "quieras", "quiera", "queramos", "quieran", "quieran"],
            .subjuntivo_imperfecto: ["quisiera", "quisieras", "quisiera", "quisieramos", "quisieran", "quisieran"],
            .imperativo: ["-", "quiere", "quiera", "queramos", "quieran", "quieran"],
        ],
        "hacer": [
            .presente: ["hago", "haces", "hace", "hacemos", "hacen", "hacen"],
            .preterito: ["hice", "hiciste", "hizo", "hicimos", "hicieron", "hicieron"],
            .imperfecto: ["hacia", "hacias", "hacia", "haciamos", "hacian", "hacian"],
            .futuro: ["hare", "haras", "hara", "haremos", "haran", "haran"],
            .condicional: ["haria", "harias", "haria", "hariamos", "harian", "harian"],
            .subjuntivo_presente: ["haga", "hagas", "haga", "hagamos", "hagan", "hagan"],
            .subjuntivo_imperfecto: ["hiciera", "hicieras", "hiciera", "hicieramos", "hicieran", "hicieran"],
            .imperativo: ["-", "haz", "haga", "hagamos", "hagan", "hagan"],
        ],
        "decir": [
            .presente: ["digo", "dices", "dice", "decimos", "dicen", "dicen"],
            .preterito: ["dije", "dijiste", "dijo", "dijimos", "dijeron", "dijeron"],
            .imperfecto: ["decia", "decias", "decia", "deciamos", "decian", "decian"],
            .futuro: ["dire", "diras", "dira", "diremos", "diran", "diran"],
            .condicional: ["diria", "dirias", "diria", "diriamos", "dirian", "dirian"],
            .subjuntivo_presente: ["diga", "digas", "diga", "digamos", "digan", "digan"],
            .subjuntivo_imperfecto: ["dijera", "dijeras", "dijera", "dijeramos", "dijeran", "dijeran"],
            .imperativo: ["-", "di", "diga", "digamos", "digan", "digan"],
        ],
        "venir": [
            .presente: ["vengo", "vienes", "viene", "venimos", "vienen", "vienen"],
            .preterito: ["vine", "viniste", "vino", "vinimos", "vinieron", "vinieron"],
            .imperfecto: ["venia", "venias", "venia", "veniamos", "venian", "venian"],
            .futuro: ["vendre", "vendras", "vendra", "vendremos", "vendran", "vendran"],
            .condicional: ["vendria", "vendrias", "vendria", "vendriamos", "vendrian", "vendrian"],
            .subjuntivo_presente: ["venga", "vengas", "venga", "vengamos", "vengan", "vengan"],
            .subjuntivo_imperfecto: ["viniera", "vinieras", "viniera", "vinieramos", "vinieran", "vinieran"],
            .imperativo: ["-", "ven", "venga", "vengamos", "vengan", "vengan"],
        ],
        "poner": [
            .presente: ["pongo", "pones", "pone", "ponemos", "ponen", "ponen"],
            .preterito: ["puse", "pusiste", "puso", "pusimos", "pusieron", "pusieron"],
            .imperfecto: ["ponia", "ponias", "ponia", "poniamos", "ponian", "ponian"],
            .futuro: ["pondre", "pondras", "pondra", "pondremos", "pondran", "pondran"],
            .condicional: ["pondria", "pondrias", "pondria", "pondriamos", "pondrian", "pondrian"],
            .subjuntivo_presente: ["ponga", "pongas", "ponga", "pongamos", "pongan", "pongan"],
            .subjuntivo_imperfecto: ["pusiera", "pusieras", "pusiera", "pusieramos", "pusieran", "pusieran"],
            .imperativo: ["-", "pon", "ponga", "pongamos", "pongan", "pongan"],
        ],
        "saber": [
            .presente: ["se", "sabes", "sabe", "sabemos", "saben", "saben"],
            .preterito: ["supe", "supiste", "supo", "supimos", "supieron", "supieron"],
            .imperfecto: ["sabia", "sabias", "sabia", "sabiamos", "sabian", "sabian"],
            .futuro: ["sabre", "sabras", "sabra", "sabremos", "sabran", "sabran"],
            .condicional: ["sabria", "sabrias", "sabria", "sabriamos", "sabrian", "sabrian"],
            .subjuntivo_presente: ["sepa", "sepas", "sepa", "sepamos", "sepan", "sepan"],
            .subjuntivo_imperfecto: ["supiera", "supieras", "supiera", "supieramos", "supieran", "supieran"],
            .imperativo: ["-", "sabe", "sepa", "sepamos", "sepan", "sepan"],
        ],
        "salir": [
            .presente: ["salgo", "sales", "sale", "salimos", "salen", "salen"],
            .preterito: ["sali", "saliste", "salio", "salimos", "salieron", "salieron"],
            .imperfecto: ["salia", "salias", "salia", "saliamos", "salian", "salian"],
            .futuro: ["saldre", "saldras", "saldra", "saldremos", "saldran", "saldran"],
            .condicional: ["saldria", "saldrias", "saldria", "saldriamos", "saldrian", "saldrian"],
            .subjuntivo_presente: ["salga", "salgas", "salga", "salgamos", "salgan", "salgan"],
            .subjuntivo_imperfecto: ["saliera", "salieras", "saliera", "salieramos", "salieran", "salieran"],
            .imperativo: ["-", "sal", "salga", "salgamos", "salgan", "salgan"],
        ],
        "dar": [
            .presente: ["doy", "das", "da", "damos", "dan", "dan"],
            .preterito: ["di", "diste", "dio", "dimos", "dieron", "dieron"],
            .imperfecto: ["daba", "dabas", "daba", "dabamos", "daban", "daban"],
            .futuro: ["dare", "daras", "dara", "daremos", "daran", "daran"],
            .condicional: ["daria", "darias", "daria", "dariamos", "darian", "darian"],
            .subjuntivo_presente: ["de", "des", "de", "demos", "den", "den"],
            .subjuntivo_imperfecto: ["diera", "dieras", "diera", "dieramos", "dieran", "dieran"],
            .imperativo: ["-", "da", "de", "demos", "den", "den"],
        ],
        "ver": [
            .presente: ["veo", "ves", "ve", "vemos", "ven", "ven"],
            .preterito: ["vi", "viste", "vio", "vimos", "vieron", "vieron"],
            .imperfecto: ["veia", "veias", "veia", "veiamos", "veian", "veian"],
            .futuro: ["vere", "veras", "vera", "veremos", "veran", "veran"],
            .condicional: ["veria", "verias", "veria", "veriamos", "verian", "verian"],
            .subjuntivo_presente: ["vea", "veas", "vea", "veamos", "vean", "vean"],
            .subjuntivo_imperfecto: ["viera", "vieras", "viera", "vieramos", "vieran", "vieran"],
            .imperativo: ["-", "ve", "vea", "veamos", "vean", "vean"],
        ],
        "traer": [
            .presente: ["traigo", "traes", "trae", "traemos", "traen", "traen"],
            .preterito: ["traje", "trajiste", "trajo", "trajimos", "trajeron", "trajeron"],
            .imperfecto: ["traia", "traias", "traia", "traiamos", "traian", "traian"],
            .futuro: ["traere", "traeras", "traera", "traeremos", "traeran", "traeran"],
            .condicional: ["traeria", "traerias", "traeria", "traeriamos", "traerian", "traerian"],
            .subjuntivo_presente: ["traiga", "traigas", "traiga", "traigamos", "traigan", "traigan"],
            .subjuntivo_imperfecto: ["trajera", "trajeras", "trajera", "trajeramos", "trajeran", "trajeran"],
            .imperativo: ["-", "trae", "traiga", "traigamos", "traigan", "traigan"],
        ],
        "oir": [
            .presente: ["oigo", "oyes", "oye", "oimos", "oyen", "oyen"],
            .preterito: ["oi", "oiste", "oyo", "oimos", "oyeron", "oyeron"],
            .imperfecto: ["oia", "oias", "oia", "oiamos", "oian", "oian"],
            .futuro: ["oire", "oiras", "oira", "oiremos", "oiran", "oiran"],
            .condicional: ["oiria", "oirias", "oiria", "oiriamos", "oirian", "oirian"],
            .subjuntivo_presente: ["oiga", "oigas", "oiga", "oigamos", "oigan", "oigan"],
            .subjuntivo_imperfecto: ["oyera", "oyeras", "oyera", "oyeramos", "oyeran", "oyeran"],
            .imperativo: ["-", "oye", "oiga", "oigamos", "oigan", "oigan"],
        ],
        "caer": [
            .presente: ["caigo", "caes", "cae", "caemos", "caen", "caen"],
            .preterito: ["cai", "caiste", "cayo", "caimos", "cayeron", "cayeron"],
            .imperfecto: ["caia", "caias", "caia", "caiamos", "caian", "caian"],
            .futuro: ["caere", "caeras", "caera", "caeremos", "caeran", "caeran"],
            .condicional: ["caeria", "caerias", "caeria", "caeriamos", "caerian", "caerian"],
            .subjuntivo_presente: ["caiga", "caigas", "caiga", "caigamos", "caigan", "caigan"],
            .subjuntivo_imperfecto: ["cayera", "cayeras", "cayera", "cayeramos", "cayeran", "cayeran"],
            .imperativo: ["-", "cae", "caiga", "caigamos", "caigan", "caigan"],
        ],
        "conocer": [
            .presente: ["conozco", "conoces", "conoce", "conocemos", "conocen", "conocen"],
            .preterito: ["conoci", "conociste", "conocio", "conocimos", "conocieron", "conocieron"],
            .imperfecto: ["conocia", "conocias", "conocia", "conociamos", "conocian", "conocian"],
            .futuro: ["conocere", "conoceras", "conocera", "conoceremos", "conoceran", "conoceran"],
            .condicional: ["conoceria", "conocerias", "conoceria", "conoceriamos", "conocerian", "conocerian"],
            .subjuntivo_presente: ["conozca", "conozcas", "conozca", "conozcamos", "conozcan", "conozcan"],
            .subjuntivo_imperfecto: ["conociera", "conocieras", "conociera", "conocieramos", "conocieran", "conocieran"],
            .imperativo: ["-", "conoce", "conozca", "conozcamos", "conozcan", "conozcan"],
        ],
        "dormir": [
            .presente: ["duermo", "duermes", "duerme", "dormimos", "duermen", "duermen"],
            .preterito: ["dormi", "dormiste", "durmio", "dormimos", "durmieron", "durmieron"],
            .imperfecto: ["dormia", "dormias", "dormia", "dormiamos", "dormian", "dormian"],
            .futuro: ["dormire", "dormiras", "dormira", "dormiremos", "dormiran", "dormiran"],
            .condicional: ["dormiria", "dormirias", "dormiria", "dormiriamos", "dormirian", "dormirian"],
            .subjuntivo_presente: ["duerma", "duermas", "duerma", "durmamos", "duerman", "duerman"],
            .subjuntivo_imperfecto: ["durmiera", "durmieras", "durmiera", "durmieramos", "durmieran", "durmieran"],
            .imperativo: ["-", "duerme", "duerma", "durmamos", "duerman", "duerman"],
        ],
        "pedir": [
            .presente: ["pido", "pides", "pide", "pedimos", "piden", "piden"],
            .preterito: ["pedi", "pediste", "pidio", "pedimos", "pidieron", "pidieron"],
            .imperfecto: ["pedia", "pedias", "pedia", "pediamos", "pedian", "pedian"],
            .futuro: ["pedire", "pediras", "pedira", "pediremos", "pediran", "pediran"],
            .condicional: ["pediria", "pedirias", "pediria", "pediriamos", "pedirian", "pedirian"],
            .subjuntivo_presente: ["pida", "pidas", "pida", "pidamos", "pidan", "pidan"],
            .subjuntivo_imperfecto: ["pidiera", "pidieras", "pidiera", "pidieramos", "pidieran", "pidieran"],
            .imperativo: ["-", "pide", "pida", "pidamos", "pidan", "pidan"],
        ],
        "sentir": [
            .presente: ["siento", "sientes", "siente", "sentimos", "sienten", "sienten"],
            .preterito: ["senti", "sentiste", "sintio", "sentimos", "sintieron", "sintieron"],
            .imperfecto: ["sentia", "sentias", "sentia", "sentiamos", "sentian", "sentian"],
            .futuro: ["sentire", "sentiras", "sentira", "sentiremos", "sentiran", "sentiran"],
            .condicional: ["sentiria", "sentirias", "sentiria", "sentiriamos", "sentirian", "sentirian"],
            .subjuntivo_presente: ["sienta", "sientas", "sienta", "sintamos", "sientan", "sientan"],
            .subjuntivo_imperfecto: ["sintiera", "sintieras", "sintiera", "sintieramos", "sintieran", "sintieran"],
            .imperativo: ["-", "siente", "sienta", "sintamos", "sientan", "sientan"],
        ],
        "jugar": [
            .presente: ["juego", "juegas", "juega", "jugamos", "juegan", "juegan"],
            .preterito: ["jugue", "jugaste", "jugo", "jugamos", "jugaron", "jugaron"],
            .imperfecto: ["jugaba", "jugabas", "jugaba", "jugabamos", "jugaban", "jugaban"],
            .futuro: ["jugare", "jugaras", "jugara", "jugaremos", "jugaran", "jugaran"],
            .condicional: ["jugaria", "jugarias", "jugaria", "jugariamos", "jugarian", "jugarian"],
            .subjuntivo_presente: ["juegue", "juegues", "juegue", "juguemos", "jueguen", "jueguen"],
            .subjuntivo_imperfecto: ["jugara", "jugaras", "jugara", "jugaramos", "jugaran", "jugaran"],
            .imperativo: ["-", "juega", "juegue", "juguemos", "jueguen", "jueguen"],
        ],
        "pensar": [
            .presente: ["pienso", "piensas", "piensa", "pensamos", "piensan", "piensan"],
            .preterito: ["pense", "pensaste", "penso", "pensamos", "pensaron", "pensaron"],
            .imperfecto: ["pensaba", "pensabas", "pensaba", "pensabamos", "pensaban", "pensaban"],
            .futuro: ["pensare", "pensaras", "pensara", "pensaremos", "pensaran", "pensaran"],
            .condicional: ["pensaria", "pensarias", "pensaria", "pensariamos", "pensarian", "pensarian"],
            .subjuntivo_presente: ["piense", "pienses", "piense", "pensemos", "piensen", "piensen"],
            .subjuntivo_imperfecto: ["pensara", "pensaras", "pensara", "pensaramos", "pensaran", "pensaran"],
            .imperativo: ["-", "piensa", "piense", "pensemos", "piensen", "piensen"],
        ],
        "volver": [
            .presente: ["vuelvo", "vuelves", "vuelve", "volvemos", "vuelven", "vuelven"],
            .preterito: ["volvi", "volviste", "volvio", "volvimos", "volvieron", "volvieron"],
            .imperfecto: ["volvia", "volvias", "volvia", "volviamos", "volvian", "volvian"],
            .futuro: ["volvere", "volveras", "volvera", "volveremos", "volveran", "volveran"],
            .condicional: ["volveria", "volverias", "volveria", "volveriamos", "volverian", "volverian"],
            .subjuntivo_presente: ["vuelva", "vuelvas", "vuelva", "volvamos", "vuelvan", "vuelvan"],
            .subjuntivo_imperfecto: ["volviera", "volvieras", "volviera", "volvieramos", "volvieran", "volvieran"],
            .imperativo: ["-", "vuelve", "vuelva", "volvamos", "vuelvan", "vuelvan"],
        ],
        "morir": [
            .presente: ["muero", "mueres", "muere", "morimos", "mueren", "mueren"],
            .preterito: ["mori", "moriste", "murio", "morimos", "murieron", "murieron"],
            .imperfecto: ["moria", "morias", "moria", "moriamos", "morian", "morian"],
            .futuro: ["morire", "moriras", "morira", "moriremos", "moriran", "moriran"],
            .condicional: ["moriria", "moririas", "moriria", "moririamos", "moririan", "moririan"],
            .subjuntivo_presente: ["muera", "mueras", "muera", "muramos", "mueran", "mueran"],
            .subjuntivo_imperfecto: ["muriera", "murieras", "muriera", "murieramos", "murieran", "murieran"],
            .imperativo: ["-", "muere", "muera", "muramos", "mueran", "mueran"],
        ],
        "seguir": [
            .presente: ["sigo", "sigues", "sigue", "seguimos", "siguen", "siguen"],
            .preterito: ["segui", "seguiste", "siguio", "seguimos", "siguieron", "siguieron"],
            .imperfecto: ["seguia", "seguias", "seguia", "seguiamos", "seguian", "seguian"],
            .futuro: ["seguire", "seguiras", "seguira", "seguiremos", "seguiran", "seguiran"],
            .condicional: ["seguiria", "seguirias", "seguiria", "seguiriamos", "seguirian", "seguirian"],
            .subjuntivo_presente: ["siga", "sigas", "siga", "sigamos", "sigan", "sigan"],
            .subjuntivo_imperfecto: ["siguiera", "siguieras", "siguiera", "siguieramos", "siguieran", "siguieran"],
            .imperativo: ["-", "sigue", "siga", "sigamos", "sigan", "sigan"],
        ],
        "llegar": [
            .presente: ["llego", "llegas", "llega", "llegamos", "llegan", "llegan"],
            .preterito: ["llegue", "llegaste", "llego", "llegamos", "llegaron", "llegaron"],
            .imperfecto: ["llegaba", "llegabas", "llegaba", "llegabamos", "llegaban", "llegaban"],
            .futuro: ["llegare", "llegaras", "llegara", "llegaremos", "llegaran", "llegaran"],
            .condicional: ["llegaria", "llegarias", "llegaria", "llegariamos", "llegarian", "llegarian"],
            .subjuntivo_presente: ["llegue", "llegues", "llegue", "lleguemos", "lleguen", "lleguen"],
            .subjuntivo_imperfecto: ["llegara", "llegaras", "llegara", "llegaramos", "llegaran", "llegaran"],
            .imperativo: ["-", "llega", "llegue", "lleguemos", "lleguen", "lleguen"],
        ],
        "caber": [
            .presente: ["quepo", "cabes", "cabe", "cabemos", "caben", "caben"],
            .preterito: ["cupe", "cupiste", "cupo", "cupimos", "cupieron", "cupieron"],
            .imperfecto: ["cabia", "cabias", "cabia", "cabiamos", "cabian", "cabian"],
            .futuro: ["cabre", "cabras", "cabra", "cabremos", "cabran", "cabran"],
            .condicional: ["cabria", "cabrias", "cabria", "cabriamos", "cabrian", "cabrian"],
            .subjuntivo_presente: ["quepa", "quepas", "quepa", "quepamos", "quepan", "quepan"],
            .subjuntivo_imperfecto: ["cupiera", "cupieras", "cupiera", "cupieramos", "cupieran", "cupieran"],
            .imperativo: ["-", "cabe", "quepa", "quepamos", "quepan", "quepan"],
        ],
        "valer": [
            .presente: ["valgo", "vales", "vale", "valemos", "valen", "valen"],
            .preterito: ["vali", "valiste", "valio", "valimos", "valieron", "valieron"],
            .imperfecto: ["valia", "valias", "valia", "valiamos", "valian", "valian"],
            .futuro: ["valdre", "valdras", "valdra", "valdremos", "valdran", "valdran"],
            .condicional: ["valdria", "valdrias", "valdria", "valdriamos", "valdrian", "valdrian"],
            .subjuntivo_presente: ["valga", "valgas", "valga", "valgamos", "valgan", "valgan"],
            .subjuntivo_imperfecto: ["valiera", "valieras", "valiera", "valieramos", "valieran", "valieran"],
            .imperativo: ["-", "vale", "valga", "valgamos", "valgan", "valgan"],
        ],
    ]
}
