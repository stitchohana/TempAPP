import Foundation

public enum TemperatureUnit: String, CaseIterable, Codable, Sendable {
    case celsius
    case fahrenheit

    public var symbol: String {
        switch self {
        case .celsius:
            return "℃"
        case .fahrenheit:
            return "℉"
        }
    }
}
