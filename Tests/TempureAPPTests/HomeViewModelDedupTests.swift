import Foundation
import Testing
@testable import TempureAPP

@Suite("HomeViewModel Dedup")
struct HomeViewModelDedupTests {
    @Test("Duplicate record keys should not crash and should keep newest updatedAt")
    @MainActor
    func duplicateRecordsKeepNewest() throws {
        let dateService = DateService()
        let day = dateService.dayStart(for: Date(timeIntervalSince1970: 1_711_000_000))

        let older = BBTRecord(date: day, temperatureCelsius: 36.3, updatedAt: 100)
        let newer = BBTRecord(date: day, temperatureCelsius: 36.8, updatedAt: 200)

        let repository = StubRepository(
            monthlyRecords: [older, newer],
            allRecords: [older, newer],
            monthlyTags: [],
            allTags: []
        )

        let viewModel = HomeViewModel(
            container: AppContainer(
                repository: repository,
                dateService: dateService,
                haptics: NoopHapticsService()
            )
        )

        viewModel.onAppear()

        let key = dateService.storageKey(for: day)
        #expect(viewModel.recordsByDateKey.count == 1)
        #expect(viewModel.recordsByDateKey[key]?.updatedAt == newer.updatedAt)
        #expect(viewModel.recordsByDateKey[key]?.temperatureCelsius == newer.temperatureCelsius)
    }

    @Test("Duplicate tag keys should not crash and should keep newest updatedAt")
    @MainActor
    func duplicateTagsKeepNewest() throws {
        let dateService = DateService()
        let day = dateService.dayStart(for: Date(timeIntervalSince1970: 1_712_000_000))

        let older = DailyTag(
            date: day,
            hasIntercourse: true,
            hasMenstruation: false,
            menstrualFlow: nil,
            updatedAt: 100
        )
        let newer = DailyTag(
            date: day,
            hasIntercourse: false,
            hasMenstruation: true,
            menstrualFlow: .medium,
            updatedAt: 200
        )

        let repository = StubRepository(
            monthlyRecords: [],
            allRecords: [],
            monthlyTags: [older, newer],
            allTags: [older, newer]
        )

        let viewModel = HomeViewModel(
            container: AppContainer(
                repository: repository,
                dateService: dateService,
                haptics: NoopHapticsService()
            )
        )

        viewModel.onAppear()

        let key = dateService.storageKey(for: day)
        #expect(viewModel.tagsByDateKey.count == 1)
        #expect(viewModel.tagsByDateKey[key]?.updatedAt == newer.updatedAt)
        #expect(viewModel.tagsByDateKey[key]?.hasIntercourse == false)
        #expect(viewModel.tagsByDateKey[key]?.hasMenstruation == true)
        #expect(viewModel.tagsByDateKey[key]?.menstrualFlow == .medium)
    }
}

private struct NoopHapticsService: HapticsService {
    @MainActor
    func light() {}

    @MainActor
    func selection() {}

    @MainActor
    func success() {}
}

private final class StubRepository: BBTRepository, @unchecked Sendable {
    private let monthlyRecordsData: [BBTRecord]
    private let allRecordsData: [BBTRecord]
    private let monthlyTagsData: [DailyTag]
    private let allTagsData: [DailyTag]
    private var preferred: TemperatureUnit = .celsius

    init(
        monthlyRecords: [BBTRecord],
        allRecords: [BBTRecord],
        monthlyTags: [DailyTag],
        allTags: [DailyTag]
    ) {
        self.monthlyRecordsData = monthlyRecords
        self.allRecordsData = allRecords
        self.monthlyTagsData = monthlyTags
        self.allTagsData = allTags
    }

    func saveTemperature(on date: Date, temperatureCelsius: Double) throws {}

    func fetchTemperature(on date: Date) throws -> BBTRecord? {
        allRecordsData.first
    }

    func fetchMonthlyRecords(containing date: Date) throws -> [BBTRecord] {
        monthlyRecordsData
    }

    func fetchAllRecords() throws -> [BBTRecord] {
        allRecordsData
    }

    func saveTag(
        on date: Date,
        hasIntercourse: Bool,
        hasMenstruation: Bool,
        menstrualFlow: MenstrualFlow?
    ) throws {}

    func fetchTag(on date: Date) throws -> DailyTag? {
        allTagsData.first
    }

    func fetchMonthlyTags(containing date: Date) throws -> [DailyTag] {
        monthlyTagsData
    }

    func fetchAllTags() throws -> [DailyTag] {
        allTagsData
    }

    func updatePreferredUnit(_ unit: TemperatureUnit) {
        preferred = unit
    }

    func preferredUnit() -> TemperatureUnit {
        preferred
    }
}
