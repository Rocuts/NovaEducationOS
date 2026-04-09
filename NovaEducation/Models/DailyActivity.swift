import SwiftData
import Foundation

@Model
final class DailyActivity {
    #Index<DailyActivity>([\.date])

    // We store the date normalized to the start of the day to ensure uniqueness per day
    @Attribute(.unique) var date: Date
    var wasActive: Bool
    
    init(date: Date, wasActive: Bool = true) {
        self.date = Calendar.current.startOfDay(for: date)
        self.wasActive = wasActive
    }

    /// Calculates the current streak from a list of activities sorted by date descending.
    static func currentStreak(from activities: [DailyActivity]) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var expectedDate = calendar.startOfDay(for: Date())

        for activity in activities {
            let activityDate = calendar.startOfDay(for: activity.date)

            if activityDate == expectedDate && activity.wasActive {
                streak += 1
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
            } else if activityDate < expectedDate {
                break
            }
        }

        return streak
    }
}
