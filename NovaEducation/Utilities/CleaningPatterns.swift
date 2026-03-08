import Foundation

/// Regex patterns for cleaning up LLM responses before they reach the UI or TTS.
/// Handles removal of markdown artifacts, images, and tool handling logs.
///
/// Thread safety: `nonisolated(unsafe)` is acceptable here because:
/// 1. This is a `static let` — the array and its Regex values are immutable after initialization.
/// 2. Static let initialization is guaranteed to be thread-safe (dispatch_once semantics).
/// 3. `Regex<AnyRegexOutput>` is value-semantic and safe to share across threads once constructed.
/// The `nonisolated(unsafe)` annotation is only needed because `Regex` does not yet declare
/// `Sendable` conformance in Swift 6, despite being safe to use concurrently.
struct CleaningPatterns: Sendable {
    nonisolated(unsafe) static let patterns: [Regex<AnyRegexOutput>] = {
        let rawPatterns = [
            "!\\[.*?\\]\\(.*?\\)",                          // Markdown images
            "\\[GeneramosEducationalImage.*?\\]",           // Leaked tool calls
            "\\[.*?(Image|Imagen|Generating).*?\\]",        // Image placeholders
            "(?i)INSTRUCCIONES INTERNAS",                   // Internal instructions
            "(?i)NO MOSTRAR AL USUARIO",                    // Hidden text
            "(?i)RESPUESTA GENERADA POR IA",               // AI response marker
            "\\[Tool:.*?\\]",                               // Tool call artifacts
            "\\[Calling.*?\\]",                             // Calling artifacts
            "\\[(Thinking|Generating|Analyzing|Tools|Error).*?\\]", // Catch-all for thinking tags
            "(?i)no puedo generar imágenes[^.]*\\.",            // "No puedo generar imágenes..."
            "(?i)no tengo la capacidad de generar[^.]*\\.",     // "No tengo la capacidad de generar..."
            "(?i)como modelo de (lenguaje|ia|inteligencia)[^.]*\\.", // "Como modelo de lenguaje/IA..."
            "```\\w*\\n?",                                  // Opening code fences (```markdown, ```text, etc.)
            "```$",                                         // Closing code fences at end of line
            "^```\\s*$"                                     // Standalone closing code fences
        ]
        return rawPatterns.compactMap { try? Regex($0) }
    }()
}
