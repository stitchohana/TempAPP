import Foundation

public struct BBTRecordRow: Sendable {
    public var date: String
    public var temperature: Double
    public var updatedAt: Int64

    public init(date: String, temperature: Double, updatedAt: Int64) {
        self.date = date
        self.temperature = temperature
        self.updatedAt = updatedAt
    }
}
