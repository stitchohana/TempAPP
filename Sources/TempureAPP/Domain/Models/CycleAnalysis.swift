import Foundation

public struct CycleAnalysis: Equatable, Sendable {
    public var coverline: Double?
    public var triggerDate: Date?
    public var highTemperatureDays: Int
    public var isPregnancySignal: Bool

    public init(
        coverline: Double? = nil,
        triggerDate: Date? = nil,
        highTemperatureDays: Int = 0,
        isPregnancySignal: Bool = false
    ) {
        self.coverline = coverline
        self.triggerDate = triggerDate
        self.highTemperatureDays = highTemperatureDays
        self.isPregnancySignal = isPregnancySignal
    }
}
