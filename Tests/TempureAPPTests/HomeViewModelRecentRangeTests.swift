import Foundation
import Testing
@testable import TempureAPP

@Suite("HomeViewModel Recent Range")
struct HomeViewModelRecentRangeTests {
    @Test("Recent chart range should be based on today and ignore selected date")
    @MainActor
    func recentRangeIgnoresSelectedDate() throws {
        let dateService = DateService()
        let today = dateService.dayStart(for: Date())
        let oldDate = dateService.calendar.date(byAdding: .day, value: -120, to: today) ?? today

        let viewModel = HomeViewModel(
            container: AppContainer(
                repository: RecentRangeStubRepository(),
                dateService: dateService,
                haptics: RecentRangeNoopHapticsService()
            )
        )

        viewModel.onAppear()
        viewModel.updateChartRange(.days14)

        let expectedStart = dateService.calendar.date(byAdding: .day, value: -13, to: today) ?? today
        #expect(viewModel.state.chartDates.first == expectedStart)
        #expect(viewModel.state.chartDates.last == today)

        viewModel.selectDate(oldDate)
        #expect(viewModel.state.selectedDate == oldDate)
        #expect(viewModel.state.chartDates.first == expectedStart)
        #expect(viewModel.state.chartDates.last == today)
    }

    @Test("Recent chart range should stay stable when switching month")
    @MainActor
    func recentRangeIgnoresMonthNavigation() throws {
        let dateService = DateService()
        let today = dateService.dayStart(for: Date())
        let viewModel = HomeViewModel(
            container: AppContainer(
                repository: RecentRangeStubRepository(),
                dateService: dateService,
                haptics: RecentRangeNoopHapticsService()
            )
        )

        viewModel.onAppear()
        viewModel.updateChartRange(.days7)
        let expectedStart = dateService.calendar.date(byAdding: .day, value: -6, to: today) ?? today

        viewModel.showPreviousMonth()

        #expect(viewModel.state.chartDates.count == 7)
        #expect(viewModel.state.chartDates.first == expectedStart)
        #expect(viewModel.state.chartDates.last == today)
    }

    @Test("Recent chart range should fall back to latest history day when there is no recent data")
    @MainActor
    func recentRangeFallsBackToLatestHistoryDay() throws {
        let dateService = DateService()
        let today = dateService.dayStart(for: Date())
        let oldDay = dateService.calendar.date(byAdding: .day, value: -120, to: today) ?? today
        let oldRecord = BBTRecord(date: oldDay, temperatureCelsius: 36.5, updatedAt: 1)

        let viewModel = HomeViewModel(
            container: AppContainer(
                repository: RecentRangeStubRepository(allRecords: [oldRecord]),
                dateService: dateService,
                haptics: RecentRangeNoopHapticsService()
            )
        )

        viewModel.onAppear()
        viewModel.updateChartRange(.days14)

        let expectedStart = dateService.calendar.date(byAdding: .day, value: -13, to: oldDay) ?? oldDay
        #expect(viewModel.state.chartDates.first == expectedStart)
        #expect(viewModel.state.chartDates.last == oldDay)
    }

    @Test("Recent chart range should include latest history day even when it is after today")
    @MainActor
    func recentRangeAllowsFutureLatestHistoryDay() throws {
        let dateService = DateService()
        let today = dateService.dayStart(for: Date())
        let nextDay = dateService.calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let nextRecord = BBTRecord(date: nextDay, temperatureCelsius: 36.7, updatedAt: 1)

        let viewModel = HomeViewModel(
            container: AppContainer(
                repository: RecentRangeStubRepository(allRecords: [nextRecord]),
                dateService: dateService,
                haptics: RecentRangeNoopHapticsService()
            )
        )

        viewModel.onAppear()
        viewModel.updateChartRange(.days7)

        let expectedStart = dateService.calendar.date(byAdding: .day, value: -6, to: nextDay) ?? nextDay
        #expect(viewModel.state.chartDates.first == expectedStart)
        #expect(viewModel.state.chartDates.last == nextDay)
    }
}

private struct RecentRangeNoopHapticsService: HapticsService {
    @MainActor
    func light() {}

    @MainActor
    func selection() {}

    @MainActor
    func success() {}
}

private final class RecentRangeStubRepository: BBTRepository, @unchecked Sendable {
    private let allRecordsData: [BBTRecord]
    private let allTagsData: [DailyTag]

    init(allRecords: [BBTRecord] = [], allTags: [DailyTag] = []) {
        self.allRecordsData = allRecords
        self.allTagsData = allTags
    }

    func saveTemperature(on date: Date, temperatureCelsius: Double) throws {}

    func fetchTemperature(on date: Date) throws -> BBTRecord? {
        nil
    }

    func fetchMonthlyRecords(containing date: Date) throws -> [BBTRecord] {
        []
    }

    func fetchAllRecords() throws -> [BBTRecord] {
        allRecordsData
    }

    func saveTag(
        on date: Date,
        hasIntercourse: Bool,
        intercourseTime: IntercourseTime?,
        hasMenstruation: Bool,
        menstrualFlow: MenstrualFlow?,
        menstrualColor: MenstrualColor?,
        hasDysmenorrhea: Bool
    ) throws {}

    func fetchTag(on date: Date) throws -> DailyTag? {
        nil
    }

    func fetchMonthlyTags(containing date: Date) throws -> [DailyTag] {
        []
    }

    func fetchAllTags() throws -> [DailyTag] {
        allTagsData
    }

    func updatePreferredUnit(_ unit: TemperatureUnit) {}

    func preferredUnit() -> TemperatureUnit {
        .celsius
    }
}
