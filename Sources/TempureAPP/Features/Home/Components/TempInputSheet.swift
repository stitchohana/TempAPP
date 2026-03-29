#if canImport(SwiftUI)
import SwiftUI

public struct TempInputSheet: View {
    @Binding public var inputValue: Double
    public var unit: TemperatureUnit
    public var range: ClosedRange<Double>
    public var onSave: () -> Void
    public var onDismiss: () -> Void

    private let haptics = SystemHapticsService()
    @State private var lastSteppedValue: Double = 0

    public init(
        inputValue: Binding<Double>,
        unit: TemperatureUnit,
        range: ClosedRange<Double>,
        onSave: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self._inputValue = inputValue
        self.unit = unit
        self.range = range
        self.onSave = onSave
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("录入体温")
                    .font(TempureTypography.body)
                Spacer()
                Button("关闭", action: onDismiss)
                    .font(TempureTypography.caption)
                    .buttonStyle(.plain)
            }

            Text(displayValue)
                .font(TempureTypography.monoNumber)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.05))
                )

            VStack(spacing: 8) {
                Slider(
                    value: sliderBinding,
                    in: range,
                    step: 0.1
                )
                .tint(TempureColors.dustyRose)

                HStack {
                    Text("\(String(format: "%.1f", range.lowerBound))\(unit.symbol)")
                    Spacer()
                    Text("\(String(format: "%.1f", range.upperBound))\(unit.symbol)")
                }
                .font(TempureTypography.caption)
                .foregroundStyle(TempureColors.subtleDot)
            }

            Button {
                haptics.success()
                onSave()
            } label: {
                HStack {
                    Spacer()
                    Text("✓ 保存")
                        .font(TempureTypography.body)
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(TempureColors.dustyRose.opacity(0.88))
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(18)
        .presentationDetents([.fraction(0.42)])
        .presentationDragIndicator(.visible)
        .onAppear {
            let stepped = steppedValue(inputValue)
            inputValue = stepped
            lastSteppedValue = stepped
        }
    }

    private var displayValue: String {
        "\(String(format: "%.1f", inputValue)) \(unit.symbol)"
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { inputValue },
            set: { newValue in
                let stepped = steppedValue(newValue)
                if stepped != inputValue {
                    inputValue = stepped
                }
                if stepped != lastSteppedValue {
                    lastSteppedValue = stepped
                    haptics.selection()
                }
            }
        )
    }

    private func steppedValue(_ value: Double) -> Double {
        let stepped = (value * 10).rounded() / 10
        return min(max(stepped, range.lowerBound), range.upperBound)
    }
}
#endif
