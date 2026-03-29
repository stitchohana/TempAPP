#if canImport(SwiftUI)
import Foundation
import SwiftUI

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public private(set) var state: HomeState
    @Published public var inputValue: Double = 36.6
    @Published public var tagHasIntercourse: Bool = false
    @Published public var tagHasMenstruation: Bool = false
    @Published public var tagMenstrualFlow: MenstrualFlow? = nil
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
    private var hasAlignedMonthOnLaunch = false

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

    public var inputRangeForCurrentUnit: ClosedRange<Double> {
        let lower = UnitConversionService.toDisplayValue(celsius: inputRangeCelsius.lowerBound, unit: state.unit)
        let upper = UnitConversionService.toDisplayValue(celsius: inputRangeCelsius.upperBound, unit: state.unit)
        return roundToTenth(lower)...roundToTenth(upper)
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
        hoverRecord = recordsByDateKey[dateService.storageKey(for: state.selectedDate)]
    }

    public func presentInput() {
        let key = dateService.storageKey(for: state.selectedDate)
        if let record = recordsByDateKey[key] {
            let display = UnitConversionService.toDisplayValue(celsius: record.temperatureCelsius, unit: state.unit)
            inputValue = roundToTenth(display)
        } else {
            let defaultValue = UnitConversionService.toDisplayValue(celsius: inputDefaultCelsius, unit: state.unit)
            inputValue = roundToTenth(defaultValue)
        }
        state.isInputSheetPresented = true
        haptics.light()
    }

    public func dismissInput() {
        state.isInputSheetPresented = false
    }

    public func saveInput() {
        do {
            let value = clampToInputRange(roundToTenth(inputValue))
            try saveTemperatureUseCase.execute(date: state.selectedDate, value: value, unit: state.unit)
            haptics.success()
            state.isInputSheetPresented = false
            reloadData()
            hoverRecord = recordsByDateKey[dateService.storageKey(for: state.selectedDate)]
        } catch {
            errorMessage = "保存失败，请重试。"
        }
    }

    public func presentTagInput() {
        let key = dateService.storageKey(for: state.selectedDate)
        if let existing = tagsByDateKey[key] {
            tagHasIntercourse = existing.hasIntercourse
            tagHasMenstruation = existing.hasMenstruation
            tagMenstrualFlow = existing.menstrualFlow
        } else {
            tagHasIntercourse = false
            tagHasMenstruation = false
            tagMenstrualFlow = nil
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
                hasMenstruation: tagHasMenstruation,
                menstrualFlow: flow
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
            let analysis = analyzeCycleUseCase.execute(records: allRecords)
            state.coverline = analysis.coverline
            state.highTempDays = analysis.highTemperatureDays
            state.isPregnancySignal = analysis.isPregnancySignal
            errorMessage = nil
        } catch {
            errorMessage = "读取数据失败，请稍后重试。"
        }
    }

    private func alignDisplayMonthToLatestRecordOnFirstLaunch() {
        guard !hasAlignedMonthOnLaunch else { return }
        hasAlignedMonthOnLaunch = true

        do {
            let records = try repository.fetchAllRecords()
            let tags = try repository.fetchAllTags()
            let latestHistoryDate = max(records.last?.date ?? .distantPast, tags.last?.date ?? .distantPast)
            guard latestHistoryDate != .distantPast else { return }

            let currentMonthRange = dateService.monthRange(containing: state.displayMonth)
            let hasRecordOrTagInCurrentMonth = records.contains { currentMonthRange.contains($0.date) }
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
