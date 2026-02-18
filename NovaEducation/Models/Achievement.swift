import SwiftData
import Foundation
import SwiftUI

@Model
final class Achievement {
    #Index<Achievement>([\.isUnlocked])

    @Attribute(.unique) var id: String
    var isUnlocked: Bool
    var unlockedAt: Date?
    var progress: Int        // Progreso actual hacia el objetivo
    var targetValue: Int     // Valor objetivo para desbloquear

    init(id: String, isUnlocked: Bool = false, unlockedAt: Date? = nil, progress: Int = 0, targetValue: Int = 1) {
        self.id = id
        self.isUnlocked = isUnlocked
        self.unlockedAt = unlockedAt
        self.progress = progress
        self.targetValue = targetValue
    }

    /// Progreso como porcentaje (0.0 - 1.0)
    var progressPercentage: Double {
        guard targetValue > 0 else { return 0 }
        return min(Double(progress) / Double(targetValue), 1.0)
    }

    /// Actualiza el progreso y desbloquea si se alcanza el objetivo
    func updateProgress(_ newProgress: Int) {
        self.progress = newProgress
        if progress >= targetValue && !isUnlocked {
            isUnlocked = true
            unlockedAt = Date()
        }
    }

    /// Incrementa el progreso en 1
    func incrementProgress() {
        updateProgress(progress + 1)
    }
}

// MARK: - Achievement Tier

/// Tier del logro (Bronce, Plata, Oro)
enum AchievementTier: String, CaseIterable {
    case bronze = "bronze"
    case silver = "silver"
    case gold = "gold"

    var displayName: String {
        switch self {
        case .bronze: return "Bronce"
        case .silver: return "Plata"
        case .gold: return "Oro"
        }
    }

    var icon: String {
        switch self {
        case .bronze: return "medal.fill"
        case .silver: return "medal.fill"
        case .gold: return "medal.fill"
        }
    }

    var color: Color {
        switch self {
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.8)
        case .gold: return Color(red: 1.0, green: 0.84, blue: 0)
        }
    }

    var emoji: String {
        switch self {
        case .bronze: return "🥉"
        case .silver: return "🥈"
        case .gold: return "🥇"
        }
    }
}

// MARK: - Achievement Category

/// Categoría del logro
enum AchievementCategory: String, CaseIterable {
    case learning = "learning"
    case streaks = "streaks"
    case exploration = "exploration"
    case schedule = "schedule"
    case mastery = "mastery"
    case levels = "levels"

    var displayName: String {
        switch self {
        case .learning: return "Aprendizaje"
        case .streaks: return "Rachas"
        case .exploration: return "Exploración"
        case .schedule: return "Horarios"
        case .mastery: return "Maestría"
        case .levels: return "Niveles"
        }
    }

    var icon: String {
        switch self {
        case .learning: return "book.fill"
        case .streaks: return "flame.fill"
        case .exploration: return "safari.fill"
        case .schedule: return "clock.fill"
        case .mastery: return "star.fill"
        case .levels: return "chart.bar.fill"
        }
    }

    var color: Color {
        switch self {
        case .learning: return .blue
        case .streaks: return .orange
        case .exploration: return .green
        case .schedule: return .purple
        case .mastery: return .yellow
        case .levels: return .pink
        }
    }
}

// MARK: - Achievement Type (32 Achievements)

/// Definición estática de todos los logros
enum AchievementType: String, CaseIterable {

    // MARK: - Aprendizaje (11)
    case firstMessage = "first_message"
    case curious10 = "curious_10"
    case curious100 = "curious_100"
    case curious1000 = "curious_1000"
    case quizFirst = "quiz_first"
    case quizMaster10 = "quiz_master_10"
    case quizMaster50 = "quiz_master_50"
    case planCompleted = "plan_completed"
    case questComplete3 = "quest_complete_3"
    case questComplete10 = "quest_complete_10"
    case questComplete50 = "quest_complete_50"

    // MARK: - Rachas (6)
    case streak3 = "streak_3"
    case streak7 = "streak_7"
    case streak30 = "streak_30"
    case streak100 = "streak_100"
    case comeback = "comeback"
    case perfectWeek = "perfect_week"

    // MARK: - Exploración (7)
    case explorer3 = "explorer_3"
    case explorer6 = "explorer_6"
    case explorer12 = "explorer_12"
    case deepDive = "deep_dive"
    case marathon = "marathon"
    case ultraMarathon = "ultra_marathon"
    case multiSubjectDay = "multi_subject_day"

