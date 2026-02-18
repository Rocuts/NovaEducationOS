import SwiftUI
import SwiftData

@main
struct NovaEducationApp: App {
    private let container: ModelContainer
    @State private var showDataResetAlert = false

    init() {
        let schema = Schema([
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
        ])

        // Configuration for the main persistent store
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        var resolvedContainer: ModelContainer?

        do {
            resolvedContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("Could not create ModelContainer: \(error)")

            // Fallback: Try a new named store if migration fails
            let fallbackConfig = ModelConfiguration("NovaEducation_Reset", schema: schema)
            do {
                resolvedContainer = try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                print("Could not create fallback ModelContainer: \(error)")
                // Last resort: in-memory store so the app doesn't crash
                let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                resolvedContainer = try? ModelContainer(for: schema, configurations: [inMemoryConfig])
            }
        }

        container = resolvedContainer ?? (try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]))
        if resolvedContainer == nil {
            _showDataResetAlert = State(initialValue: true)
        }
    }

    @State private var focusManager = FocusManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(focusManager)
                .task {
                    ImageGeneratorService.cleanupOldImages()
                }
                .alert("Error de datos", isPresented: $showDataResetAlert) {
                    Button("Entendido", role: .cancel) {}
                } message: {
                    Text("No se pudieron cargar tus datos. La app funcionará con datos temporales.")
                }
        }
        .modelContainer(container)
    }
}
