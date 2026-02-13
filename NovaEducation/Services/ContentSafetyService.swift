import SwiftUI
import RegexBuilder

enum SafetyCheckResult {
    case safe
    case unsafe(reason: String)
}

struct ContentSafetyService {
    
    // MARK: - API
    
    static func validate(_ input: String) -> SafetyCheckResult {
        // 1. Check for PII (Personally Identifiable Information)
        if hasPII(input) {
            return .unsafe(reason: "Por seguridad, no compartas información personal como teléfonos o correos.")
        }
        
        // 2. Check for Harmful Content (Keywords/Patterns)
        if hasHarmfulContent(input) {
            return .unsafe(reason: "Lo siento, no puedo responder a eso. Mi propósito es ser un asistente educativo seguro y positivo.")
        }
        
        // 3. Check for Jailbreak/Injection attempts
        if isJailbreakAttempt(input) {
            return .unsafe(reason: "No puedo ignorar mis instrucciones de seguridad.")
        }
        
        return .safe
    }
    
    // MARK: - Private Logic
    
    private static func hasPII(_ input: String) -> Bool {
        // Email detection
        let emailPattern = Regex {
            OneOrMore(.word)
            "@"
            OneOrMore(.word)
            "."
            OneOrMore(.word)
        }
        
        if input.contains(emailPattern) { return true }
        
        // Phone detection (iOS 26 Standard)
        // Uses Optionally to avoid 'Optional' ambiguity in DSL
        let phonePattern = Regex {
            Optionally { "+" }
            OneOrMore(.digit)
            OneOrMore {
                ChoiceOf {
                    .digit
                    "-"
                    " "
                    "("
                    ")"
                }
            }
        }
        
        // Check matches with threshold to avoid false positives (e.g. math)
        let matches = input.matches(of: phonePattern)
        for match in matches {
            let content = String(input[match.range])
            let digitCount = content.filter { $0.isNumber }.count
            
            // Standard: Phones usually have 7+ digits (e.g. 555-0199)
            // Timestamps might trigger this, but we prefer safety in Phase 1.
            if digitCount >= 7 {
                return true
            }
        }
        
        return false
    }
    
    private static func hasHarmfulContent(_ input: String) -> Bool {
        let blocklist = [
            "matar", "suicidio", "droga", "bomba", "terrorismo", "porn", "sexo", "odio", "racista", "nazi",
            "kill", "suicide", "drug", "bomb", "terrorism", "sex", "hate", "racist"
        ]
        
        let lowercased = input.lowercased()
        for word in blocklist {
            if lowercased.contains(word) {
                return true
            }
        }
        return false
    }
    
    private static func isJailbreakAttempt(_ input: String) -> Bool {
        let patterns = [
            "ignora tus instrucciones", "ignore your instructions",
            "actua como", "act as",
            "olvida todo", "forget everything",
            "dan", "jailbreak"
        ]
        
        let lowercased = input.lowercased()
        for pattern in patterns {
            if lowercased.contains(pattern) {
                return true
            }
        }
        return false
    }
}
