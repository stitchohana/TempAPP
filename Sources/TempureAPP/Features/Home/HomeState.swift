import Foundation

public struct HomeState: Sendable {
    public var displayMonth: Date
    public var selectedDate: Date
    public var monthlyRecords: [BBTRecord]
    public var monthlyTags: [DailyTag]
    public var coverline: Double?
    public var highTempDays: Int
    public var isPregnancySignal: Bool
    public var unit: TemperatureUnit
    public var chartRange: ChartRange
    public var chartDates: [Date]
    public var chartRecords: [BBTRecord]
    public var chartTags: [DailyTag]
    public var isInputSheetPresented: Bool
    public var isTagSheetPresented: Bool

    public init(
        displayMonth: Date = Date(),
        selectedDate: Date = Date(),
        monthlyRecords: [BBTRecord] = [],
        monthlyTags: [DailyTag] = [],
        coverline: Double? = nil,
        highTempDays: Int = 0,
        isPregnancySignal: Bool = false,
        unit: TemperatureUnit = .celsius,
        chartRange: ChartRange = .days30,
        chartDates: [Date] = [],
        chartRecords: [BBTRecord] = [],
        chartTags: [DailyTag] = [],
        isInputSheetPresented: Bool = false,
        isTagSheetPresented: Bool = false
    ) {
        self.displayMonth = displayMonth
        self.selectedDate = selectedDate
        self.monthlyRecords = monthlyRecords
        self.monthlyTags = monthlyTags
        self.coverline = coverline
        self.highTempDays = highTempDays
        self.isPregnancySignal = isPregnancySignal
        self.unit = unit
        self.chartRange = chartRange
        self.chartDates = chartDates
        self.chartRecords = chartRecords
        self.chartTags = chartTags
        self.isInputSheetPresented = isInputSheetPresented
        self.isTagSheetPresented = isTagSheetPresented
    }
}
