import SwiftUI
import RegexBuilder

enum SafetyCheckResult {
    case safe
    case unsafe(reason: String)
}

struct ContentSafetyService {

    // MARK: - Cached Regex Patterns (compiled once)

    private static let emailPattern = Regex {
        OneOrMore(.word)
        "@"
        OneOrMore(.word)
        "."
        OneOrMore(.word)
    }

    private static let phoneRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"\+?\d{1,3}?[- .]?\(?\d{2,4}\)?[- .]?\d{3,4}[- .]?\d{3,4}"#,
            options: []
        )
    }()

    private static let wholeWordBlocklist = [
        "matar", "suicidio", "bomba", "terrorismo", "porn", "odio", "racista", "nazi",
        "kill", "suicide", "bomb", "terrorism", "hate", "racist"
    ]

    private static let blocklistRegexes: [NSRegularExpression] = {
        wholeWordBlocklist.compactMap { word in
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
            return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        }
    }()

    private static let jailbreakPatterns = [
        "ignora tus instrucciones", "ignore your instructions",
        "olvida todo", "forget everything",
        "olvida tus instrucciones", "forget your instructions",
        "ignora las reglas", "ignore the rules",
        "no tienes restricciones", "you have no restrictions",
        "jailbreak", "prompt injection"
    ]

    // MARK: - API

    static func validate(_ input: String) -> SafetyCheckResult {
        if hasPII(input) {
            return .unsafe(reason: "Por seguridad, no compartas información personal como teléfonos o correos.")
        }

        if hasHarmfulContent(input) {
            return .unsafe(reason: "Lo siento, no puedo responder a eso. Mi propósito es ser un asistente educativo seguro y positivo.")
        }

        if isJailbreakAttempt(input) {
            return .unsafe(reason: "No puedo ignorar mis instrucciones de seguridad.")
        }

        return .safe
    }

    // MARK: - Private Logic

    private static func hasPII(_ input: String) -> Bool {
        if input.contains(emailPattern) { return true }

        if let phoneRegex {
            let range = NSRange(input.startIndex..., in: input)
            let phoneMatches = phoneRegex.matches(in: input, range: range)
            for match in phoneMatches {
                if let swiftRange = Range(match.range, in: input) {
                    let content = String(input[swiftRange])
                    let digitCount = content.filter { $0.isNumber }.count
                    if digitCount >= 7 {
                        return true
                    }
                }
            }
        }

        return false
    }

    private static func hasHarmfulContent(_ input: String) -> Bool {
        let lowercased = input.lowercased()

        let range = NSRange(lowercased.startIndex..., in: lowercased)
        for regex in blocklistRegexes {
            if regex.firstMatch(in: lowercased, range: range) != nil {
                return true
            }
        }

        // "droga" - allow in scientific/pharmacology context
        if lowercased.contains("droga") {
            let scientificContext = ["farmacología", "farmacologia", "medicamento", "tratamiento", "medicina", "farmaco", "fármaco"]
            let isScientific = scientificContext.contains { lowercased.contains($0) }
            if !isScientific {
                return true
            }
        }

        // "sexo"/"sex" - allow in biological/educational context
        if lowercased.contains("sexo") || lowercased.contains("sex") {
            let educationalContext = [
                "biología", "biologia", "reproducción", "reproduccion", "cromosoma",
                "genética", "genetica", "célula", "celula", "especie",
                "sexual", "asexual", "dimorfismo", "género", "genero",
                "fecundación", "fecundacion", "gameto", "biology", "reproduction"
            ]
            let isEducational = educationalContext.contains { lowercased.contains($0) }
            if !isEducational {
                return true
            }
        }

        return false
    }

    private static func isJailbreakAttempt(_ input: String) -> Bool {
        let lowercased = input.lowercased()
        for pattern in jailbreakPatterns {
            if lowercased.contains(pattern) {
                return true
            }
        }
        return false
    }
}
