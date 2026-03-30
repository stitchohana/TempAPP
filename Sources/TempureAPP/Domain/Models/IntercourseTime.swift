import Foundation

public enum IntercourseTime: String, CaseIterable, Codable, Sendable {
    case morning
    case afternoon
    case evening
    case night

    public var displayText: String {
        switch self {
        case .morning:
            return "早上"
        case .afternoon:
            return "下午"
        case .evening:
            return "晚上"
        case .night:
            return "深夜"
        }
    }
}
