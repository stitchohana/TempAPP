import Foundation

public protocol BBTRepository: Sendable {
    func saveTemperature(on date: Date, temperatureCelsius: Double) throws
    func fetchTemperature(on date: Date) throws -> BBTRecord?
    func fetchMonthlyRecords(containing date: Date) throws -> [BBTRecord]
    func fetchAllRecords() throws -> [BBTRecord]
    func saveWeight(on date: Date, weightKg: Double) throws
    func fetchWeight(on date: Date) throws -> WeightRecord?
    func fetchAllWeights() throws -> [WeightRecord]
    func saveTag(
        on date: Date,
        hasIntercourse: Bool,
        intercourseTime: IntercourseTime?,
        hasMenstruation: Bool,
        menstrualFlow: MenstrualFlow?,
        menstrualColor: MenstrualColor?,
        hasDysmenorrhea: Bool
    ) throws
    func fetchTag(on date: Date) throws -> DailyTag?
    func fetchMonthlyTags(containing date: Date) throws -> [DailyTag]
    func fetchAllTags() throws -> [DailyTag]
    func clearAllData() throws
    func updatePreferredUnit(_ unit: TemperatureUnit)
    func preferredUnit() -> TemperatureUnit
}
