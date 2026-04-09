import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var selectedSubject: Subject?
    let settings: UserSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(FocusManager.self) private var focusManager
    var transitionNamespace: Namespace.ID

    let columns = [
        GridItem(.adaptive(minimum: 150), spacing: Nova.Spacing.lg)
    ]

    @State private var viewModel = HomeViewModel()
    @Namespace private var statsGlassNamespace

    // Entrance animation states
    @State private var headerAppeared = false
    @State private var chipsAppeared = false
    @State private var cardsAppeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Nova.Spacing.xl) {
                // Scroll detection anchor
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("homeScroll")).minY)
                }
                .frame(height: 0)

                headerSection
                quickActionsSection
                subjectsSection
            }
            .padding(.top, Nova.Spacing.md)
        }
        .coordinateSpace(name: "homeScroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
            let scrolled = offset < -10
            if scrolled != viewModel.hasScrolled {
                withAnimation(Nova.Animation.springSnappy) {
                    viewModel.hasScrolled = scrolled
                }
            }
        }
        .contentMargins(.top, Nova.Spacing.sm, for: .scrollContent)
        .contentMargins(.bottom, Nova.Spacing.tabBarClearance, for: .scrollContent)
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .top) {
            // Fade overlay that covers the status bar area and creates a smooth
            // transition so scrolled content dissolves before reaching system icons.
            // Uses multiple gradient stops for a premium, natural fade.
            LinearGradient(
                stops: [
                    .init(color: Color(.systemGroupedBackground), location: 0),
                    .init(color: Color(.systemGroupedBackground), location: 0.5),
                    .init(color: Color(.systemGroupedBackground).opacity(0.85), location: 0.65),
                    .init(color: Color(.systemGroupedBackground).opacity(0.5), location: 0.8),
                    .init(color: Color(.systemGroupedBackground).opacity(0.15), location: 0.92),
                    .init(color: Color(.systemGroupedBackground).opacity(0), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 110)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            viewModel.loadGamificationData(context: modelContext)
        }
    }


    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Nova.Spacing.md) {
            // Top row: Greeting + Focus toggle
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Nova.Spacing.xxxs) {
                    Text(viewModel.greeting)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(settings.studentName)
                        .font(.title.bold())
                }

                Spacer()

                // Focus mode toggle - changes icon and color when active
                Button {
                    focusManager.toggleFocusMode()
                } label: {
                    Image(systemName: focusManager.isFocusModeActive ? "moon.stars.fill" : "moon.stars")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(focusManager.isFocusModeActive ? .white : .indigo)
                        .frame(width: 36, height: 36)
                        .background(
                            focusManager.isFocusModeActive
                                ? AnyShapeStyle(.indigo)
                                : AnyShapeStyle(.fill.quaternary)
                        )
                        .clipShape(Circle())
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(focusManager.isFocusModeActive ? "Desactivar modo enfoque" : "Activar modo enfoque")
                .accessibilityHint("Toca dos veces para alternar el modo de concentración")
                .animation(Nova.Animation.entranceFast, value: focusManager.isFocusModeActive)
            }

            // Stats row: XP + Streak + Quests
            statsRow
        }
        .padding(.horizontal, Nova.Spacing.screenHorizontal)
        .opacity(headerAppeared ? 1 : 0)
        .offset(y: headerAppeared ? 0 : 15)
        .animation(Nova.Animation.entranceMedium, value: headerAppeared)
        .onAppear { headerAppeared = true }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: Nova.Spacing.md) {
            GlassEffectContainer(spacing: Nova.Spacing.sm) {
                // Level + XP
                CompactXPDisplay(
                    currentXP: settings.totalXP,
                    currentLevel: settings.currentLevel,
                    progress: settings.levelProgress
                )
                .glassEffectID("xpDisplay", in: statsGlassNamespace)

                // Streak — morphs in/out of the XP display glass group
                if viewModel.currentStreak > 0 {
                    StreakBadge(days: viewModel.currentStreak)
                        .glassEffectID("streakBadge", in: statsGlassNamespace)
                }
            }

            Spacer()

            // Quests shortcut
            if !viewModel.todayQuests.isEmpty {
                Button {
                    viewModel.showQuestsExpanded = true
                } label: {
                    let completed = viewModel.todayQuests.filter { $0.isCompleted }.count
                    let total = viewModel.todayQuests.count
                    let pendingXP = viewModel.todayQuests.filter { $0.isActive }.reduce(0) { $0 + $1.xpReward }

                    HStack(spacing: Nova.Spacing.xs) {
                        Image(systemName: "target")
                            .font(.caption.bold())
                            .foregroundStyle(.blue)

                        Text("\(completed)/\(total)")
                            .font(.caption.bold())

                        if pendingXP > 0 {
                            Text("\(pendingXP) XP")
                                .font(.caption2.bold())
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.horizontal, Nova.Spacing.sm)
                    .padding(.vertical, Nova.Spacing.xs)
                    .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $viewModel.showQuestsExpanded) {
            QuestsDetailSheet(quests: $viewModel.todayQuests, modelContext: modelContext)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Nova.Spacing.sm) {
                if let lastId = settings.lastSubjectId,
                   let subject = Subject(rawValue: lastId) {
                    QuickActionChip(
                        title: "Continuar",
                        subtitle: subject.displayName,
                        icon: subject.icon,
                        color: subject.color,
                        hint: "Toca dos veces para continuar estudiando \(subject.displayName)"
                    ) {
                        selectedSubject = subject
                    }
                    .matchedTransitionSource(id: subject.id, in: transitionNamespace)
                    .opacity(chipsAppeared ? 1 : 0)
                    .offset(y: chipsAppeared ? 0 : 20)
                    .animation(Nova.Animation.stagger(index: 0), value: chipsAppeared)
                }

                QuickActionChip(
                    title: "Chat libre",
                    subtitle: "Pregunta lo que quieras",
                    icon: "bubble.left.and.bubble.right.fill",
                    color: .purple,
                    hint: "Toca dos veces para iniciar un chat libre"
                ) {
                    selectedSubject = .open
                }
                .opacity(chipsAppeared ? 1 : 0)
                .offset(y: chipsAppeared ? 0 : 20)
                .animation(Nova.Animation.stagger(index: 1), value: chipsAppeared)

                QuickActionChip(
                    title: "Meta diaria",
                    subtitle: settings.dailyGoalMinutes == 0 ? "Sin meta" : "\(settings.dailyGoalMinutes) min",
                    icon: "target",
                    color: .orange,
                    hint: "Toca dos veces para configurar tu meta de estudio"
                ) {
                    viewModel.showingGoalSheet = true
                }
                .opacity(chipsAppeared ? 1 : 0)
                .offset(y: chipsAppeared ? 0 : 20)
                .animation(Nova.Animation.stagger(index: 2), value: chipsAppeared)
            }
            .padding(.horizontal, Nova.Spacing.screenHorizontal)
            .onAppear { chipsAppeared = true }
        }
        .sheet(isPresented: $viewModel.showingGoalSheet) {
            GoalEditView(settings: settings)
                .presentationDetents([.height(350)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Subjects Section

    private var subjectsSection: some View {
        VStack(alignment: .leading, spacing: Nova.Spacing.md) {
            HStack {
                Text("Materias")
                    .font(.title2.bold())

                Spacer()

                Text("\(Subject.allCases.count) disponibles")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Nova.Spacing.screenHorizontal)

            LazyVGrid(columns: columns, spacing: Nova.Spacing.lg) {
                ForEach(Array(Subject.allCases.enumerated()), id: \.element.id) { index, subject in
                    Button {
                        withAnimation(Nova.Animation.entranceFast) {
                            selectedSubject = subject
                        }
                    } label: {
                        SubjectCard(subject: subject)
                    }
                    .buttonStyle(.squishy)
                    .matchedTransitionSource(id: subject.id, in: transitionNamespace)
                    .opacity(cardsAppeared ? 1 : 0)
                    .offset(y: cardsAppeared ? 0 : 20)
                    .animation(Nova.Animation.stagger(index: index), value: cardsAppeared)
                }
            }
            .padding(.horizontal, Nova.Spacing.screenHorizontal)
            .onAppear { cardsAppeared = true }
        }
    }
}

// MARK: - Quick Action Chip

struct QuickActionChip: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var hint: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Nova.Spacing.sm) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Nova.Spacing.md)
            .padding(.vertical, Nova.Spacing.sm)
            .background(.regularMaterial, in: Capsule())
        }
        .buttonStyle(.squishy)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityHint(hint)
    }
}

