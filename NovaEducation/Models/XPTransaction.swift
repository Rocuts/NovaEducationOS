import SwiftData
import Foundation

/// Representa una transacción de XP ganado por el estudiante
@Model
final class XPTransaction {
    #Index<XPTransaction>([\.sourceRaw, \.timestamp], [\.timestamp])

    var id: UUID
    var amount: Int              // XP ganado (ya con multiplicador aplicado)
    var baseAmount: Int          // XP base antes de multiplicador
    var multiplier: Double       // Multiplicador que se aplicó
    var sourceRaw: String        // Almacenamiento para XPSource
    var subjectId: String?       // Materia relacionada (opcional)
    var timestamp: Date

    /// Origen del XP como enum tipado
    var source: XPSource {
        get { XPSource(rawValue: sourceRaw) ?? .message }
        set { sourceRaw = newValue.rawValue }
    }

    init(
        baseAmount: Int,
        multiplier: Double = 1.0,
        source: XPSource,
        subjectId: String? = nil
    ) {
        self.id = UUID()
        self.baseAmount = baseAmount
        self.multiplier = multiplier
        self.amount = Int(Double(baseAmount) * multiplier)
        self.sourceRaw = source.rawValue
        self.subjectId = subjectId
        self.timestamp = Date()
    }
}

/// Origen de los puntos de experiencia
enum XPSource: String, Codable, CaseIterable {
    case message = "message"                    // 5 XP base - enviar mensaje
    case quizCorrectEasy = "quiz_correct_easy"  // 10 XP - quiz fácil correcto
    case quizCorrectMedium = "quiz_correct_medium" // 20 XP - quiz medio correcto
    case quizCorrectHard = "quiz_correct_hard"  // 30 XP - quiz difícil correcto
    case quizPerfect = "quiz_perfect"           // 20 XP bonus - quiz perfecto
    case questQuick = "quest_quick"             // 15 XP - misión rápida
    case questChallenge = "quest_challenge"     // 40 XP - misión desafío
    case questEpic = "quest_epic"               // 100 XP - misión épica
    case planCompleted = "plan_completed"       // 50 XP - plan completado
    case achievementUnlock = "achievement"      // Variable - logro desbloqueado
    case dailyGoal = "daily_goal"               // 25 XP - meta diaria cumplida
    case streakBonus = "streak_bonus"           // 10 XP - bonus por día de racha
    case firstOfDay = "first_of_day"            // 5 XP - primer mensaje del día

    /// XP base para cada fuente
    var baseXP: Int {
        switch self {
        case .message: return 5
        case .quizCorrectEasy: return 10
        case .quizCorrectMedium: return 20
        case .quizCorrectHard: return 30
        case .quizPerfect: return 20
        case .questQuick: return 15
        case .questChallenge: return 40
        case .questEpic: return 100
        case .planCompleted: return 50
        case .achievementUnlock: return 0 // Variable, se pasa como parámetro
        case .dailyGoal: return 25
        case .streakBonus: return 10
        case .firstOfDay: return 5
        }
    }

    /// Descripción para mostrar en UI
    var displayName: String {
        switch self {
        case .message: return "Mensaje enviado"
        case .quizCorrectEasy: return "Quiz fácil"
        case .quizCorrectMedium: return "Quiz medio"
        case .quizCorrectHard: return "Quiz difícil"
        case .quizPerfect: return "Quiz perfecto"
        case .questQuick: return "Misión rápida"
        case .questChallenge: return "Misión desafío"
        case .questEpic: return "Misión épica"
        case .planCompleted: return "Plan completado"
        case .achievementUnlock: return "Logro desbloqueado"
        case .dailyGoal: return "Meta diaria"
        case .streakBonus: return "Bonus de racha"
        case .firstOfDay: return "Primer mensaje del día"
        }
    }

    /// Icono SF Symbol
    var icon: String {
        switch self {
        case .message: return "bubble.left.fill"
        case .quizCorrectEasy, .quizCorrectMedium, .quizCorrectHard: return "checkmark.circle.fill"
        case .quizPerfect: return "star.fill"
        case .questQuick: return "bolt.fill"
        case .questChallenge: return "flame.fill"
        case .questEpic: return "crown.fill"
        case .planCompleted: return "list.bullet.clipboard.fill"
        case .achievementUnlock: return "trophy.fill"
        case .dailyGoal: return "target"
        case .streakBonus: return "flame.fill"
        case .firstOfDay: return "sunrise.fill"
        }
    }
}

// MARK: - Player Level System

/// Sistema de niveles del jugador
enum PlayerLevel {

    /// Calcula el XP necesario para alcanzar un nivel específico
    /// Fórmula: 100 * 1.5^(nivel-1)
    static func xpRequired(forLevel level: Int) -> Int {
        guard level > 0 else { return 0 }
        return Int(100.0 * pow(1.5, Double(level - 1)))
    }

    /// Calcula el XP total acumulado necesario para alcanzar un nivel
    static func totalXPRequired(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        var total = 0
        for l in 1..<level {
            total += xpRequired(forLevel: l)
        }
        return total
    }

    /// Calcula el nivel actual basado en XP total
    static func level(fromTotalXP xp: Int) -> Int {
        var level = 1
        var xpNeeded = 0

        while xpNeeded + xpRequired(forLevel: level) <= xp {
            xpNeeded += xpRequired(forLevel: level)
            level += 1
        }

        return level
    }

    /// Calcula el progreso dentro del nivel actual (0.0 - 1.0)
    static func progress(forTotalXP xp: Int) -> Double {
        let currentLevel = level(fromTotalXP: xp)
        let xpForCurrentLevel = totalXPRequired(forLevel: currentLevel)
        let xpForNextLevel = xpRequired(forLevel: currentLevel)
        guard xpForNextLevel > 0 else { return 0 }
        let xpInCurrentLevel = xp - xpForCurrentLevel

        return Double(xpInCurrentLevel) / Double(xpForNextLevel)
    }

    /// XP restante para el siguiente nivel
    static func xpToNextLevel(fromTotalXP xp: Int) -> Int {
        let currentLevel = level(fromTotalXP: xp)
        let xpForCurrentLevel = totalXPRequired(forLevel: currentLevel)
        let xpForNextLevel = xpRequired(forLevel: currentLevel)
        let xpInCurrentLevel = xp - xpForCurrentLevel

        return xpForNextLevel - xpInCurrentLevel
    }

    /// Título del jugador basado en su nivel
    static func title(forLevel level: Int) -> String {
        switch level {
        case 1...4: return "Novato"
        case 5...9: return "Explorador"
        case 10...14: return "Estudiante"
        case 15...19: return "Experto"
        case 20...29: return "Maestro"
        case 30...: return "Leyenda"
        default: return "Novato"
        }
    }

    /// Icono del título
    static func titleIcon(forLevel level: Int) -> String {
        switch level {
        case 1...4: return "leaf.fill"
        case 5...9: return "binoculars.fill"
        case 10...14: return "book.fill"
        case 15...19: return "brain.head.profile.fill"
        case 20...29: return "graduationcap.fill"
        case 30...: return "crown.fill"
        default: return "leaf.fill"
        }
    }
}
