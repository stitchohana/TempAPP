import Foundation

public struct HomeState: Sendable {
    public var displayMonth: Date
    public var selectedDate: Date
    public var monthlyRecords: [BBTRecord]
    public var allWeightRecords: [WeightRecord]
    public var monthlyTags: [DailyTag]
    public var coverline: Double?
    public var highTempDays: Int
    public var isPregnancySignal: Bool
    public var unit: TemperatureUnit
    public var chartRange: ChartRange
    public var chartDates: [Date]
    public var chartRecords: [BBTRecord]
    public var chartWeightRecords: [WeightRecord]
    public var chartTags: [DailyTag]
    public var isInputSheetPresented: Bool
    public var isWeightSheetPresented: Bool
    public var isTagSheetPresented: Bool

    public init(
        displayMonth: Date = Date(),
        selectedDate: Date = Date(),
        monthlyRecords: [BBTRecord] = [],
        allWeightRecords: [WeightRecord] = [],
        monthlyTags: [DailyTag] = [],
        coverline: Double? = nil,
        highTempDays: Int = 0,
        isPregnancySignal: Bool = false,
        unit: TemperatureUnit = .celsius,
        chartRange: ChartRange = .days30,
        chartDates: [Date] = [],
        chartRecords: [BBTRecord] = [],
        chartWeightRecords: [WeightRecord] = [],
        chartTags: [DailyTag] = [],
        isInputSheetPresented: Bool = false,
        isWeightSheetPresented: Bool = false,
        isTagSheetPresented: Bool = false
    ) {
        self.displayMonth = displayMonth
        self.selectedDate = selectedDate
        self.monthlyRecords = monthlyRecords
        self.allWeightRecords = allWeightRecords
        self.monthlyTags = monthlyTags
        self.coverline = coverline
        self.highTempDays = highTempDays
        self.isPregnancySignal = isPregnancySignal
        self.unit = unit
        self.chartRange = chartRange
        self.chartDates = chartDates
        self.chartRecords = chartRecords
        self.chartWeightRecords = chartWeightRecords
        self.chartTags = chartTags
        self.isInputSheetPresented = isInputSheetPresented
        self.isWeightSheetPresented = isWeightSheetPresented
        self.isTagSheetPresented = isTagSheetPresented
    }
}
