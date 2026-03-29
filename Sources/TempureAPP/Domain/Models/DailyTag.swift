import Foundation

public struct DailyTag: Identifiable, Equatable, Sendable {
    public var date: Date
    public var hasIntercourse: Bool
    public var hasMenstruation: Bool
    public var menstrualFlow: MenstrualFlow?
    public var updatedAt: Int64

    private static let idFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    public var id: String {
        Self.idFormatter.string(from: date)
    }

    public var hasAnyTag: Bool {
        hasIntercourse || hasMenstruation
    }

    public init(
        date: Date,
        hasIntercourse: Bool,
        hasMenstruation: Bool,
        menstrualFlow: MenstrualFlow?,
        updatedAt: Int64 = Int64(Date().timeIntervalSince1970)
    ) {
        self.date = date
        self.hasIntercourse = hasIntercourse
        self.hasMenstruation = hasMenstruation
        self.menstrualFlow = menstrualFlow
        self.updatedAt = updatedAt
    }
}
