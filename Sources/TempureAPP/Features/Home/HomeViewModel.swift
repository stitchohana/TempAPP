#if canImport(SwiftUI)
import Foundation
import SwiftUI

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public private(set) var state: HomeState
    @Published public var inputValue: Double = 36.6
    @Published public var inputWeightValue: Double = 55.0
    @Published public var tagHasIntercourse: Bool = false
    @Published public var tagIntercourseTime: IntercourseTime? = nil
    @Published public var tagHasMenstruation: Bool = false
    @Published public var tagMenstrualFlow: MenstrualFlow? = nil
    @Published public var tagMenstrualColor: MenstrualColor? = nil
    @Published public var tagHasDysmenorrhea: Bool = false
    @Published public var hoverRecord: BBTRecord?
    @Published public var errorMessage: String?

    private let repository: BBTRepository
    private let dateService: DateService
    private let haptics: HapticsService
    private let saveTemperatureUseCase: SaveTemperatureUseCase
    private let getMonthlyRecordsUseCase: GetMonthlyRecordsUseCase
    private let analyzeCycleUseCase: AnalyzeCycleUseCase
    private let inputRangeCelsius: ClosedRange<Double> = 35.0...40.0
    private let inputDefaultCelsius: Double = 36.6
    private let weightRangeKg: ClosedRange<Double> = 30.0...150.0
    private let weightDefaultKg: Double = 55.0
    private var hasAlignedMonthOnLaunch = false
    private let defaults = UserDefaults.standard
    private let lastTemperatureCelsiusKey = "last_input_temperature_celsius"
    private let lastWeightKgKey = "last_input_weight_kg"

    public init(container: AppContainer) {
        let today = container.dateService.dayStart(for: Date())
        self.repository = container.repository
        self.dateService = container.dateService
        self.haptics = container.haptics
        self.saveTemperatureUseCase = SaveTemperatureUseCase(repository: container.repository, dateService: container.dateService)
        self.getMonthlyRecordsUseCase = GetMonthlyRecordsUseCase(repository: container.repository)
        self.analyzeCycleUseCase = AnalyzeCycleUseCase(dateService: container.dateService)
        self.state = HomeState(
            displayMonth: today,
            selectedDate: today,
            unit: container.repository.preferredUnit()
        )
    }

    public var recordsByDateKey: [String: BBTRecord] {
        state.monthlyRecords.reduce(into: [:]) { result, record in
            let key = dateService.storageKey(for: record.date)
            if let existing = result[key], existing.updatedAt > record.updatedAt {
                return
            }
            result[key] = record
        }
    }

    public var tagsByDateKey: [String: DailyTag] {
        state.monthlyTags.reduce(into: [:]) { result, tag in
            let key = dateService.storageKey(for: tag.date)
            if let existing = result[key], existing.updatedAt > tag.updatedAt {
                return
            }
            result[key] = tag
        }
    }

    public var chartRecordsByDateKey: [String: BBTRecord] {
        state.chartRecords.reduce(into: [:]) { result, record in
            let key = dateService.storageKey(for: record.date)
            if let existing = result[key], existing.updatedAt > record.updatedAt {
                return
            }
            result[key] = record
        }
    }

    public var chartTagsByDateKey: [String: DailyTag] {
        state.chartTags.reduce(into: [:]) { result, tag in
            let key = dateService.storageKey(for: tag.date)
            if let existing = result[key], existing.updatedAt > tag.updatedAt {
                return
            }
            result[key] = tag
        }
    }

    public var weightRecordsByDateKey: [String: WeightRecord] {
        state.allWeightRecords.reduce(into: [:]) { result, record in
            let key = dateService.storageKey(for: record.date)
            if let existing = result[key], existing.updatedAt > record.updatedAt {
                return
            }
            result[key] = record
        }
    }

    public var chartWeightRecordsByDateKey: [String: WeightRecord] {
        state.chartWeightRecords.reduce(into: [:]) { result, record in
            let key = dateService.storageKey(for: record.date)
            if let existing = result[key], existing.updatedAt > record.updatedAt {
                return
            }
            result[key] = record
        }
    }

    public var inputRangeForCurrentUnit: ClosedRange<Double> {
        let lower = UnitConversionService.toDisplayValue(celsius: inputRangeCelsius.lowerBound, unit: state.unit)
        let upper = UnitConversionService.toDisplayValue(celsius: inputRangeCelsius.upperBound, unit: state.unit)
        return roundToTenth(lower)...roundToTenth(upper)
    }

    public var inputWeightRangeKg: ClosedRange<Double> {
        weightRangeKg
    }

    public func onAppear() {
        alignDisplayMonthToLatestRecordOnFirstLaunch()
        reloadData()
    }

    public func showPreviousMonth() {
        withAnimation(.easeInOut(duration: TempureMotion.medium)) {
            state.displayMonth = dateService.calendar.date(byAdding: .month, value: -1, to: state.displayMonth) ?? state.displayMonth
            state.selectedDate = dateService.monthRange(containing: state.displayMonth).start
        }
        haptics.selection()
        reloadData()
    }

    public func showNextMonth() {
        withAnimation(.easeInOut(duration: TempureMotion.medium)) {
            state.displayMonth = dateService.calendar.date(byAdding: .month, value: 1, to: state.displayMonth) ?? state.displayMonth
            state.selectedDate = dateService.monthRange(containing: state.displayMonth).start
        }
        haptics.selection()
        reloadData()
    }

    public func selectDate(_ date: Date) {
        withAnimation(.easeInOut(duration: TempureMotion.short)) {
            state.selectedDate = dateService.dayStart(for: date)
        }
        haptics.selection()
        let key = dateService.storageKey(for: state.selectedDate)
        hoverRecord = chartRecordsByDateKey[key] ?? recordsByDateKey[key]
    }

    public func updateChartRange(_ range: ChartRange) {
        guard state.chartRange != range else { return }
        state.chartRange = range
        haptics.selection()
        rebuildChartData()
    }

    public func presentInput() {
        let key = dateService.storageKey(for: state.selectedDate)
        if let record = recordsByDateKey[key] {
            let display = UnitConversionService.toDisplayValue(celsius: record.temperatureCelsius, unit: state.unit)
            inputValue = roundToTenth(display)
        } else {
            let rememberedCelsius = defaults.object(forKey: lastTemperatureCelsiusKey) as? Double
            let fallbackCelsius = rememberedCelsius ?? inputDefaultCelsius
            let defaultValue = UnitConversionService.toDisplayValue(celsius: fallbackCelsius, unit: state.unit)
            inputValue = roundToTenth(defaultValue)
        }
        state.isInputSheetPresented = true
        haptics.light()
    }

    public func presentWeightInput() {
        let key = dateService.storageKey(for: state.selectedDate)
        if let record = weightRecordsByDateKey[key] {
            inputWeightValue = roundToTenth(record.weightKg)
        } else {
            let remembered = defaults.object(forKey: lastWeightKgKey) as? Double
            inputWeightValue = roundToTenth(remembered ?? weightDefaultKg)
        }
        state.isWeightSheetPresented = true
        haptics.light()
    }

    public func dismissInput() {
        state.isInputSheetPresented = false
    }

    public func dismissWeightInput() {
        state.isWeightSheetPresented = false
    }

    public func saveInput() {
        do {
            let value = clampToInputRange(roundToTenth(inputValue))
            try saveTemperatureUseCase.execute(date: state.selectedDate, value: value, unit: state.unit)
            let celsius = UnitConversionService.toStoredCelsius(value: value, from: state.unit)
            defaults.set(celsius, forKey: lastTemperatureCelsiusKey)
            haptics.success()
            state.isInputSheetPresented = false
            reloadData()
            hoverRecord = recordsByDateKey[dateService.storageKey(for: state.selectedDate)]
        } catch {
            errorMessage = "保存失败，请重试。"
        }
    }

    public func saveWeightInput() {
        do {
            let value = min(max(roundToTenth(inputWeightValue), weightRangeKg.lowerBound), weightRangeKg.upperBound)
            try repository.saveWeight(on: state.selectedDate, weightKg: value)
            defaults.set(value, forKey: lastWeightKgKey)
            haptics.success()
            state.isWeightSheetPresented = false
            reloadData()
        } catch {
            errorMessage = "体重保存失败，请重试。"
        }
    }

    public func presentTagInput() {
        let key = dateService.storageKey(for: state.selectedDate)
        if let existing = tagsByDateKey[key] {
            tagHasIntercourse = existing.hasIntercourse
            tagIntercourseTime = existing.intercourseTime
            tagHasMenstruation = existing.hasMenstruation
            tagMenstrualFlow = existing.menstrualFlow
            tagMenstrualColor = existing.menstrualColor
            tagHasDysmenorrhea = existing.hasDysmenorrhea
        } else {
            tagHasIntercourse = false
            tagIntercourseTime = nil
            tagHasMenstruation = false
            tagMenstrualFlow = nil
            tagMenstrualColor = nil
            tagHasDysmenorrhea = false
        }
        state.isTagSheetPresented = true
        haptics.light()
    }

    public func dismissTagInput() {
        state.isTagSheetPresented = false
    }

    public func saveTagInput() {
        do {
            let flow = tagHasMenstruation ? tagMenstrualFlow : nil
            try repository.saveTag(
                on: state.selectedDate,
                hasIntercourse: tagHasIntercourse,
                intercourseTime: tagIntercourseTime,
                hasMenstruation: tagHasMenstruation,
                menstrualFlow: flow,
                menstrualColor: tagHasMenstruation ? tagMenstrualColor : nil,
                hasDysmenorrhea: tagHasMenstruation ? tagHasDysmenorrhea : false
            )
            haptics.success()
            state.isTagSheetPresented = false
            reloadData()
        } catch {
            errorMessage = "标签保存失败，请重试。"
        }
    }

    public func updateUnit(_ unit: TemperatureUnit) {
        let previousUnit = state.unit
        let currentCelsius = UnitConversionService.toStoredCelsius(value: inputValue, from: previousUnit)
        state.unit = unit
        if state.isInputSheetPresented {
            let displayValue = UnitConversionService.toDisplayValue(celsius: currentCelsius, unit: unit)
            inputValue = clampToInputRange(roundToTenth(displayValue))
        }
        repository.updatePreferredUnit(unit)
        haptics.selection()
    }

    public func valueForDisplay(_ record: BBTRecord) -> Double {
        UnitConversionService.toDisplayValue(celsius: record.temperatureCelsius, unit: state.unit)
    }

    public func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = dateService.calendar
        formatter.locale = Locale.current
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    public func formatDisplay(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func roundToTenth(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    private func clampToInputRange(_ value: Double) -> Double {
        let bounds = inputRangeForCurrentUnit
        return min(max(value, bounds.lowerBound), bounds.upperBound)
    }

    private func reloadData() {
        do {
            state.monthlyRecords = try getMonthlyRecordsUseCase.execute(containing: state.displayMonth)
            state.monthlyTags = try repository.fetchMonthlyTags(containing: state.displayMonth)
            let allRecords = try repository.fetchAllRecords()
            let allWeights = try repository.fetchAllWeights()
            let allTags = try repository.fetchAllTags()
            state.allWeightRecords = allWeights
            let analysis = analyzeCycleUseCase.execute(records: allRecords)
            state.coverline = analysis.coverline
            state.highTempDays = analysis.highTemperatureDays
            state.isPregnancySignal = analysis.isPregnancySignal
            rebuildChartData(allRecords: allRecords, allWeights: allWeights, allTags: allTags)
            errorMessage = nil
        } catch {
            errorMessage = "读取数据失败，请稍后重试。"
        }
    }

    private func rebuildChartData(allRecords: [BBTRecord]? = nil, allWeights: [WeightRecord]? = nil, allTags: [DailyTag]? = nil) {
        let records: [BBTRecord]
        let weights: [WeightRecord]
        let tags: [DailyTag]

        if let allRecords, let allWeights, let allTags {
            records = allRecords
            weights = allWeights
            tags = allTags
        } else {
            records = (try? repository.fetchAllRecords()) ?? []
            weights = (try? repository.fetchAllWeights()) ?? []
            tags = (try? repository.fetchAllTags()) ?? []
        }

        let end = chartEndDate(records: records, weights: weights, tags: tags)
        let offset = state.chartRange.rawValue - 1
        let start = dateService.calendar.date(byAdding: .day, value: -offset, to: end) ?? end
        let upper = dateService.calendar.date(byAdding: .day, value: 1, to: end) ?? end

        var days: [Date] = []
        var cursor = start
        while cursor <= end {
            days.append(cursor)
            cursor = dateService.calendar.date(byAdding: .day, value: 1, to: cursor) ?? end.addingTimeInterval(1)
        }
        state.chartDates = days

        state.chartRecords = records.filter { record in
            let day = dateService.dayStart(for: record.date)
            return day >= start && day < upper
        }
        state.chartWeightRecords = weights.filter { record in
            let day = dateService.dayStart(for: record.date)
            return day >= start && day < upper
        }
        state.chartTags = tags.filter { tag in
            let day = dateService.dayStart(for: tag.date)
            return day >= start && day < upper
        }
    }

    private func chartEndDate(records: [BBTRecord], weights: [WeightRecord], tags: [DailyTag]) -> Date {
        let today = dateService.dayStart(for: Date())
        let offset = state.chartRange.rawValue - 1
        let recentWindowStart = dateService.calendar.date(byAdding: .day, value: -offset, to: today) ?? today

        let hasRecentRecord = records.contains { record in
            let day = dateService.dayStart(for: record.date)
            return day >= recentWindowStart && day <= today
        }
        let hasRecentTag = tags.contains { tag in
            let day = dateService.dayStart(for: tag.date)
            return day >= recentWindowStart && day <= today
        }
        let hasRecentWeight = weights.contains { weight in
            let day = dateService.dayStart(for: weight.date)
            return day >= recentWindowStart && day <= today
        }

        if hasRecentRecord || hasRecentTag || hasRecentWeight {
            return today
        }

        let latestRecordDay = records.map { dateService.dayStart(for: $0.date) }.max()
        let latestWeightDay = weights.map { dateService.dayStart(for: $0.date) }.max()
        let latestTagDay = tags.map { dateService.dayStart(for: $0.date) }.max()
        let latestHistoryDay = max(max(latestRecordDay ?? .distantPast, latestWeightDay ?? .distantPast), latestTagDay ?? .distantPast)
        if latestHistoryDay == .distantPast {
            return today
        }
        return latestHistoryDay
    }

    private func alignDisplayMonthToLatestRecordOnFirstLaunch() {
        guard !hasAlignedMonthOnLaunch else { return }
        hasAlignedMonthOnLaunch = true

        do {
            let records = try repository.fetchAllRecords()
            let weights = try repository.fetchAllWeights()
            let tags = try repository.fetchAllTags()
            let latestHistoryDate = max(max(records.last?.date ?? .distantPast, weights.last?.date ?? .distantPast), tags.last?.date ?? .distantPast)
            guard latestHistoryDate != .distantPast else { return }

            let currentMonthRange = dateService.monthRange(containing: state.displayMonth)
            let hasRecordOrTagInCurrentMonth = records.contains { currentMonthRange.contains($0.date) }
                || weights.contains { currentMonthRange.contains($0.date) }
                || tags.contains { currentMonthRange.contains($0.date) }
            guard !hasRecordOrTagInCurrentMonth else { return }

            state.displayMonth = latestHistoryDate
            state.selectedDate = latestHistoryDate
            hoverRecord = records.last { dateService.dayStart(for: $0.date) == dateService.dayStart(for: latestHistoryDate) }
        } catch {
            // Keep default month when startup lookup fails.
        }
    }
}
#endif
