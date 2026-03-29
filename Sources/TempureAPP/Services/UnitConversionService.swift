import Foundation

public enum UnitConversionService {
    public static func toDisplayValue(celsius: Double, unit: TemperatureUnit) -> Double {
        switch unit {
        case .celsius:
            return celsius
        case .fahrenheit:
            return celsius * 9.0 / 5.0 + 32.0
        }
    }

    public static func toStoredCelsius(value: Double, from unit: TemperatureUnit) -> Double {
        switch unit {
        case .celsius:
            return value
        case .fahrenheit:
            return (value - 32.0) * 5.0 / 9.0
        }
    }
}
