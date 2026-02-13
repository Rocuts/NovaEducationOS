import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var selectedSubject: Subject?
    let settings: UserSettings
    @Environment(\.modelContext) private var modelContext

    let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Buenos dias"
        case 12..<19:
            return "Buenas tardes"
        default:
            return "Buenas noches"
        }
    }

    @State private var showingGoalSheet = false
    @State private var todayQuests: [DailyQuest] = []
    @State private var currentStreak: Int = 0
    @State private var showQuestsExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Section with XP
                headerSection

                // Gamification Section (XP + Streak + Quests)
                gamificationSection

                // Quick Actions
                quickActionsSection

                // Subjects Grid
                subjectsSection
            }
        }
        .contentMargins(.bottom, 100, for: .scrollContent)
        .background(backgroundGradient)
        .navigationBarHidden(true)
        .onAppear {
            loadGamificationData()
        }
    }

    // MARK: - Load Gamification Data

    private func loadGamificationData() {
        // Load daily quests
        DailyQuestService.shared.loadTodayQuests(context: modelContext)

        // Generate default quests if needed
        if DailyQuestService.shared.needsQuestGeneration(context: modelContext) {
            DailyQuestService.shared.generateDefaultQuests(context: modelContext)
        }

        todayQuests = DailyQuestService.shared.todayQuests

        // Calculate streak
        currentStreak = calculateCurrentStreak()
    }

    private func calculateCurrentStreak() -> Int {
        let descriptor = FetchDescriptor<DailyActivity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let activities = try? modelContext.fetch(descriptor) else { return 0 }

        var streak = 0
        var expectedDate = Calendar.current.startOfDay(for: Date())

        for activity in activities {
            let activityDate = Calendar.current.startOfDay(for: activity.date)

            if activityDate == expectedDate && activity.wasActive {
                streak += 1
                expectedDate = Calendar.current.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
            } else if activityDate < expectedDate {
                break
            }
        }

        return streak
    }

    // MARK: - Gamification Section

    private var gamificationSection: some View {
        VStack(spacing: 16) {
            // XP and Level Row
            HStack(spacing: 12) {
                // Level Badge
                CompactXPDisplay(
                    currentXP: settings.totalXP,
                    currentLevel: settings.currentLevel,
                    progress: settings.levelProgress
                )

                Spacer()

                // Streak Badge
                if currentStreak > 0 {
                    StreakBadge(days: currentStreak)
                }
            }
            .padding(.horizontal, 20)

            // Daily Quests Card (Compact version)
            if !todayQuests.isEmpty {
                CompactQuestsCard(quests: todayQuests) {
                    showQuestsExpanded = true
                }
                .padding(.horizontal, 20)
            }
        }
        .sheet(isPresented: $showQuestsExpanded) {
            QuestsDetailSheet(quests: $todayQuests, modelContext: modelContext)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        ZStack {
            Color(uiColor: .systemBackground)

            LinearGradient(
                colors: [
                    Color.blue.opacity(0.08),
                    Color.purple.opacity(0.05),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showingGoalSheet) {
            GoalEditView(settings: settings)
                .presentationDetents([.height(350)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                // Logo with glow effect
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                        .blur(radius: 10)

                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(greeting),")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Text(settings.studentName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .primary.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }

                Spacer()
            }

            Text("Que quieres aprender hoy?")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if let lastId = settings.lastSubjectId,
                   let subject = Subject(rawValue: lastId) {
                    QuickActionCard(
                        title: "Continuar",
                        subtitle: subject.displayName,
                        icon: subject.icon, // Use subject icon or play
                        gradient: [subject.color, subject.color.opacity(0.8)]
                    ) {
                        selectedSubject = subject
                    }
                } else {
                    QuickActionCard(
                        title: "Empezar",
                        subtitle: "Matemáticas",
                        icon: "play.fill",
                        gradient: [.blue, .cyan]
                    ) {
                        selectedSubject = .math
                    }
                }

                QuickActionCard(
                    title: "Chat libre",
                    subtitle: "Pregunta lo que quieras",
                    icon: "bubble.left.and.bubble.right.fill",
                    gradient: [.purple, .pink]
                ) {
                    selectedSubject = .open
                }

                QuickActionCard(
                    title: "Meta diaria",
                    subtitle: settings.dailyGoalMinutes == 0 ? "Sin meta" : "\(settings.dailyGoalMinutes) min",
                    icon: "target",
                    gradient: [.orange, .red]
                ) {
                    // Show goal setting sheet
                    showingGoalSheet = true
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Subjects Section
    private var subjectsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Materias")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Text("\(Subject.allCases.count) disponibles")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Subject.allCases) { subject in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSubject = subject
                        }
                    } label: {
                        SubjectCard(subject: subject)
                    }
                    .buttonStyle(SubjectButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Quick Action Card
struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subject Button Style
struct SubjectButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    HomeView(selectedSubject: .constant(nil), settings: UserSettings())
        .modelContainer(for: [UserSettings.self, DailyQuest.self, DailyActivity.self], inMemory: true)
}

// MARK: - Streak Badge

struct StreakBadge: View {
    let days: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.subheadline)
                .foregroundStyle(.orange)
                .symbolEffect(.bounce, value: days)

            Text("\(days)")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            Text(days == 1 ? "día" : "días")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - Quests Detail Sheet

struct QuestsDetailSheet: View {
    @Binding var quests: [DailyQuest]
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showXPGain = false
    @State private var lastXPGained = 0
    @State private var showLevelUp = false
    @State private var newLevel = 0
    @State private var newTitle = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "target")
                            .font(.largeTitle)
                            .foregroundStyle(.blue)

                        Text("Misiones de Hoy")
                            .font(.title2.bold())

                        let completed = quests.filter { $0.isCompleted }.count
                        Text("\(completed) de \(quests.count) completadas")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top)

                    // Quests List
                    DailyQuestsCard(quests: quests) { quest in
                        completeQuest(quest)
                    }
                    .padding(.horizontal)

                    // XP Summary
                    let pendingXP = quests.filter { $0.isActive }.reduce(0) { $0 + $1.xpReward }
                    if pendingXP > 0 {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.yellow)
                            Text("\(pendingXP) XP disponibles")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
            .overlay {
                // XP Toast
                if showXPGain {
                    VStack {
                        XPGainToast(
                            amount: lastXPGained,
                            multiplier: XPManager.shared.currentMultiplier
                        )
                        .padding()
                        .transition(.move(edge: .top).combined(with: .opacity))

                        Spacer()
                    }
                }
            }
            .fullScreenCover(isPresented: $showLevelUp) {
                LevelUpCelebration(
                    newLevel: newLevel,
                    newTitle: newTitle,
                    onDismiss: {
                        showLevelUp = false
                    }
                )
            }
        }
    }

    private func completeQuest(_ quest: DailyQuest) {
        guard !quest.isCompleted else { return }

        let result = DailyQuestService.shared.completeQuest(quest, context: modelContext)

        // Update local state
        if let index = quests.firstIndex(where: { $0.id == quest.id }) {
            quests[index] = quest
        }

        // Show XP feedback
        lastXPGained = result.xpGained
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showXPGain = true
        }

        // Hide after delay
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation {
                showXPGain = false
            }
        }

        // Level up celebration
        if result.leveledUp {
            newLevel = XPManager.shared.newLevel
            newTitle = PlayerLevel.title(forLevel: newLevel)

            Task {
                try? await Task.sleep(for: .seconds(0.5))
                showLevelUp = true
            }
        }
    }
}

// MARK: - Goal Edit View
struct GoalEditView: View {
    @Bindable var settings: UserSettings
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Meta Diaria")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Establece tu objetivo de estudio diario")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)

            // Goal Display
            VStack(spacing: 8) {
                Text("\(settings.dailyGoalMinutes)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
                
                Text("minutos")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            // Controls
            HStack(spacing: 32) {
                Button {
                    if settings.dailyGoalMinutes > 5 {
                        settings.dailyGoalMinutes -= 5
                        triggerHaptic()
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.gray.opacity(0.3))
                }

                Button {
                    if settings.dailyGoalMinutes < 240 {
                        settings.dailyGoalMinutes += 5
                        triggerHaptic()
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.blue)
                }
            }

            Spacer()

            // Save Button
            Button {
                dismiss()
            } label: {
                Text("Listo")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}