// MARK: - Streak Badge

struct StreakBadge: View {
    let days: Int

    var body: some View {
        HStack(spacing: Nova.Spacing.xxs) {
            Image(systemName: "flame.fill")
                .font(.caption.bold())
                .foregroundStyle(.orange)

            Text("\(days)")
                .font(.caption.bold())

            Text(days == 1 ? "día" : "días")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Nova.Spacing.sm)
        .padding(.vertical, Nova.Spacing.xs)
        .background(.regularMaterial, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Racha de \(days) \(days == 1 ? "día" : "días")")
    }
}

// MARK: - Quests Detail Sheet

struct QuestsDetailSheet: View {
    @Binding var quests: [DailyQuest]
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showLevelUp = false
    @State private var newLevel = 1
    @State private var previousLevel = 0
    @State private var newTitle = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Nova.Spacing.xl) {
                    // Header
                    VStack(spacing: Nova.Spacing.sm) {
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
            .fullScreenCover(isPresented: $showLevelUp) {
                LevelUpCelebration(
                    newLevel: newLevel,
                    previousLevel: previousLevel,
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

        if let index = quests.firstIndex(where: { $0.id == quest.id }) {
            quests[index] = quest
        }

        IslandNotificationManager.shared.show(
            .xpGain(amount: result.xpGained, multiplier: XPManager.shared.currentMultiplier)
        )

        if result.leveledUp {
            let level = XPManager.shared.newLevel
            guard level > 0 else { return }
            previousLevel = XPManager.shared.previousLevel
            newLevel = level
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
    @ScaledMetric(relativeTo: .largeTitle) private var goalFontSize: CGFloat = 64

    var body: some View {
        VStack(spacing: Nova.Spacing.xxl) {
            VStack(spacing: Nova.Spacing.sm) {
                Text("Meta Diaria")
                    .font(.title2.bold())

                Text("Establece tu objetivo de estudio diario")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, Nova.Spacing.xxl)

            VStack(spacing: Nova.Spacing.sm) {
                Text("\(settings.dailyGoalMinutes)")
                    .font(.system(size: goalFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)

                Text("minutos")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Meta diaria")
            .accessibilityValue("\(settings.dailyGoalMinutes) minutos")

            HStack(spacing: Nova.Spacing.xxxl) {
                Button {
                    if settings.dailyGoalMinutes > 5 {
                        settings.dailyGoalMinutes -= 5
                        Nova.Haptics.medium()
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.largeTitle)
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Reducir meta")
                .accessibilityHint("Reduce la meta en 5 minutos")

                Button {
                    if settings.dailyGoalMinutes < 240 {
                        settings.dailyGoalMinutes += 5
                        Nova.Haptics.medium()
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.largeTitle)
                        .imageScale(.large)
                        .foregroundStyle(.blue)
                }
                .accessibilityLabel("Aumentar meta")
                .accessibilityHint("Aumenta la meta en 5 minutos")
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Listo")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, Nova.Spacing.screenHorizontal)
            .padding(.bottom, Nova.Spacing.screenHorizontal)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preview

struct HomeView_Preview_Wrapper: View {
    @Namespace var namespace

    var body: some View {
        HomeView(selectedSubject: .constant(nil), settings: UserSettings(), transitionNamespace: namespace)
            .modelContainer(for: [UserSettings.self, DailyQuest.self, DailyActivity.self], inMemory: true)
    }
}

#Preview {
    HomeView_Preview_Wrapper()
}
