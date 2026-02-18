import SwiftUI
import SwiftData

// MARK: - Student Progress View (With Gamification)

struct StudentProgressView: View {
    let settings: UserSettings
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StudySession.startTime) private var sessions: [StudySession]
    @Query(sort: \DailyActivity.date, order: .reverse) private var activities: [DailyActivity]
    @Query(sort: \Achievement.unlockedAt, order: .reverse) private var unlockedAchievements: [Achievement]
    @Query private var allAchievements: [Achievement]
    // Use settings.totalMessages instead of fetching all ChatMessage records

    @State private var showAllAchievements = false
    @State private var multiplierBreakdown: [XPManager.MultiplierBonus] = []
    @State private var currentMultiplier: Double = 1.0
    @State private var sectionsAppeared = false
    @State private var barsAppeared = false

    private var totalStudyTime: String {
        let totalSeconds = sessions.reduce(0) { $0 + $1.duration }
        let hours = Int(totalSeconds / 3600)
        let minutes = Int((totalSeconds.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m"
    }

    private var currentStreak: Int {
        var streak = 0
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard !activities.isEmpty else { return 0 }
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }

        let mostRecent = activities[0].date
        if !calendar.isDate(mostRecent, inSameDayAs: today) &&
            !calendar.isDate(mostRecent, inSameDayAs: yesterday) {
            return 0
        }

        var currentDate = mostRecent
        streak = 1

        for i in 1..<activities.count {
            let previousActivityDate = activities[i].date
            if let expectedDate = calendar.date(byAdding: .day, value: -1, to: currentDate),
               calendar.isDate(previousActivityDate, inSameDayAs: expectedDate) {
                streak += 1
                currentDate = previousActivityDate
            } else {
                break
            }
        }

        return streak
    }

    var uniqueSubjectsCount: Int {
        Set(sessions.map { $0.subjectId }).count
    }

    var messagesCount: Int {
        settings.totalMessages
    }

    var xpGainedToday: Int {
        XPManager.shared.xpGainedToday(context: modelContext)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Nova.Spacing.sectionGap) {
                xpProgressSection
                    .opacity(sectionsAppeared ? 1 : 0)
                    .offset(y: sectionsAppeared ? 0 : 20)
                    .animation(Nova.Animation.stagger(index: 0), value: sectionsAppeared)

                streakMultiplierSection
                    .opacity(sectionsAppeared ? 1 : 0)
                    .offset(y: sectionsAppeared ? 0 : 20)
                    .animation(Nova.Animation.stagger(index: 1), value: sectionsAppeared)

                statsSection
                    .opacity(sectionsAppeared ? 1 : 0)
                    .offset(y: sectionsAppeared ? 0 : 20)
                    .animation(Nova.Animation.stagger(index: 2), value: sectionsAppeared)

                weeklyProgressSection
                    .opacity(sectionsAppeared ? 1 : 0)
                    .offset(y: sectionsAppeared ? 0 : 20)
                    .animation(Nova.Animation.stagger(index: 3), value: sectionsAppeared)

                achievementsSection
                    .opacity(sectionsAppeared ? 1 : 0)
                    .offset(y: sectionsAppeared ? 0 : 20)
                    .animation(Nova.Animation.stagger(index: 4), value: sectionsAppeared)
            }
            .padding()
            .onAppear { sectionsAppeared = true }
        }
        .contentMargins(.bottom, Nova.Spacing.tabBarClearance, for: .scrollContent)
        .background(backgroundGradient)
        .navigationTitle("Tu Progreso")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .onAppear {
            loadMultiplierData()
        }
        .sheet(isPresented: $showAllAchievements) {
            AllAchievementsView(achievements: allAchievements)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func loadMultiplierData() {
        let result = XPManager.shared.calculateMultiplier(context: modelContext)
        currentMultiplier = result.total
        multiplierBreakdown = result.breakdown
    }

    private var backgroundGradient: some View {
        Color(uiColor: .systemGroupedBackground)
            .ignoresSafeArea()
    }

    // MARK: - XP Progress Section

    private var xpProgressSection: some View {
        XPProgressBar(
            currentXP: settings.totalXP,
            currentLevel: settings.currentLevel,
            progress: settings.levelProgress,
            xpToNextLevel: settings.xpToNextLevel,
            playerTitle: settings.playerTitle,
            playerTitleIcon: settings.playerTitleIcon
        )
    }

    // MARK: - Streak and Multiplier Section

    private var streakMultiplierSection: some View {
        HStack(spacing: Nova.Spacing.lg) {
            // Streak Card
            StatCard(
                title: "Días de racha",
                value: "\(currentStreak)",
                icon: "flame.fill",
                color: .orange
            )

            // Multiplier Card
            StatCard(
                title: "Multiplicador",
                value: "x\(String(format: "%.1f", currentMultiplier))",
                icon: "bolt.fill",
                color: .purple
            )

            // XP Today Card
            StatCard(
                title: "XP hoy",
                value: "\(xpGainedToday)",
                icon: "sparkles",
                color: .yellow
            )
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Nova.Spacing.lg) {
            StatCard(
                title: "Tiempo de estudio",
                value: totalStudyTime,
                icon: "clock.fill",
                color: .blue
            )

            StatCard(
                title: "Mensajes",
                value: "\(messagesCount)",
                icon: "message.fill",
                color: .green
            )

            StatCard(
                title: "Materias",
                value: "\(uniqueSubjectsCount)",
                icon: "book.fill",
                color: .purple
            )

            StatCard(
                title: "Logros",
                value: "\(unlockedAchievements.count)/\(AchievementType.allCases.count)",
                icon: "trophy.fill",
                color: .yellow
            )
        }
    }

    // MARK: - Weekly Progress Section

    private var weeklyProgressSection: some View {
        VStack(alignment: .leading, spacing: Nova.Spacing.lg) {
            Text("Esta semana")
                .font(.headline)

            HStack(alignment: .bottom, spacing: Nova.Spacing.md) {
                let days = (0..<7).reversed().map { offset in
                    Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
                }

                ForEach(days, id: \.self) { day in
                    let dayString = daySymbol(for: day)
                    let minutes = minutesStudied(on: day)
                    let height = min(CGFloat(minutes), 120.0) / 120.0 * 80.0
                    let displayHeight = barsAppeared ? max(height, 5) : 5

                    VStack(spacing: Nova.Spacing.sm) {
                        RoundedRectangle(cornerRadius: Nova.Radius.xs)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 30, height: displayHeight)

                        Text(dayString)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(dayString), \(Int(minutes)) minutos")
                }
            }
            .frame(maxWidth: .infinity)
            .onAppear {
                withAnimation(Nova.Animation.entranceSlow.delay(0.3)) {
                    barsAppeared = true
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Nova.Radius.card))
    }

    private func daySymbol(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        formatter.locale = Locale(identifier: "es_ES")
        return String(formatter.string(from: date).prefix(1)).uppercased()
    }

    /// Pre-computed weekly study minutes (avoids O(n*7) per render)
    private var weeklyMinutes: [Date: Double] {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentSessions = sessions.filter { $0.startTime >= weekAgo }

        var result: [Date: Double] = [:]
        for session in recentSessions {
            let day = calendar.startOfDay(for: session.startTime)
            result[day, default: 0] += session.duration / 60
        }
        return result
    }

    private func minutesStudied(on date: Date) -> Double {
        let day = Calendar.current.startOfDay(for: date)
        return weeklyMinutes[day] ?? 0
    }

    // MARK: - Achievements Section

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: Nova.Spacing.lg) {
            HStack {
                Text("Logros")
                    .font(.headline)

                Spacer()

                Button("Ver todos") {
                    showAllAchievements = true
                }
                .font(.subheadline)
                .foregroundStyle(.blue)
            }

            if unlockedAchievements.isEmpty {
                VStack(spacing: Nova.Spacing.md) {
                    Image(systemName: "trophy")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                        .symbolEffect(.pulse, options: .repeating)

                    Text("Aún no has desbloqueado logros")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Envía tu primer mensaje para empezar")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Nova.Spacing.xl)
            } else {
                VStack(spacing: Nova.Spacing.md) {
                    ForEach(unlockedAchievements.prefix(5)) { achievement in
                        if let type = AchievementType(rawValue: achievement.id) {
                            AchievementProgressRow(
                                achievementType: type,
                                currentProgress: achievement.progress,
                                isUnlocked: true
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Nova.Radius.card))
    }
}

// MARK: - All Achievements View

struct AllAchievementsView: View {
    let achievements: [Achievement]
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var achievementCountSize: CGFloat = 48

    // Pre-computed dictionary for O(1) lookups instead of O(n) per achievement
    private var achievementMap: [String: Achievement] {
        Dictionary(uniqueKeysWithValues: achievements.map { ($0.id, $0) })
    }

    // Computed once, not on every body rebuild
    private static let categorizedTypes: [(String, [AchievementType])] = [
        ("Aprendizaje", AchievementType.allCases.filter { $0.category == .learning }),
        ("Rachas", AchievementType.allCases.filter { $0.category == .streaks }),
        ("Exploración", AchievementType.allCases.filter { $0.category == .exploration }),
        ("Horarios", AchievementType.allCases.filter { $0.category == .schedule }),
        ("Maestría", AchievementType.allCases.filter { $0.category == .mastery }),
        ("Niveles", AchievementType.allCases.filter { $0.category == .levels })
    ]

    func isUnlocked(_ type: AchievementType) -> Bool {
        achievementMap[type.rawValue]?.isUnlocked ?? false
    }

    func progress(for type: AchievementType) -> Int {
        achievementMap[type.rawValue]?.progress ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Nova.Spacing.sectionGap) {
                    let unlockedCount = achievements.filter { $0.isUnlocked }.count
                    let totalCount = AchievementType.allCases.count

                    VStack(spacing: Nova.Spacing.sm) {
                        Text("\(unlockedCount)")
                            .font(.system(size: achievementCountSize, weight: .bold, design: .rounded))
                            .foregroundStyle(.blue)

                        Text("de \(totalCount) logros desbloqueados")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()

                    ForEach(Self.categorizedTypes, id: \.0) { category, types in
                        VStack(alignment: .leading, spacing: Nova.Spacing.md) {
                            Text(category)
                                .font(.headline)
                                .padding(.horizontal)

                            VStack(spacing: Nova.Spacing.sm) {
                                ForEach(types, id: \.rawValue) { type in
                                    AchievementProgressRow(
                                        achievementType: type,
                                        currentProgress: progress(for: type),
                                        isUnlocked: isUnlocked(type)
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Todos los Logros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Nova.Spacing.md) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Spacer()
            }

            VStack(alignment: .leading, spacing: Nova.Spacing.xxs) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Nova.Radius.lg))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Achievement Row

struct AchievementRow: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isUnlocked: Bool

    var body: some View {
        HStack(spacing: Nova.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? color.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(isUnlocked ? color : .gray)
            }

            VStack(alignment: .leading, spacing: Nova.Spacing.xxs) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isUnlocked ? .primary : .secondary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, Nova.Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(description). \(isUnlocked ? "Desbloqueado" : "Bloqueado")")
    }
}

#Preview {
    NavigationStack {
        StudentProgressView(settings: UserSettings())
    }
    .modelContainer(for: [
        ChatMessage.self,
        UserSettings.self,
        StudySession.self,
        DailyActivity.self,
        Achievement.self,
        StudentKnowledge.self,
        QuizQuestion.self,
        LearningPlan.self,
        XPTransaction.self,
        DailyQuest.self
    ], inMemory: true)
}
