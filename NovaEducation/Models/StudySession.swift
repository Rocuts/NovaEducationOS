import SwiftData
import Foundation

@Model
final class StudySession {
    #Index<StudySession>([\.startTime], [\.subjectId])

    var id: UUID
    var startTime: Date
    var endTime: Date
    var subjectId: String
    
    init(startTime: Date, endTime: Date, subjectId: String) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.subjectId = subjectId
    }
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}
