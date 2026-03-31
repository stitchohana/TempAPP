import Foundation

public struct WeightRecord: Identifiable, Equatable, Sendable {
    public var date: Date
    public var weightKg: Double
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

    public init(date: Date, weightKg: Double, updatedAt: Int64 = Int64(Date().timeIntervalSince1970)) {
        self.date = date
        self.weightKg = weightKg
        self.updatedAt = updatedAt
    }
}