    // MARK: - Horarios (4)
    case earlyBird = "early_bird"
    case nightOwl = "night_owl"
    case lunchLearner = "lunch_learner"
    case weekendWarrior = "weekend_warrior"

    // MARK: - Maestría (5)
    case firstMastery = "first_mastery"
    case subjectExpert = "subject_expert"
    case polymath = "polymath"
    case perfectScore = "perfect_score"
    case knowledgeKeeper = "knowledge_keeper"

    // MARK: - Niveles (7)
    case level3 = "level_3"
    case level5 = "level_5"
    case level10 = "level_10"
    case level20 = "level_20"
    case xpCollector500 = "xp_collector_500"
    case xpCollector2000 = "xp_collector_2000"
    case xpCollector10000 = "xp_collector_10000"

    // MARK: - Properties

    var title: String {
        switch self {
        // Aprendizaje
        case .firstMessage: return "Primera Pregunta"
        case .curious10: return "Curioso"
        case .curious100: return "Muy Curioso"
        case .curious1000: return "Insaciable"
        case .quizFirst: return "Primer Quiz"
        case .quizMaster10: return "Aprendiz de Quiz"
        case .quizMaster50: return "Maestro del Quiz"
        case .planCompleted: return "Planificador"
        case .questComplete3: return "Misionero"
        case .questComplete10: return "Cazamisiones"
        case .questComplete50: return "Leyenda de Misiones"
        // Rachas
        case .streak3: return "Constante"
        case .streak7: return "Dedicado"
        case .streak30: return "Imparable"
        case .streak100: return "Leyenda"
        case .comeback: return "Regreso Épico"
        case .perfectWeek: return "Semana Perfecta"
        // Exploración
        case .explorer3: return "Explorador"
        case .explorer6: return "Aventurero"
        case .explorer12: return "Enciclopédico"
        case .deepDive: return "Inmersión"
        case .marathon: return "Maratón"
        case .ultraMarathon: return "Ultra Maratón"
        case .multiSubjectDay: return "Multitarea"
        // Horarios
        case .earlyBird: return "Madrugador"
        case .nightOwl: return "Búho Nocturno"
        case .lunchLearner: return "Aprendiz del Almuerzo"
        case .weekendWarrior: return "Guerrero de Fin de Semana"
        // Maestría
        case .firstMastery: return "Primera Maestría"
        case .subjectExpert: return "Experto"
        case .polymath: return "Erudito"
        case .perfectScore: return "Puntuación Perfecta"
        case .knowledgeKeeper: return "Guardián del Conocimiento"
        // Niveles
        case .level3: return "Primeros Pasos"
        case .level5: return "Nivel 5"
        case .level10: return "Nivel 10"
        case .level20: return "Nivel 20"
        case .xpCollector500: return "Coleccionista"
        case .xpCollector2000: return "Acumulador"
        case .xpCollector10000: return "Magnate del XP"
        }
    }

