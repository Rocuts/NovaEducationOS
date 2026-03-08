import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.nova.education", category: "AppLifecycle")

@main
struct NovaEducationApp: App {
    private let container: ModelContainer
    // App level state for alerts doesn't work well initialized before `container` without causing init issues if not careful,
    // so we use a view-level flag. We detect the need for an alert during init and pass it to the view.
    private let needsDataResetAlert: Bool

    init() {
        let schema = Schema(SchemaV2.models)

        // Configuration for the main persistent store
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        var resolvedContainer: ModelContainer?

        do {
            resolvedContainer = try ModelContainer(
                for: schema,
                migrationPlan: NovaEducationMigrationPlan.self,
                configurations: [modelConfiguration]
            )
        } catch {
            logger.error("Could not create ModelContainer: \(error.localizedDescription, privacy: .public)")

            // Fallback: Try a new named store if migration fails
            let fallbackConfig = ModelConfiguration("NovaEducation_Reset", schema: schema)
            do {
                resolvedContainer = try ModelContainer(
                    for: schema,
                    migrationPlan: NovaEducationMigrationPlan.self,
                    configurations: [fallbackConfig]
                )
            } catch {
                logger.error("Could not create fallback ModelContainer: \(error.localizedDescription, privacy: .public)")
                // Last resort: in-memory store so the app doesn't crash
                let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                resolvedContainer = try? ModelContainer(for: schema, configurations: [inMemoryConfig])
            }
        }

        if let resolved = resolvedContainer {
            container = resolved
            needsDataResetAlert = false
        } else {
            // Final fallback -- in-memory so the app can at least launch
            do {
                let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = try ModelContainer(for: schema, configurations: [inMemoryConfig])
            } catch {
                fatalError("NovaEducation: Failed to create even an in-memory ModelContainer: \(error)")
            }
            needsDataResetAlert = true
        }
    }

    @State private var focusManager = FocusManager()
    @State private var showDataResetAlert = false

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(focusManager)
                .alert("Error de datos", isPresented: $showDataResetAlert) {
                    Button("Entendido", role: .cancel) {}
                } message: {
                    Text("No se pudieron cargar tus datos. La app funcionará con datos temporales.")
                }
                .onAppear {
                    if needsDataResetAlert {
                        showDataResetAlert = true
                    }
                }
        }
        .modelContainer(container)
    }
}
