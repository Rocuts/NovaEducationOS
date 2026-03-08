import SwiftData

// MARK: - Schema V1

/// Captures the initial schema for all NovaEducation @Model types.
/// Future releases that change any model must add a new SchemaVN and a migration stage.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
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
        ]
    }
}

// MARK: - Schema V2

/// First schema migration template. Mirror V1 to establish a stable state.
enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
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
        ]
    }
}

// MARK: - Migration Plan

/// Central migration plan for NovaEducation's SwiftData store.
/// Add new schema versions to `schemas` and corresponding `MigrationStage` entries to `stages`.
enum NovaEducationMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )
}
