import Foundation

public struct HomeState: Sendable {
    public var displayMonth: Date
    public var selectedDate: Date
    public var monthlyRecords: [BBTRecord]
    public var coverline: Double?
    public var highTempDays: Int
    public var isPregnancySignal: Bool
    public var unit: TemperatureUnit
    public var isInputSheetPresented: Bool

    public init(
        displayMonth: Date = Date(),
        selectedDate: Date = Date(),
        monthlyRecords: [BBTRecord] = [],
        coverline: Double? = nil,
        highTempDays: Int = 0,
        isPregnancySignal: Bool = false,
        unit: TemperatureUnit = .celsius,
        isInputSheetPresented: Bool = false
    ) {
        self.displayMonth = displayMonth
        self.selectedDate = selectedDate
        self.monthlyRecords = monthlyRecords
        self.coverline = coverline
        self.highTempDays = highTempDays
        self.isPregnancySignal = isPregnancySignal
        self.unit = unit
        self.isInputSheetPresented = isInputSheetPresented
    }
}
