import Testing
import SwiftData
@testable import NovaEducation

@MainActor
@Suite("Student Memory Integrity Tests")
struct StudentMemoryServiceTests {

    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema([StudentKnowledge.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("Student Memory updates mastery exactly on subject scopes")
    func testSaveAndExtractKnowledge() throws {
        let container = try createTestContainer()
        let memoryService = StudentMemoryService.shared

        // Ingesting first knowledge domain
        let observation1 = "The student struggles with organic chemistry chains."
        memoryService.saveMemory(concept: observation1, subject: .chemistry, context: container.mainContext)

        // Verifying persistence and association scope
        let chemScope = memoryService.getRelevantMemories(for: .chemistry, context: container.mainContext)
        #expect(chemScope.contains { $0.fact == observation1 }, "Memory Service should retain targeted concepts on matching topics")

        // C-16 Validating Scope Segregation Integrity
        let mathScope = memoryService.getRelevantMemories(for: .math, context: container.mainContext)
        #expect(mathScope.isEmpty, "Memory Service must segregate memory retrieval based strictly on domain Enum / ID")
    }

    @Test("Memory update boundaries assert valid range constraints")
    func testMasteryScoping() throws {
        let container = try createTestContainer()
        let memoryService = StudentMemoryService.shared
        let concept = "Pythagorean Theorem understanding"

        memoryService.saveMemory(concept: concept, subject: .math, context: container.mainContext)
        let knowledgeModel = memoryService.getRelevantMemories(for: .math, context: container.mainContext).first!

        #expect(knowledgeModel.masteryLevel == 0.1, "Default base initialization should be 0.1")

        // Test Valid Growth
        memoryService.updateMastery(conceptId: knowledgeModel.id, success: true, context: container.mainContext)
        #expect(knowledgeModel.masteryLevel > 0.1, "Mastery grows on success")

        // Test Negative Clamping (C-16 model validation)
        for _ in 0..<15 {
            memoryService.updateMastery(conceptId: knowledgeModel.id, success: false, context: container.mainContext)
        }
        #expect(knowledgeModel.masteryLevel >= 0.0, "Mastery must never underflow below 0.0")

        // Test Positive Clamping
        for _ in 0..<30 {
            memoryService.updateMastery(conceptId: knowledgeModel.id, success: true, context: container.mainContext)
        }
        #expect(knowledgeModel.masteryLevel <= 1.0, "Mastery must never overflow above 1.0")
    }

    @Test("Robustness: Graceful degrade on missing context references")
    func testGracefulContextFailures() {
        let memoryService = StudentMemoryService.shared

        // Requesting concepts with completely uninitialized Context -> returns defaults arrays fallback
        let fakeFailContext = try! ModelContainer(for: Schema([UserSettings.self]), configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext
        
        // This simulates a context isolated namespace (where StudentKnowledge schema doesn't exist)
        let result = memoryService.getRelevantMemories(for: .math, context: fakeFailContext)
        #expect(result.isEmpty, "Retrieving unknown schemas must gracefully failback instead of asserting crashes")
    }
}
