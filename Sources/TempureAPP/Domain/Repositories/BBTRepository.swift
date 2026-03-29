import Foundation

public protocol BBTRepository: Sendable {
    func saveTemperature(on date: Date, temperatureCelsius: Double) throws
    func fetchTemperature(on date: Date) throws -> BBTRecord?
    func fetchMonthlyRecords(containing date: Date) throws -> [BBTRecord]
    func fetchAllRecords() throws -> [BBTRecord]
    func saveTag(on date: Date, hasIntercourse: Bool, hasMenstruation: Bool, menstrualFlow: MenstrualFlow?) throws
    func fetchTag(on date: Date) throws -> DailyTag?
    func fetchMonthlyTags(containing date: Date) throws -> [DailyTag]
    func fetchAllTags() throws -> [DailyTag]
    func updatePreferredUnit(_ unit: TemperatureUnit)
    func preferredUnit() -> TemperatureUnit
}