    var description: String {
        switch self {
        // Aprendizaje
        case .firstMessage: return "Envía tu primer mensaje"
        case .curious10: return "Envía 10 mensajes"
        case .curious100: return "Envía 100 mensajes"
        case .curious1000: return "Envía 1000 mensajes"
        case .quizFirst: return "Completa tu primer quiz"
        case .quizMaster10: return "Consigue 10 quizzes perfectos"
        case .quizMaster50: return "Consigue 50 quizzes perfectos"
        case .planCompleted: return "Completa un plan de aprendizaje"
        case .questComplete3: return "Completa 3 misiones diarias"
        case .questComplete10: return "Completa 10 misiones diarias"
        case .questComplete50: return "Completa 50 misiones diarias"
        // Rachas
        case .streak3: return "Estudia 3 días seguidos"
        case .streak7: return "Estudia 7 días seguidos"
        case .streak30: return "Estudia 30 días seguidos"
        case .streak100: return "Estudia 100 días seguidos"
        case .comeback: return "Vuelve después de 7+ días inactivo"
        case .perfectWeek: return "Cumple tu meta diaria 7 días seguidos"
        // Exploración
        case .explorer3: return "Explora 3 materias diferentes"
        case .explorer6: return "Explora 6 materias diferentes"
        case .explorer12: return "Explora las 12 materias"
        case .deepDive: return "Estudia 30 min en una sesión"
        case .marathon: return "Estudia 60 min en una sesión"
        case .ultraMarathon: return "Estudia 120 min en una sesión"
        case .multiSubjectDay: return "Estudia 3 materias en un solo día"
        // Horarios
        case .earlyBird: return "Estudia antes de las 7 AM"
        case .nightOwl: return "Estudia después de las 11 PM"
        case .lunchLearner: return "Estudia entre 12 y 2 PM"
        case .weekendWarrior: return "Estudia sábado Y domingo"
        // Maestría
        case .firstMastery: return "Alcanza 80%+ de maestría en un concepto"
        case .subjectExpert: return "10 conceptos con 80%+ en una materia"
        case .polymath: return "5 conceptos con 80%+ en 5 materias diferentes"
        case .perfectScore: return "100% en un quiz de 10 preguntas"
        case .knowledgeKeeper: return "Almacena 50 conceptos"
        // Niveles
        case .level3: return "Alcanza el nivel 3"
        case .level5: return "Alcanza el nivel 5"
        case .level10: return "Alcanza el nivel 10"
        case .level20: return "Alcanza el nivel 20"
        case .xpCollector500: return "Acumula 500 XP en total"
        case .xpCollector2000: return "Acumula 2000 XP en total"
        case .xpCollector10000: return "Acumula 10000 XP en total"
        }
    }

    var icon: String {
        switch self {
        // Aprendizaje
        case .firstMessage: return "bubble.left.fill"
        case .curious10, .curious100, .curious1000: return "questionmark.circle.fill"
        case .quizFirst, .quizMaster10, .quizMaster50: return "checkmark.seal.fill"
        case .planCompleted: return "list.bullet.clipboard.fill"
        case .questComplete3, .questComplete10, .questComplete50: return "target"
        // Rachas
        case .streak3, .streak7, .streak30, .streak100: return "flame.fill"
        case .comeback: return "arrow.counterclockwise"
        case .perfectWeek: return "star.circle.fill"
        // Exploración
        case .explorer3, .explorer6, .explorer12: return "safari.fill"
        case .deepDive: return "figure.pool.swim"
        case .marathon: return "figure.run"
        case .ultraMarathon: return "figure.hiking"
        case .multiSubjectDay: return "square.grid.3x3.fill"
        // Horarios
        case .earlyBird: return "sunrise.fill"
        case .nightOwl: return "moon.stars.fill"
        case .lunchLearner: return "fork.knife"
        case .weekendWarrior: return "sun.max.fill"
        // Maestría
        case .firstMastery: return "brain.head.profile.fill"
        case .subjectExpert: return "star.fill"
        case .polymath: return "sparkles"
        case .perfectScore: return "100.circle.fill"
        case .knowledgeKeeper: return "books.vertical.fill"
        // Niveles
        case .level3: return "3.circle.fill"
        case .level5: return "5.circle.fill"
        case .level10: return "10.circle.fill"
        case .level20: return "20.circle.fill"
        case .xpCollector500: return "star.circle.fill"
        case .xpCollector2000: return "star.square.fill"
        case .xpCollector10000: return "crown.fill"
        }
    }

    var tier: AchievementTier {
        switch self {
        // Bronce (fáciles)
        case .firstMessage, .curious10, .quizFirst, .planCompleted,
             .questComplete3,
             .streak3, .comeback,
             .explorer3, .deepDive,
             .earlyBird, .nightOwl, .lunchLearner,
             .firstMastery,
             .level3, .level5, .xpCollector500:
            return .bronze

        // Plata (intermedios)
        case .curious100, .quizMaster10,
             .questComplete10,
             .streak7, .perfectWeek,
             .explorer6, .marathon, .multiSubjectDay,
             .weekendWarrior,
             .subjectExpert, .perfectScore,
             .level10, .xpCollector2000:
            return .silver

        // Oro (difíciles)
        case .curious1000, .quizMaster50,
             .questComplete50,
             .streak30, .streak100,
             .explorer12, .ultraMarathon,
             .polymath, .knowledgeKeeper,
             .level20, .xpCollector10000:
            return .gold
        }
    }

