#if canImport(SwiftUI)
import Foundation
import SwiftUI

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public private(set) var state: HomeState
    @Published public var inputText: String = ""
    @Published public var hoverRecord: BBTRecord?
    @Published public var errorMessage: String?

    private let repository: BBTRepository
    private let dateService: DateService
    private let haptics: HapticsService
    private let saveTemperatureUseCase: SaveTemperatureUseCase
    private let getMonthlyRecordsUseCase: GetMonthlyRecordsUseCase
    private let analyzeCycleUseCase: AnalyzeCycleUseCase

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
        Dictionary(uniqueKeysWithValues: state.monthlyRecords.map { (dateService.storageKey(for: $0.date), $0) })
    }

    public func onAppear() {
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
            inputText = String(format: "%.2f", UnitConversionService.toDisplayValue(celsius: record.temperatureCelsius, unit: state.unit))
        } else {
            inputText = ""
        }
        state.isInputSheetPresented = true
        haptics.light()
    }

    public func dismissInput() {
        state.isInputSheetPresented = false
    }

    public func saveInput() {
        guard let value = Double(inputText) else {
            errorMessage = "请输入有效温度（示例: 36.54）"
            return
        }

        do {
            try saveTemperatureUseCase.execute(date: state.selectedDate, value: value, unit: state.unit)
            haptics.success()
            state.isInputSheetPresented = false
            reloadData()
            hoverRecord = recordsByDateKey[dateService.storageKey(for: state.selectedDate)]
        } catch {
            errorMessage = "保存失败，请重试。"
        }
    }

    public func updateUnit(_ unit: TemperatureUnit) {
        state.unit = unit
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
        String(format: "%.2f", value)
    }

    private func reloadData() {
        do {
            state.monthlyRecords = try getMonthlyRecordsUseCase.execute(containing: state.displayMonth)
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
}
#endif
