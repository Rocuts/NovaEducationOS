import SwiftUI
import SwiftData

@Model
class UserSettings {
    var id: UUID
    var studentName: String
    var educationLevel: EducationLevel
    var preferredTheme: AppTheme
    var notificationsEnabled: Bool
    var studyRemindersEnabled: Bool
    var studyReminderTime: Date
    var soundsEnabled: Bool
    var hapticsEnabled: Bool
    var dailyGoalMinutes: Int
    var createdAt: Date
    var updatedAt: Date

    var lastSubjectId: String?

    // MARK: - Gamification Fields

    /// XP total acumulado
    var totalXP: Int

    /// Número total de mensajes enviados
    var totalMessages: Int

    /// Número de quizzes perfectos
    var perfectQuizzes: Int

    /// Número de planes completados
    var completedPlans: Int

    /// Días consecutivos de meta diaria cumplida
    var dailyGoalStreak: Int

    /// Último día que se cumplió la meta diaria
    var lastDailyGoalDate: Date?

    /// Fecha del último día inactivo (para logro "comeback")
    var lastInactiveDate: Date?

    /// Número de días inactivos antes de volver
    var daysInactiveBeforeReturn: Int

    // MARK: - Computed Properties

    /// Nivel actual calculado desde XP total
    var currentLevel: Int {
        PlayerLevel.level(fromTotalXP: totalXP)
    }

    /// Progreso hacia el siguiente nivel (0.0 - 1.0)
    var levelProgress: Double {
        PlayerLevel.progress(forTotalXP: totalXP)
    }

    /// XP necesario para el siguiente nivel
    var xpToNextLevel: Int {
        PlayerLevel.xpToNextLevel(fromTotalXP: totalXP)
    }

    /// Título del jugador
    var playerTitle: String {
        PlayerLevel.title(forLevel: currentLevel)
    }

    /// Icono del título
    var playerTitleIcon: String {
        PlayerLevel.titleIcon(forLevel: currentLevel)
    }

    init(
        studentName: String = "Estudiante",
        educationLevel: EducationLevel = .secondary,
        preferredTheme: AppTheme = .system,
        notificationsEnabled: Bool = true,
        studyRemindersEnabled: Bool = false,
        studyReminderTime: Date = Calendar.current.date(from: DateComponents(hour: 16, minute: 0)) ?? Date(),
        soundsEnabled: Bool = true,
        hapticsEnabled: Bool = true,
        dailyGoalMinutes: Int = 30,
        lastSubjectId: String? = nil
    ) {
        self.id = UUID()
        self.studentName = studentName
        self.educationLevel = educationLevel
        self.preferredTheme = preferredTheme
        self.notificationsEnabled = notificationsEnabled
        self.studyRemindersEnabled = studyRemindersEnabled
        self.studyReminderTime = studyReminderTime
        self.soundsEnabled = soundsEnabled
        self.hapticsEnabled = hapticsEnabled
        self.dailyGoalMinutes = dailyGoalMinutes
        self.lastSubjectId = lastSubjectId
        self.createdAt = Date()
        self.updatedAt = Date()

        // Initialize gamification fields
        self.totalXP = 0
        self.totalMessages = 0
        self.perfectQuizzes = 0
        self.completedPlans = 0
        self.dailyGoalStreak = 0
        self.lastDailyGoalDate = nil
        self.lastInactiveDate = nil
        self.daysInactiveBeforeReturn = 0
    }

    // MARK: - XP Methods

    /// Añade XP y retorna true si subió de nivel
    @discardableResult
    func addXP(_ amount: Int) -> Bool {
        let previousLevel = currentLevel
        totalXP += amount
        updatedAt = Date()
        return currentLevel > previousLevel
    }

    /// Incrementa el contador de mensajes
    func incrementMessages() {
        totalMessages += 1
        updatedAt = Date()
    }

    /// Incrementa el contador de quizzes perfectos
    func incrementPerfectQuizzes() {
        perfectQuizzes += 1
        updatedAt = Date()
    }

    /// Incrementa el contador de planes completados
    func incrementCompletedPlans() {
        completedPlans += 1
        updatedAt = Date()
    }

    /// Registra que se cumplió la meta diaria hoy
    func recordDailyGoalMet() {
        let today = Calendar.current.startOfDay(for: Date())

        if let lastDate = lastDailyGoalDate {
            let lastDay = Calendar.current.startOfDay(for: lastDate)
            let daysDiff = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysDiff == 1 {
                // Día consecutivo
                dailyGoalStreak += 1
            } else if daysDiff > 1 {
                // Se rompió la racha
                dailyGoalStreak = 1
            }
            // Si daysDiff == 0, ya se registró hoy
        } else {
            dailyGoalStreak = 1
        }

        lastDailyGoalDate = today
        updatedAt = Date()
    }
}

enum EducationLevel: String, Codable, CaseIterable {
    case primary = "primary"
    case secondary = "secondary"
    case university = "university"

    var displayName: String {
        switch self {
        case .primary: return "Primaria"
        case .secondary: return "Secundaria / Bachillerato"
        case .university: return "Universidad"
        }
    }

    var icon: String {
        switch self {
        case .primary: return "figure.child"
        case .secondary: return "graduationcap"
        case .university: return "building.columns"
        }
    }

    /// Age range for this education level
    var ageRange: String {
        switch self {
        case .primary: return "6-11 años"
        case .secondary: return "12-17 años"
        case .university: return "18+ años"
        }
    }

    /// Pedagogical description for the AI model to adapt its responses (English for model performance)
    var pedagogicalContext: String {
        switch self {
        case .primary:
            return """
            PRIMARY SCHOOL student (ages 6-11):
            - Use very simple, clear language as if speaking to a child
            - Explain with everyday, concrete examples (toys, animals, family, food)
            - Avoid technical terms; if used, define them immediately with simple words
            - Use visual analogies and comparisons with familiar things
            - Keep responses short and direct, no more than 2-3 paragraphs
            - Celebrate achievements enthusiastically
            - Max math level: basic arithmetic, simple fractions, basic geometry
            - Use emojis occasionally to make the conversation friendlier
            """
        case .secondary:
            return """
            SECONDARY/HIGH SCHOOL student (ages 12-17):
            - Clear language but you may use technical vocabulary with explanations
            - Explain the "why" behind concepts, not just the "what"
            - Use examples from teen life (technology, social media, sports, music)
            - You may use abstractions and logical reasoning
            - Encourage critical thinking with reflective questions
            - Connect topics to real-world applications and potential careers
            - Math level: algebra, geometry, trigonometry, intro to calculus
            - Foster critical analysis and argumentation
            """
        case .university:
            return """
            UNIVERSITY student (ages 18+):
            - Use appropriate technical and academic terminology without simplifying
            - Deep explanations with academic rigor
            - You may reference literature, papers, and sources when relevant
            - Encourage independent thinking, research, and questioning
            - Math level: calculus, linear algebra, statistics, as appropriate
            - Treat the student as a colleague in training
            - You may suggest additional resources to deepen understanding
            """
        }
    }
}

enum AppTheme: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"

    var displayName: String {
        switch self {
        case .light: return "Claro"
        case .dark: return "Oscuro"
        case .system: return "Sistema"
        }
    }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}
