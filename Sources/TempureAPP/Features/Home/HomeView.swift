#if canImport(SwiftUI)
import SwiftUI

public struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @Environment(\.colorScheme) private var colorScheme

    public init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            background
                .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    TinySettingsView(unit: viewModel.state.unit) {
                        viewModel.updateUnit($0)
                    }
                }
                .padding(.horizontal, 14)

                MatrixCalendarView(
                    month: viewModel.state.displayMonth,
                    selectedDate: viewModel.state.selectedDate,
                    recordedDateKeys: Set(viewModel.recordsByDateKey.keys),
                    dateService: DateService.shared,
                    onSelectDate: { viewModel.selectDate($0) },
                    onPreviousMonth: { viewModel.showPreviousMonth() },
                    onNextMonth: { viewModel.showNextMonth() }
                )
                .frame(maxHeight: 330)

                BBTLineChartView(
                    monthDates: DateService.shared.daysInMonth(containing: viewModel.state.displayMonth),
                    recordsByDateKey: viewModel.recordsByDateKey,
                    selectedDate: viewModel.state.selectedDate,
                    hoverRecord: viewModel.hoverRecord,
                    coverlineCelsius: viewModel.state.coverline,
                    isPregnancySignal: viewModel.state.isPregnancySignal,
                    unit: viewModel.state.unit,
                    dateService: DateService.shared,
                    onSelectDate: { viewModel.selectDate($0) },
                    onHoverRecord: { viewModel.hoverRecord = $0 }
                )
                .frame(maxHeight: 320)

                if viewModel.state.isPregnancySignal {
                    Text("体温已连续高温 15 天，也许会有一个好消息。建议使用验孕棒测试。")
                        .font(TempureTypography.caption)
                        .foregroundStyle(TempureColors.dustyRose)
                        .transition(.opacity)
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            Button(action: viewModel.presentInput) {
                Image(systemName: "plus")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(TempureColors.dustyRose)
                            .shadow(color: TempureColors.dustyRose.opacity(colorScheme == .dark ? 0.85 : 0.4), radius: 9)
                    )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.state.isInputSheetPresented },
                set: { if !$0 { viewModel.dismissInput() } }
            )
        ) {
            TempInputSheet(
                inputText: $viewModel.inputText,
                unit: viewModel.state.unit,
                onSave: viewModel.saveInput,
                onDismiss: viewModel.dismissInput
            )
        }
        .alert(
            "提示",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("知道了", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            viewModel.onAppear()
        }
    }

    private var background: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                TempureColors.warmSandDark,
                TempureColors.warmSandDark.opacity(0.95),
                Color.black.opacity(0.93),
            ]
        }
        return [
            TempureColors.warmSand,
            TempureColors.warmSand.opacity(0.96),
            Color.white.opacity(0.94),
        ]
    }
}
#endif
