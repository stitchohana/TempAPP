import Foundation

public protocol BBTRepository: Sendable {
    func saveTemperature(on date: Date, temperatureCelsius: Double) throws
    func fetchTemperature(on date: Date) throws -> BBTRecord?
    func fetchMonthlyRecords(containing date: Date) throws -> [BBTRecord]
    func fetchAllRecords() throws -> [BBTRecord]
    func updatePreferredUnit(_ unit: TemperatureUnit)
    func preferredUnit() -> TemperatureUnit
}
