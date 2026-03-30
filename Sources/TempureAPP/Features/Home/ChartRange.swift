import Foundation

public enum ChartRange: Int, CaseIterable, Sendable {
    case days7 = 7
    case days14 = 14
    case days30 = 30

    public var title: String {
        switch self {
        case .days7:
            "近7天"
        case .days14:
            "近14天"
        case .days30:
            "近30天"
        }
    }
}
