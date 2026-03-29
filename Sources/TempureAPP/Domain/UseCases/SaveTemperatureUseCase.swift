import Foundation

public enum SaveTemperatureError: Error {
    case invalidRange
}

public struct SaveTemperatureUseCase: Sendable {
    private let repository: BBTRepository
    private let dateService: DateService

    public init(repository: BBTRepository, dateService: DateService = .shared) {
        self.repository = repository
        self.dateService = dateService
    }

    public func execute(date: Date, value: Double, unit: TemperatureUnit) throws {
        let celsius = UnitConversionService.toStoredCelsius(value: value, from: unit)
        let rounded = (celsius * 100).rounded() / 100
        guard rounded >= 30.0, rounded <= 45.0 else {
            throw SaveTemperatureError.invalidRange
        }
        try repository.saveTemperature(on: dateService.dayStart(for: date), temperatureCelsius: rounded)
    }
}
