import Testing
import SwiftData
@testable import NovaEducation

@Suite("ChatViewModel Tests")
@MainActor
struct ChatViewModelTests {

    @Test("Initialization sets subject and default state")
    func initialization() {
        let viewModel = ChatViewModel(
            subject: .science,
            studentName: "TestStudent",
            educationLevel: .primary
        )

        #expect(viewModel.subject == .science)
        #expect(!viewModel.isGenerating)
        #expect(viewModel.currentInput == "")
    }

    @Test("Reconfigure preserves in-flight state when identity unchanged")
    func reconfigurePreservesState() {
        let viewModel = ChatViewModel(
            subject: .social,
            studentName: "Alice",
            educationLevel: .secondary
        )

        // Simulate in-flight state
        viewModel.isGenerating = true
        viewModel.currentInput = "Hello"

        // Reconfigure with SAME identity
        viewModel.reconfigure(studentName: "Alice", educationLevel: .secondary)

        // State should be preserved
        #expect(viewModel.isGenerating)
        #expect(viewModel.currentInput == "Hello")
    }

    @Test("Gamification state dismissals work correctly")
    func gamificationStateDismissals() {
        let viewModel = ChatViewModel(subject: .math)

        viewModel.didLevelUp = true
        viewModel.showLevelUpCelebration = true
        viewModel.previousLevel = 1
        viewModel.dismissLevelUpCelebration()

        #expect(!viewModel.didLevelUp)
        #expect(!viewModel.showLevelUpCelebration)
        #expect(viewModel.previousLevel == 0)

        viewModel.showXPToast = true
        viewModel.dismissXPToast()
        #expect(!viewModel.showXPToast)

        viewModel.errorMessage = "Error"
        viewModel.errorRecoverySuggestion = "Try again"
        viewModel.dismissError()
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.errorRecoverySuggestion == nil)
    }

    @Test("Reconfigure updates identity when changed")
    func reconfigureUpdatesIdentity() {
        let viewModel = ChatViewModel(
            subject: .social,
            studentName: "Alice",
            educationLevel: .secondary
        )

        viewModel.currentInput = "Pregunta pendiente"
        viewModel.isGenerating = true

        viewModel.reconfigure(studentName: "Bob", educationLevel: .university)

        #expect(viewModel.currentIdentity.studentName == "Bob")
        #expect(viewModel.currentIdentity.educationLevel == .university)
        #expect(viewModel.currentInput == "Pregunta pendiente")
        #expect(viewModel.isGenerating)
    }

    @Test("Daily message count includes first_of_day transactions")
    func dailyMessageCountIncludesFirstOfDay() throws {
        let context = try makeXPModelContext()
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)

        let messageTx = XPTransaction(baseAmount: 5, source: .message, subjectId: "math")
        messageTx.timestamp = startOfDay.addingTimeInterval(60)
        context.insert(messageTx)

        let firstOfDayTx = XPTransaction(baseAmount: 5, source: .firstOfDay, subjectId: "math")
        firstOfDayTx.timestamp = startOfDay.addingTimeInterval(120)
        context.insert(firstOfDayTx)

        let nonMessageTx = XPTransaction(baseAmount: 25, source: .dailyGoal, subjectId: "math")
        nonMessageTx.timestamp = startOfDay.addingTimeInterval(180)
        context.insert(nonMessageTx)

        let yesterdayTx = XPTransaction(baseAmount: 5, source: .message, subjectId: "math")
        yesterdayTx.timestamp = Calendar.current.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay
        context.insert(yesterdayTx)

        let count = ChatViewModel.messageTransactionCountToday(in: context, now: now)
        #expect(count == 2)
        #expect(ChatViewModel.xpSourceForMessageCount(count) == .message)
    }

    @Test("First message source is first_of_day when no daily message transactions")
    func firstMessageSourceWhenNoTransactions() {
        #expect(ChatViewModel.xpSourceForMessageCount(0) == .firstOfDay)
    }

    private func makeXPModelContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: XPTransaction.self, configurations: config)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }
}