    var category: AchievementCategory {
        switch self {
        case .firstMessage, .curious10, .curious100, .curious1000,
             .quizFirst, .quizMaster10, .quizMaster50, .planCompleted,
             .questComplete3, .questComplete10, .questComplete50:
            return .learning
        case .streak3, .streak7, .streak30, .streak100, .comeback, .perfectWeek:
            return .streaks
        case .explorer3, .explorer6, .explorer12, .deepDive, .marathon, .ultraMarathon,
             .multiSubjectDay:
            return .exploration
        case .earlyBird, .nightOwl, .lunchLearner, .weekendWarrior:
            return .schedule
        case .firstMastery, .subjectExpert, .polymath, .perfectScore, .knowledgeKeeper:
            return .mastery
        case .level3, .level5, .level10, .level20,
             .xpCollector500, .xpCollector2000, .xpCollector10000:
            return .levels
        }
    }

    /// XP que otorga al desbloquearse (escalado por tier)
    var xpReward: Int {
        switch tier {
        case .bronze: return xpRewardBase
        case .silver: return Int(Double(xpRewardBase) * 1.5)
        case .gold: return xpRewardBase * 2
        }
    }

    private var xpRewardBase: Int {
        switch self {
        // Aprendizaje
        case .firstMessage: return 10
        case .curious10: return 25
        case .curious100: return 50
        case .curious1000: return 150
        case .quizFirst: return 15
        case .quizMaster10: return 75
        case .quizMaster50: return 200
        case .planCompleted: return 30
        case .questComplete3: return 20
        case .questComplete10: return 75
        case .questComplete50: return 200
        // Rachas
        case .streak3: return 20
        case .streak7: return 50
        case .streak30: return 200
        case .streak100: return 500
        case .comeback: return 25
        case .perfectWeek: return 100
        // Exploración
        case .explorer3: return 20
        case .explorer6: return 50
        case .explorer12: return 150
        case .deepDive: return 30
        case .marathon: return 75
        case .ultraMarathon: return 150
        case .multiSubjectDay: return 40
        // Horarios
        case .earlyBird: return 20
        case .nightOwl: return 20
        case .lunchLearner: return 15
        case .weekendWarrior: return 40
        // Maestría
        case .firstMastery: return 25
        case .subjectExpert: return 100
        case .polymath: return 250
        case .perfectScore: return 75
        case .knowledgeKeeper: return 150
        // Niveles
        case .level3: return 15
        case .level5: return 50
        case .level10: return 100
        case .level20: return 250
        case .xpCollector500: return 25
        case .xpCollector2000: return 75
        case .xpCollector10000: return 300
        }
    }

    /// Valor objetivo para desbloquear (para tracking de progreso)
    var targetValue: Int {
        switch self {
        case .firstMessage: return 1
        case .curious10: return 10
        case .curious100: return 100
        case .curious1000: return 1000
        case .quizFirst: return 1
        case .quizMaster10: return 10
        case .quizMaster50: return 50
        case .planCompleted: return 1
        case .questComplete3: return 3
        case .questComplete10: return 10
        case .questComplete50: return 50
        case .streak3: return 3
        case .streak7: return 7
        case .streak30: return 30
        case .streak100: return 100
        case .comeback: return 1
        case .perfectWeek: return 7
        case .explorer3: return 3
        case .explorer6: return 6
        case .explorer12: return 12
        case .deepDive: return 30  // minutos
        case .marathon: return 60
        case .ultraMarathon: return 120
        case .multiSubjectDay: return 3
        case .earlyBird: return 1
        case .nightOwl: return 1
        case .lunchLearner: return 1
        case .weekendWarrior: return 1
        case .firstMastery: return 1
        case .subjectExpert: return 10
        case .polymath: return 5
        case .perfectScore: return 1
        case .knowledgeKeeper: return 50
        case .level3: return 3
        case .level5: return 5
        case .level10: return 10
        case .level20: return 20
        case .xpCollector500: return 500
        case .xpCollector2000: return 2000
        case .xpCollector10000: return 10000
        }
    }

    /// Color principal del logro (basado en categoría)
    var color: Color {
        category.color
    }
}

// MARK: - Helpers

extension AchievementType {

    /// Retorna todos los logros de una categoría
    static func achievements(for category: AchievementCategory) -> [AchievementType] {
        allCases.filter { $0.category == category }
    }

    /// Retorna todos los logros de un tier
    static func achievements(for tier: AchievementTier) -> [AchievementType] {
        allCases.filter { $0.tier == tier }
    }
}

