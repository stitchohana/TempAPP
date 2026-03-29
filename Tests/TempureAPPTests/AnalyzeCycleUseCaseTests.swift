import Foundation
import Testing
@testable import TempureAPP

@Suite("Cycle Analysis")
struct AnalyzeCycleUseCaseTests {
    @Test("Coverline should trigger when 6+3 rule is met")
    func coverlineTrigger() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let calendar = Calendar(identifier: .gregorian)
        var records: [BBTRecord] = []

        let baseline = [36.40, 36.42, 36.41, 36.39, 36.44, 36.43]
        let rising = [36.67, 36.68, 36.71]
        let values = baseline + rising

        for (index, value) in values.enumerated() {
            let day = calendar.date(byAdding: .day, value: index, to: start) ?? start
            records.append(BBTRecord(date: day, temperatureCelsius: value))
        }

        let useCase = AnalyzeCycleUseCase(dateService: DateService())
        let analysis = useCase.execute(records: records)

        #expect(analysis.coverline != nil)
        #expect(analysis.highTemperatureDays == 3)
        #expect(analysis.isPregnancySignal == false)
    }

    @Test("Unit conversion should preserve values")
    func unitConversion() {
        let fahrenheit = UnitConversionService.toDisplayValue(celsius: 36.5, unit: .fahrenheit)
        #expect(abs(fahrenheit - 97.7) < 0.001)

        let celsius = UnitConversionService.toStoredCelsius(value: 97.7, from: .fahrenheit)
        #expect(abs(celsius - 36.5) < 0.001)
    }
}
