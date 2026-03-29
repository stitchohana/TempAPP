#if canImport(SwiftUI)
import SwiftUI

public struct TempInputSheet: View {
    @Binding public var inputText: String
    public var unit: TemperatureUnit
    public var onSave: () -> Void
    public var onDismiss: () -> Void

    private let haptics = SystemHapticsService()

    public init(
        inputText: Binding<String>,
        unit: TemperatureUnit,
        onSave: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self._inputText = inputText
        self.unit = unit
        self.onSave = onSave
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 14) {
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

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(keys, id: \.self) { key in
                    Button {
                        handleKey(key)
                    } label: {
                        Text(key)
                            .font(TempureTypography.body)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.8))
                            )
                    }
                    .buttonStyle(.plain)
                }
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
        .presentationDetents([.fraction(0.5)])
        .presentationDragIndicator(.visible)
    }

    private var displayValue: String {
        guard let value = Double(inputText) else {
            return "--.-- \(unit.symbol)"
        }
        return "\(String(format: "%.2f", value)) \(unit.symbol)"
    }

    private var keys: [String] {
        ["1", "2", "3",
         "4", "5", "6",
         "7", "8", "9",
         ".", "0", "⌫"]
    }

    private func handleKey(_ key: String) {
        haptics.selection()
        switch key {
        case "⌫":
            if !inputText.isEmpty {
                inputText.removeLast()
            }
        case ".":
            if inputText.isEmpty {
                inputText = "0."
            } else if !inputText.contains(".") {
                inputText.append(".")
            }
        default:
            appendDigit(key)
        }
    }

    private func appendDigit(_ digit: String) {
        guard digit.count == 1 else { return }

        if inputText.contains(".") {
            let parts = inputText.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            let decimalCount = parts.count > 1 ? parts[1].count : 0
            guard decimalCount < 2 else { return }
            inputText.append(digit)
            return
        }

        let integerCount = inputText.filter(\.isWholeNumber).count
        if integerCount < 2 {
            inputText.append(digit)
        } else if integerCount == 2 {
            inputText.append(".")
            inputText.append(digit)
        }
    }
}
#endif
