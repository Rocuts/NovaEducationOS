import Foundation
import SwiftData
import os

/// Actor responsible for handling background session initialization tasks
/// to prevent Main Thread hangs.
actor BackgroundSessionManager {
    static let shared = BackgroundSessionManager()

    private nonisolated let logger = Logger(subsystem: "com.nova.education", category: "BackgroundSession")

    private init() {}

    func initializeSession(container: ModelContainer) async {
        await MainActor.run {
            let context = ModelContext(container)
            context.autosaveEnabled = false

            // 1. Update Daily Activity
            let today = Calendar.current.startOfDay(for: Date())
            let descriptor = FetchDescriptor<DailyActivity>(predicate: #Predicate { $0.date == today })

            if (try? context.fetch(descriptor).first) == nil {
                let newActivity = DailyActivity(date: Date(), wasActive: true)
                context.insert(newActivity)
            }

            // 2. Initialize achievements if needed (Seeding)
            let achDescriptor = FetchDescriptor<Achievement>()
            if let existing = try? context.fetch(achDescriptor) {
                let existingIds = Set(existing.map { $0.id })

                for type in AchievementType.allCases {
                    if !existingIds.contains(type.rawValue) {
                        let achievement = Achievement(
                            id: type.rawValue,
                            isUnlocked: false,
                            progress: 0,
                            targetValue: type.targetValue
                        )
                        context.insert(achievement)
                    }
                }
            }

            // 3. Clean up orphaned and old generated images
            cleanupGeneratedImages(context: context)

            do {
                try context.save()
            } catch {
                logger.error("Failed to save: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Image Cleanup

    /// Deletes orphaned images not referenced by any ChatMessage and images older than 30 days.
    @MainActor
    private func cleanupGeneratedImages(context: ModelContext) {
        let imagesDir = URL.documentsDirectory.appending(path: "GeneratedImages")
        let fm = FileManager.default

        guard fm.fileExists(atPath: imagesDir.path()) else { return }

        guard let files = try? fm.contentsOfDirectory(
            at: imagesDir,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }

        guard !files.isEmpty else { return }

        // Collect all image URL strings referenced by ChatMessages
        let msgDescriptor = FetchDescriptor<ChatMessage>()
        let messages = (try? context.fetch(msgDescriptor)) ?? []
        let referencedFilenames = Self.referencedImageFilenames(from: messages)

        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        for fileURL in files {
            let isOrphaned = !referencedFilenames.contains(fileURL.lastPathComponent)

            var isOld = false
            if let attrs = try? fm.attributesOfItem(atPath: fileURL.path()),
               let creationDate = attrs[.creationDate] as? Date {
                isOld = creationDate < thirtyDaysAgo
            }

            if isOrphaned || isOld {
                try? fm.removeItem(at: fileURL)
            }
        }
    }

    static func referencedImageFilenames(from messages: [ChatMessage]) -> Set<String> {
        Set(messages.compactMap { message -> String? in
            guard let rawReference = message.imageURLString else { return nil }
            let normalized = normalizedImageFilename(from: rawReference)
            return normalized.isEmpty ? nil : normalized
        })
    }

    static func normalizedImageFilename(from rawReference: String) -> String {
        if rawReference.hasPrefix("file://"), let url = URL(string: rawReference) {
            return url.lastPathComponent
        }
        return URL(fileURLWithPath: rawReference).lastPathComponent
    }
}
