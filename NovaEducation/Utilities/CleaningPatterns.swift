import Foundation

/// Regex patterns for cleaning up LLM responses before they reach the UI or TTS.
/// Handles removal of markdown artifacts, images, and tool handling logs.
struct CleaningPatterns {
    nonisolated(unsafe) static let patterns: [Regex<AnyRegexOutput>] = {
        let rawPatterns = [
            "!\\[.*?\\]\\(.*?\\)",                          // Markdown images
            "\\[GeneramosEducationalImage.*?\\]",           // Leaked tool calls
            "\\[.*?(Image|Imagen|Generating).*?\\]",        // Image placeholders
            // Removed: "\\*\\*\\*.*?\\*\\*\\*" stripped valid bold-italic Markdown and AI content
            "(?i)INSTRUCCIONES INTERNAS",                   // Internal instructions
            "(?i)NO MOSTRAR AL USUARIO",                    // Hidden text
            "(?i)RESPUESTA GENERADA POR IA",               // AI response marker
            "\\[Tool:.*?\\]",                               // Tool call artifacts
            "\\[Calling.*?\\]",                             // Calling artifacts
            "\\[(Thinking|Generating|Analyzing|Tools|Error).*?\\]" // Catch-all for thinking tags
        ]
        return rawPatterns.compactMap { try? Regex($0) }
    }()
}
