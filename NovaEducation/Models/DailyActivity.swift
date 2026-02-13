import SwiftData
import Foundation

@Model
final class DailyActivity {
    // We store the date normalized to the start of the day to ensure uniqueness per day
    @Attribute(.unique) var date: Date
    var wasActive: Bool
    
    init(date: Date, wasActive: Bool = true) {
        self.date = Calendar.current.startOfDay(for: date)
        self.wasActive = wasActive
    }
}
