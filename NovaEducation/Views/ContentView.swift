import SwiftUI
import SwiftData

/// Legacy ContentView - Now replaced by MainTabView
/// Keeping for backwards compatibility and testing
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [UserSettings]
    @State private var selectedSubject: Subject?

    private var settings: UserSettings {
        if let existing = settingsArray.first {
            return existing
        } else {
            let newSettings = UserSettings()
            modelContext.insert(newSettings)
            return newSettings
        }
    }

    var body: some View {
        NavigationStack {
            HomeView(selectedSubject: $selectedSubject, settings: settings)
                .navigationDestination(item: $selectedSubject) { subject in
                    ChatView(subject: subject)
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ChatMessage.self, UserSettings.self, StudySession.self, DailyActivity.self, Achievement.self], inMemory: true)
}
