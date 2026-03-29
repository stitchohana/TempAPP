#if canImport(SwiftUI)
import SwiftUI

public struct TinySettingsView: View {
    public var unit: TemperatureUnit
    public var onSelectUnit: (TemperatureUnit) -> Void

    public init(unit: TemperatureUnit, onSelectUnit: @escaping (TemperatureUnit) -> Void) {
        self.unit = unit
        self.onSelectUnit = onSelectUnit
    }

    public var body: some View {
        Menu {
            Button {
                onSelectUnit(.celsius)
            } label: {
                Label("摄氏 \(unit == .celsius ? "✓" : "")", systemImage: "thermometer.medium")
            }

            Button {
                onSelectUnit(.fahrenheit)
            } label: {
                Label("华氏 \(unit == .fahrenheit ? "✓" : "")", systemImage: "thermometer.high")
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 13, weight: .semibold))
                .padding(8)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }
}
#endif
