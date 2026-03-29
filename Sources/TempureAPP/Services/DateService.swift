import Foundation

public final class DateService: Sendable {
    public static let shared = DateService()

    public let calendar: Calendar
    private let storageFormatter: DateFormatter

    public init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        self.storageFormatter = formatter
    }

    public func dayStart(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    public func storageKey(for date: Date) -> String {
        storageFormatter.string(from: dayStart(for: date))
    }

    public func date(from storageKey: String) -> Date? {
        storageFormatter.date(from: storageKey)
    }

    public func monthRange(containing date: Date) -> DateInterval {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? dayStart(for: date)
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        return DateInterval(start: monthStart, end: nextMonth)
    }

    public func daysInMonth(containing date: Date) -> [Date] {
        let range = monthRange(containing: date)
        var days: [Date] = []
        var cursor = range.start
        while cursor < range.end {
            days.append(cursor)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? range.end
        }
        return days
    }
}
