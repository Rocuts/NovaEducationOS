import Testing
@testable import NovaEducation

@Suite("BackgroundSessionManager Tests")
struct BackgroundSessionManagerTests {

    @Test("Normalize image filename from file URL, absolute path, and plain filename")
    func normalizeImageFilename() {
        let fileURLReference = "file:///var/mobile/Containers/Data/Application/ABC/Documents/GeneratedImages/atom.png"
        let absolutePathReference = "/Users/test/Documents/GeneratedImages/molecule.png"
        let plainFilenameReference = "planet.png"

        #expect(BackgroundSessionManager.normalizedImageFilename(from: fileURLReference) == "atom.png")
        #expect(BackgroundSessionManager.normalizedImageFilename(from: absolutePathReference) == "molecule.png")
        #expect(BackgroundSessionManager.normalizedImageFilename(from: plainFilenameReference) == "planet.png")
    }

    @Test("Referenced image filenames are normalized before orphan cleanup comparison")
    func referencedImageFilenamesNormalization() {
        let messageA = ChatMessage(role: .assistant, content: "A", subjectId: "science")
        messageA.imageURLString = "file:///var/mobile/Containers/Data/Application/ABC/Documents/GeneratedImages/cell.png"

        let messageB = ChatMessage(role: .assistant, content: "B", subjectId: "science")
        messageB.imageURLString = "/tmp/GeneratedImages/dna.png"

        let messageC = ChatMessage(role: .assistant, content: "C", subjectId: "science")
        messageC.imageURLString = "heart.png"

        let messageD = ChatMessage(role: .assistant, content: "D", subjectId: "science")
        messageD.imageURLString = nil

        let filenames = BackgroundSessionManager.referencedImageFilenames(from: [messageA, messageB, messageC, messageD])

        #expect(filenames == Set(["cell.png", "dna.png", "heart.png"]))
    }
}
