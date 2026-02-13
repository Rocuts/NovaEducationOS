import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [UserSettings]
    @State private var selectedTab: AppTab = .home
    @State private var selectedSubject: Subject?

    private var settings: UserSettings? {
        settingsArray.first
    }

    enum AppTab: Int, CaseIterable {
        case home = 0
        case history = 1
        case progress = 2
        case settings = 3
        case search = 4
    }

    var body: some View {
        Group {
            if let settings = settings {
                TabView(selection: $selectedTab) {
                    // MARK: - Home Tab
                    SwiftUI.Tab("Inicio", systemImage: "house.fill", value: AppTab.home) {
                        NavigationStack {
                            HomeView(selectedSubject: $selectedSubject, settings: settings)
                                .navigationDestination(item: $selectedSubject) { subject in
                                    ChatView(subject: subject)
                                }
                        }
                    }

                    // MARK: - History Tab
                    SwiftUI.Tab("Historial", systemImage: "clock.arrow.circlepath", value: AppTab.history) {
                        NavigationStack {
                            HistoryView(selectedSubject: $selectedSubject)
                                .navigationDestination(item: $selectedSubject) { subject in
                                    ChatView(subject: subject)
                                }
                        }
                    }

                    // MARK: - Progress Tab
                    SwiftUI.Tab("Progreso", systemImage: "chart.bar.fill", value: AppTab.progress) {
                        NavigationStack {
                            ProgressView(settings: settings)
                        }
                    }

                    // MARK: - Settings Tab
                    SwiftUI.Tab("Ajustes", systemImage: "gearshape.fill", value: AppTab.settings) {
                        NavigationStack {
                            SettingsView(settings: settings)
                        }
                    }

                    // MARK: - Search Tab (iOS 26 special role - separated visually)
                    SwiftUI.Tab("Buscar", systemImage: "magnifyingglass", value: AppTab.search, role: .search) {
                        NavigationStack {
                            SearchView(selectedSubject: $selectedSubject, settings: settings)
                                .navigationDestination(item: $selectedSubject) { subject in
                                    ChatView(subject: subject)
                                }
                        }
                    }
                }
                .tabBarMinimizeBehavior(.onScrollDown)
            } else {
                SwiftUI.ProgressView()
            }
        }
        .preferredColorScheme(settings?.preferredTheme.colorScheme ?? .light)
        .onAppear {
            if settingsArray.isEmpty {
                let newSettings = UserSettings()
                modelContext.insert(newSettings)
            }
        }
    }
}

// MARK: - Progress View (With Gamification)
struct ProgressView: View {
    let settings: UserSettings
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StudySession.startTime) private var sessions: [StudySession]
    @Query(sort: \DailyActivity.date, order: .reverse) private var activities: [DailyActivity]
    @Query(sort: \Achievement.unlockedAt, order: .reverse) private var unlockedAchievements: [Achievement]
    @Query private var allAchievements: [Achievement]
    @Query private var allMessages: [ChatMessage]

    @State private var showAllAchievements = false
    @State private var multiplierBreakdown: [XPManager.MultiplierBonus] = []
    @State private var currentMultiplier: Double = 1.0

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

        let mostRecent = activities[0].date
        if !calendar.isDate(mostRecent, inSameDayAs: today) &&
            !calendar.isDate(mostRecent, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: today)!) {
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
        allMessages.count
    }

    var xpGainedToday: Int {
        XPManager.shared.xpGainedToday(context: modelContext)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // XP Progress Section (New!)
                xpProgressSection

                // Streak and Multiplier
                streakMultiplierSection

                // Stats Grid
                statsSection

                // Weekly Progress Chart
                weeklyProgressSection

                // Achievements Section (Improved)
                achievementsSection
            }
            .padding()
        }
        .contentMargins(.bottom, 100, for: .scrollContent)
        .background(backgroundGradient)
        .navigationTitle("Tu Progreso")
        .navigationBarTitleDisplayMode(.large)
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
        LinearGradient(
            colors: [
                Color(uiColor: .systemBackground),
                Color.blue.opacity(0.05),
                Color.purple.opacity(0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
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
        HStack(spacing: 16) {
            // Streak Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)

                    Spacer()
                }

                Text("\(currentStreak)")
                    .font(.title.bold())

                Text("Días de racha")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))

            // Multiplier Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .font(.title2)
                        .foregroundStyle(.purple)

                    Spacer()
                }

                Text("x\(String(format: "%.1f", currentMultiplier))")
                    .font(.title.bold())

                Text("Multiplicador")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))

            // XP Today Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.yellow)

                    Spacer()
                }

                Text("\(xpGainedToday)")
                    .font(.title.bold())

                Text("XP hoy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var statsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
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

    private var weeklyProgressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Esta semana")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 12) {
                let days = (0..<7).reversed().map { offset in
                    Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
                }

                ForEach(days, id: \.self) { day in
                    let dayString = daySymbol(for: day)
                    let minutes = minutesStudied(on: day)
                    let height = min(CGFloat(minutes), 120.0) / 120.0 * 80.0

                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 30, height: max(height, 5))

                        Text(dayString)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    }

    private func daySymbol(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        formatter.locale = Locale(identifier: "es_ES")
        return String(formatter.string(from: date).prefix(1)).uppercased()
    }

    private func minutesStudied(on date: Date) -> Double {
        let calendar = Calendar.current
        let daySessions = sessions.filter { calendar.isDate($0.startTime, inSameDayAs: date) }
        let totalSeconds = daySessions.reduce(0) { $0 + $1.duration }
        return totalSeconds / 60
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                VStack(spacing: 12) {
                    Image(systemName: "trophy")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("Aún no has desbloqueado logros")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("¡Sigue estudiando para conseguir tu primer logro!")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - All Achievements View

struct AllAchievementsView: View {
    let achievements: [Achievement]
    @Environment(\.dismiss) private var dismiss

    var achievementsByCategory: [(String, [AchievementType])] {
        [
            ("Aprendizaje", AchievementType.allCases.filter { $0.category == .learning }),
            ("Rachas", AchievementType.allCases.filter { $0.category == .streaks }),
            ("Exploración", AchievementType.allCases.filter { $0.category == .exploration }),
            ("Horarios", AchievementType.allCases.filter { $0.category == .schedule }),
            ("Maestría", AchievementType.allCases.filter { $0.category == .mastery }),
            ("Niveles", AchievementType.allCases.filter { $0.category == .levels })
        ]
    }

    func isUnlocked(_ type: AchievementType) -> Bool {
        achievements.first { $0.id == type.rawValue }?.isUnlocked ?? false
    }

    func progress(for type: AchievementType) -> Int {
        achievements.first { $0.id == type.rawValue }?.progress ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Summary
                    let unlockedCount = achievements.filter { $0.isUnlocked }.count
                    let totalCount = AchievementType.allCases.count

                    VStack(spacing: 8) {
                        Text("\(unlockedCount)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.blue)

                        Text("de \(totalCount) logros desbloqueados")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()

                    // Categories
                    ForEach(achievementsByCategory, id: \.0) { category, types in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(category)
                                .font(.headline)
                                .padding(.horizontal)

                            VStack(spacing: 8) {
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

// MARK: - Supporting Views for Progress
// (Keeping existing definitions if they were separate, but since we are rewriting the file, we include them)

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct AchievementRow: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isUnlocked: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? color.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(isUnlocked ? color : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
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
        .padding(.vertical, 4)
    }
}

#Preview {
    MainTabView()
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
