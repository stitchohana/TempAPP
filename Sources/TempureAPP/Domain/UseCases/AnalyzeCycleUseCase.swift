import Foundation

public struct AnalyzeCycleUseCase: Sendable {
    private let dateService: DateService
    private let requiredRiseCelsius: Double
    private let tolerance: Double
    private let maxMissingDaysForTrigger: Int

    public init(
        dateService: DateService = .shared,
        requiredRiseCelsius: Double = 0.2,
        tolerance: Double = 0.05,
        maxMissingDaysForTrigger: Int = 1
    ) {
        self.dateService = dateService
        self.requiredRiseCelsius = requiredRiseCelsius
        self.tolerance = tolerance
        self.maxMissingDaysForTrigger = maxMissingDaysForTrigger
    }

    public func execute(records: [BBTRecord]) -> CycleAnalysis {
        let sorted = records.sorted { lhs, rhs in
            let lhsDay = dateService.dayStart(for: lhs.date)
            let rhsDay = dateService.dayStart(for: rhs.date)
            if lhsDay == rhsDay {
                return lhs.updatedAt < rhs.updatedAt
            }
            return lhsDay < rhsDay
        }
        guard
            let start = sorted.first?.date,
            let end = sorted.last?.date
        else {
            return CycleAnalysis()
        }

        let dateSeries = buildDateSeries(start: dateService.dayStart(for: start), end: dateService.dayStart(for: end))
        let valueMap = sorted.reduce(into: [Date: Double]()) { result, record in
            result[dateService.dayStart(for: record.date)] = record.temperatureCelsius
        }
        let values = dateSeries.map { valueMap[$0] }

        guard values.count >= 9 else {
            return CycleAnalysis()
        }

        for index in 6..<(values.count - 2) {
            let baselineWindow = Array(values[(index - 6)..<index])
            let baselineData = baselineWindow.compactMap { $0 }
            let baselineMissing = baselineWindow.count - baselineData.count

            guard baselineMissing <= maxMissingDaysForTrigger, baselineData.count >= 5 else {
                continue
            }

            let baselineAverage = baselineData.reduce(0, +) / Double(baselineData.count)
            let threshold = baselineAverage + requiredRiseCelsius

            let risingWindow = Array(values[index...(index + 2)])
            let risingData = risingWindow.compactMap { $0 }
            let risingMissing = risingWindow.count - risingData.count

            guard risingMissing <= maxMissingDaysForTrigger, risingData.count >= 2 else {
                continue
            }

            let risingValid = risingData.allSatisfy { $0 >= (threshold - tolerance) }
            guard risingValid else {
                continue
            }

            let highDays = countConsecutiveHighDays(
                from: index,
                values: values,
                coverline: baselineAverage
            )

            return CycleAnalysis(
                coverline: baselineAverage,
                triggerDate: dateSeries[index],
                highTemperatureDays: highDays,
                isPregnancySignal: highDays >= 15
            )
        }

        return CycleAnalysis()
    }

    private func countConsecutiveHighDays(from startIndex: Int, values: [Double?], coverline: Double) -> Int {
        var count = 0
        for value in values[startIndex...] {
            guard let value else {
                break
            }
            if value >= (coverline - tolerance) {
                count += 1
            } else {
                break
            }
        }
        return count
    }

    private func buildDateSeries(start: Date, end: Date) -> [Date] {
        var series: [Date] = []
        var cursor = start

        while cursor <= end {
            series.append(cursor)
            cursor = dateService.calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            if series.count > 5000 {
                break
            }
        }
        return series
    }
}
