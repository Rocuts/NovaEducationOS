import Testing
@testable import NovaEducation

@Suite("PlayerLevel Tests")
struct PlayerLevelTests {

    // MARK: - xpRequired

    @Test("XP required for level 1 is 100")
    func xpRequiredLevel1() {
        #expect(PlayerLevel.xpRequired(forLevel: 1) == 100)
    }

    @Test("XP required for level 2 is 150 (100 * 1.5)")
    func xpRequiredLevel2() {
        #expect(PlayerLevel.xpRequired(forLevel: 2) == 150)
    }

    @Test("XP required for level 3 is 225 (100 * 1.5^2)")
    func xpRequiredLevel3() {
        #expect(PlayerLevel.xpRequired(forLevel: 3) == 225)
    }

    @Test("XP required for level 0 or negative is 0")
    func xpRequiredEdgeCases() {
        #expect(PlayerLevel.xpRequired(forLevel: 0) == 0)
        #expect(PlayerLevel.xpRequired(forLevel: -1) == 0)
    }

    // MARK: - totalXPRequired

    @Test("Total XP for level 1 is 0 (start of game)")
    func totalXPLevel1() {
        #expect(PlayerLevel.totalXPRequired(forLevel: 1) == 0)
    }

    @Test("Total XP for level 2 is 100 (need level 1's XP)")
    func totalXPLevel2() {
        #expect(PlayerLevel.totalXPRequired(forLevel: 2) == 100)
    }

    @Test("Total XP for level 3 is 250 (100 + 150)")
    func totalXPLevel3() {
        #expect(PlayerLevel.totalXPRequired(forLevel: 3) == 250)
    }

    // MARK: - level(fromTotalXP:)

    @Test("0 XP is level 1")
    func levelFrom0XP() {
        #expect(PlayerLevel.level(fromTotalXP: 0) == 1)
    }

    @Test("99 XP is still level 1")
    func levelFrom99XP() {
        #expect(PlayerLevel.level(fromTotalXP: 99) == 1)
    }

    @Test("100 XP is level 2")
    func levelFrom100XP() {
        #expect(PlayerLevel.level(fromTotalXP: 100) == 2)
    }

    @Test("249 XP is still level 2")
    func levelFrom249XP() {
        #expect(PlayerLevel.level(fromTotalXP: 249) == 2)
    }

    @Test("250 XP is level 3")
    func levelFrom250XP() {
        #expect(PlayerLevel.level(fromTotalXP: 250) == 3)
    }

    @Test("Large XP produces high level")
    func levelFromLargeXP() {
        let level = PlayerLevel.level(fromTotalXP: 100_000)
        #expect(level > 10)
    }

    // MARK: - progress

    @Test("Progress at 0 XP is 0")
    func progressAt0XP() {
        let progress = PlayerLevel.progress(forTotalXP: 0)
        #expect(progress >= 0.0 && progress <= 1.0)
        #expect(progress == 0.0)
    }

    @Test("Progress at 50 XP is 0.5 (halfway through level 1)")
    func progressAt50XP() {
        let progress = PlayerLevel.progress(forTotalXP: 50)
        #expect(abs(progress - 0.5) < 0.01)
    }

    @Test("Progress at level boundary is 0")
    func progressAtLevelBoundary() {
        // At exactly 100 XP, we're at level 2 with 0 progress
        let progress = PlayerLevel.progress(forTotalXP: 100)
        #expect(abs(progress - 0.0) < 0.01)
    }

    @Test("Progress is always between 0 and 1")
    func progressBounds() {
        for xp in stride(from: 0, through: 5000, by: 100) {
            let progress = PlayerLevel.progress(forTotalXP: xp)
            #expect(progress >= 0.0 && progress <= 1.0, "Progress out of bounds at XP: \(xp)")
        }
    }

    // MARK: - xpToNextLevel

    @Test("XP to next level from 0 is 100")
    func xpToNextLevelFrom0() {
        #expect(PlayerLevel.xpToNextLevel(fromTotalXP: 0) == 100)
    }

    @Test("XP to next level from 50 is 50")
    func xpToNextLevelFrom50() {
        #expect(PlayerLevel.xpToNextLevel(fromTotalXP: 50) == 50)
    }

    // MARK: - title

    @Test("Level titles follow expected progression")
    func titles() {
        #expect(PlayerLevel.title(forLevel: 1) == "Novato")
        #expect(PlayerLevel.title(forLevel: 5) == "Explorador")
        #expect(PlayerLevel.title(forLevel: 10) == "Estudiante")
        #expect(PlayerLevel.title(forLevel: 15) == "Experto")
        #expect(PlayerLevel.title(forLevel: 20) == "Maestro")
        #expect(PlayerLevel.title(forLevel: 30) == "Leyenda")
    }
}
