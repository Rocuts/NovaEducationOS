import SwiftUI

enum Subject: String, CaseIterable, Identifiable, Codable {
    case open = "abierta"
    case math = "matematicas"
    case physics = "fisica"
    case chemistry = "quimica"
    case science = "ciencias"
    case social = "sociales"
    case language = "lenguaje"
    case english = "ingles"
    case ethics = "etica"
    case technology = "tecnologia"
    case arts = "artes"
    case sports = "deportes"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .open: return "Chat Abierto"
        case .math: return "Matemáticas"
        case .physics: return "Física"
        case .chemistry: return "Química"
        case .science: return "Ciencias Naturales"
        case .social: return "Ciencias Sociales"
        case .language: return "Lenguaje"
        case .english: return "Inglés"
        case .ethics: return "Ética y Valores"
        case .technology: return "Tecnología"
        case .arts: return "Artes"
        case .sports: return "Deportes"
        }
    }

    var icon: String {
        switch self {
        case .open: return "bubble.left.and.bubble.right.fill"
        case .math: return "x.squareroot"
        case .physics: return "atom"
        case .chemistry: return "flask.fill"
        case .science: return "leaf.fill"
        case .social: return "globe.americas.fill"
        case .language: return "text.book.closed.fill"
        case .english: return "character.bubble.fill"
        case .ethics: return "heart.text.square.fill"
        case .technology: return "desktopcomputer"
        case .arts: return "paintbrush.pointed.fill"
        case .sports: return "figure.run"
        }
    }

    var color: Color {
        switch self {
        case .open: return .gray
        case .math: return .blue
        case .physics: return .cyan
        case .chemistry: return .orange
        case .science: return .green
        case .social: return .brown
        case .language: return .red
        case .english: return .purple
        case .ethics: return .yellow
        case .technology: return .indigo
        case .arts: return .pink
        case .sports: return .mint
        }
    }

    /// Returns true if this subject has a deterministic interceptor
    /// that handles computation/fact-lookup before the LLM
    var hasInterceptor: Bool {
        switch self {
        case .math, .physics, .chemistry, .language: return true
        default: return false
        }
    }

    /// Returns true if this subject should show a specialized keyboard
    var hasSpecialKeyboard: Bool {
        switch self {
        case .math, .physics, .chemistry:
            return true
        default:
            return false
        }
    }

    /// Indicates if this subject benefits from AI-generated educational images.
    /// Visual subjects (animals, geography, art) get image generation; abstract subjects (math, logic) do not.
    var supportsImages: Bool {
        switch self {
        case .open, .science, .social, .language, .english, .arts, .sports:
            return true
        case .math, .physics, .chemistry, .technology, .ethics:
            return false
        }
    }

    /// Returns the keyboard type for this subject
    var keyboardType: SubjectKeyboardType {
        switch self {
        case .math:
            return .math
        case .physics:
            return .physics
        case .chemistry:
            return .chemistry
        default:
            return .none
        }
    }
}

/// Enum to specify keyboard type for specialized subjects
enum SubjectKeyboardType {
    case none
    case math
    case physics
    case chemistry
}
