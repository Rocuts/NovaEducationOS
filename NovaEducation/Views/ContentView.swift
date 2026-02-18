import SwiftUI
import SwiftData

/// Legacy ContentView - Now replaced by MainTabView
/// Keeping for backwards compatibility and testing
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [UserSettings]
    @State private var selectedSubject: Subject?
    @Namespace private var transitionNamespace

    var body: some View {
        NavigationStack {
            if let settings = settingsArray.first {
                HomeView(selectedSubject: $selectedSubject, settings: settings, transitionNamespace: transitionNamespace)
                    .navigationDestination(item: $selectedSubject) { subject in
                        ChatView(subject: subject)
                    }
            } else {
                ProgressView()
                    .onAppear {
                        modelContext.insert(UserSettings())
                    }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ChatMessage.self, UserSettings.self, StudySession.self, DailyActivity.self, Achievement.self], inMemory: true)
}
