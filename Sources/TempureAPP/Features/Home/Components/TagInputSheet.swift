#if canImport(SwiftUI)
import SwiftUI

public struct TagInputSheet: View {
    @Binding public var hasIntercourse: Bool
    @Binding public var hasMenstruation: Bool
    @Binding public var menstrualFlow: MenstrualFlow?
    public var onSave: () -> Void
    public var onDismiss: () -> Void

    private let haptics = SystemHapticsService()

    public init(
        hasIntercourse: Binding<Bool>,
        hasMenstruation: Binding<Bool>,
        menstrualFlow: Binding<MenstrualFlow?>,
        onSave: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self._hasIntercourse = hasIntercourse
        self._hasMenstruation = hasMenstruation
        self._menstrualFlow = menstrualFlow
        self.onSave = onSave
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("添加标签")
                    .font(TempureTypography.body)
                Spacer()
                Button("关闭", action: onDismiss)
                    .font(TempureTypography.caption)
                    .buttonStyle(.plain)
            }

            Toggle(isOn: intercourseBinding) {
                Text("同房")
                    .font(TempureTypography.body)
            }
            .toggleStyle(.switch)

            Toggle(isOn: menstruationBinding) {
                Text("月经")
                    .font(TempureTypography.body)
            }
            .toggleStyle(.switch)

            if hasMenstruation {
                VStack(alignment: .leading, spacing: 8) {
                    Text("经量（可选）")
                        .font(TempureTypography.caption)
                        .foregroundStyle(TempureColors.subtleDot)

                    HStack(spacing: 8) {
                        flowChip(title: "不选", isSelected: menstrualFlow == nil) {
                            menstrualFlow = nil
                            haptics.selection()
                        }

                        ForEach(MenstrualFlow.allCases, id: \.rawValue) { flow in
                            flowChip(title: flow.displayText, isSelected: menstrualFlow == flow) {
                                menstrualFlow = flow
                                haptics.selection()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                haptics.success()
                onSave()
            } label: {
                HStack {
                    Spacer()
                    Text("✓ 保存标签")
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

            if !hasIntercourse, !hasMenstruation {
                Text("保存后会清空该日期标签")
                    .font(TempureTypography.caption)
                    .foregroundStyle(TempureColors.subtleDot)
            }
        }
        .padding(18)
        .presentationDetents([.fraction(0.44)])
        .presentationDragIndicator(.visible)
    }

    private var intercourseBinding: Binding<Bool> {
        Binding(
            get: { hasIntercourse },
            set: { value in
                hasIntercourse = value
                haptics.selection()
            }
        )
    }

    private var menstruationBinding: Binding<Bool> {
        Binding(
            get: { hasMenstruation },
            set: { value in
                hasMenstruation = value
                if !value {
                    menstrualFlow = nil
                }
                haptics.selection()
            }
        )
    }

    private func flowChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(TempureTypography.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? TempureColors.dustyRose.opacity(0.86) : Color.black.opacity(0.06))
                )
                .foregroundStyle(isSelected ? Color.white : TempureColors.neutralText)
        }
        .buttonStyle(.plain)
    }
}
#endif
