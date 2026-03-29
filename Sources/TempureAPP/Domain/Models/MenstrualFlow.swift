import Foundation

public enum MenstrualFlow: String, CaseIterable, Codable, Sendable {
    case light
    case medium
    case heavy

    public var displayText: String {
        switch self {
        case .light:
            return "量小"
        case .medium:
            return "量中"
        case .heavy:
            return "量大"
        }
    }

    public var shortText: String {
        switch self {
        case .light:
            return "小"
        case .medium:
            return "中"
        case .heavy:
            return "大"
        }
    }
}
