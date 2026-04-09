import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [UserSettings]
    @State private var selectedTab: AppTab = .home
    @State private var selectedSubject: Subject?
    @Namespace private var transitionNamespace

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

    @Environment(FocusManager.self) private var focusManager

    var body: some View {
        Group {
            if let settings = settings {
                TabView(selection: $selectedTab) {
                    // MARK: - Home Tab
                    SwiftUI.Tab("Inicio", systemImage: "house.fill", value: AppTab.home) {
                        NavigationStack {
                            HomeView(selectedSubject: $selectedSubject, settings: settings, transitionNamespace: transitionNamespace)
                                .navigationDestination(item: $selectedSubject) { subject in
                                    ChatView(subject: subject)
                                        .navigationTransition(.zoom(sourceID: subject.id, in: transitionNamespace))
                                        .toolbar(focusManager.isFocusModeActive ? .hidden : .visible, for: .tabBar)
                                }
                        }
                    }

                    // MARK: - History Tab
                    SwiftUI.Tab("Historial", systemImage: "clock.arrow.circlepath", value: AppTab.history) {
                        NavigationStack {
                            HistoryView(selectedSubject: $selectedSubject)
                                .navigationDestination(item: $selectedSubject) { subject in
                                    ChatView(subject: subject)
                                        .toolbar(focusManager.isFocusModeActive ? .hidden : .visible, for: .tabBar)
                                }
                        }
                    }

                    // MARK: - Progress Tab
                    SwiftUI.Tab("Progreso", systemImage: "chart.bar.fill", value: AppTab.progress) {
                        NavigationStack {
                            StudentProgressView(settings: settings)
                        }
                    }

                    // MARK: - Settings Tab
                    SwiftUI.Tab("Ajustes", systemImage: "gearshape.fill", value: AppTab.settings) {
                        NavigationStack {
                            SettingsView(settings: settings)
                        }
                    }

                    // MARK: - Search Tab
                    SwiftUI.Tab("Buscar", systemImage: "magnifyingglass", value: AppTab.search, role: .search) {
                        NavigationStack {
                            SearchView(selectedSubject: $selectedSubject, settings: settings)
                                .navigationDestination(item: $selectedSubject) { subject in
                                    ChatView(subject: subject)
                                        .toolbar(focusManager.isFocusModeActive ? .hidden : .visible, for: .tabBar)
                                }
                        }
                    }
                }
                .tabBarMinimizeBehavior(.onScrollDown)
            } else {
                // Premium branded loading state
                VStack(spacing: Nova.Spacing.lg) {
                    NovaAvatarView(state: .thinking)
                        .frame(width: 120, height: 120)

                    Text("Cargando...")
                        .font(Nova.Typography.headlineSmall)
                        .foregroundStyle(.secondary)
                        .shimmer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemBackground))
            }
        }
        .preferredColorScheme(settings?.preferredTheme.colorScheme)
        .overlay {
            // Sistema de notificaciones premium — emerge del Dynamic Island
            IslandNotificationContainer()
        }
        .onAppear {
            if settingsArray.isEmpty {
                let newSettings = UserSettings()
                modelContext.insert(newSettings)
            }
            // Sync haptics preference on launch
            Nova.Haptics.isEnabled = settings?.hapticsEnabled ?? true
        }
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
