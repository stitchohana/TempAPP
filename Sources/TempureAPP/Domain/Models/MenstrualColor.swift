import Foundation

public enum MenstrualColor: String, CaseIterable, Codable, Sendable {
    case pink
    case brightRed
    case darkRed
    case brown

    public var displayText: String {
        switch self {
        case .pink:
            return "粉色"
        case .brightRed:
            return "鲜红"
        case .darkRed:
            return "暗红"
        case .brown:
            return "褐色"
        }
    }
}
