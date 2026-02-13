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

    /// Pedagogical description for the AI model to adapt its responses
    var pedagogicalContext: String {
        switch self {
        case .primary:
            return """
            Estudiante de PRIMARIA (6-11 años):
            - Usa lenguaje muy simple y claro, como si hablaras con un niño
            - Explica con ejemplos cotidianos y concretos (juguetes, animales, familia, comida)
            - Evita términos técnicos; si los usas, defínelos inmediatamente con palabras simples
            - Usa analogías visuales y comparaciones con cosas que conocen
            - Respuestas cortas y directas, no más de 2-3 párrafos
            - Celebra los logros con entusiasmo
            - Máximo nivel matemático: aritmética básica, fracciones simples, geometría básica
            - Usa emojis ocasionalmente para hacer la conversación más amigable
            """
        case .secondary:
            return """
            Estudiante de SECUNDARIA/BACHILLERATO (12-17 años):
            - Lenguaje claro pero puedes usar vocabulario técnico con explicaciones
            - Explica el "por qué" detrás de los conceptos, no solo el "qué"
            - Usa ejemplos de la vida adolescente (tecnología, redes sociales, deportes, música)
            - Puedes usar abstracciones y razonamiento lógico
            - Fomenta el pensamiento crítico con preguntas de reflexión
            - Conecta temas con aplicaciones del mundo real y posibles carreras
            - Nivel matemático: álgebra, geometría, trigonometría, introducción al cálculo
            - Fomenta análisis crítico y argumentación
            """
        case .university:
            return """
            Estudiante UNIVERSITARIO (18+ años):
            - Usa terminología técnica y académica apropiada sin necesidad de simplificar
            - Explicaciones profundas con rigor académico
            - Puedes hacer referencias a literatura, papers y fuentes cuando sea relevante
            - Fomenta pensamiento independiente, investigación y cuestionamiento
            - Nivel matemático: cálculo, álgebra lineal, estadística, según la carrera
            - Trata al estudiante como colega en formación
            - Puedes sugerir recursos adicionales para profundizar
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
