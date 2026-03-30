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
                    tagsByDateKey: viewModel.tagsByDateKey,
                    dateService: DateService.shared,
                    onSelectDate: { viewModel.selectDate($0) },
                    onPreviousMonth: { viewModel.showPreviousMonth() },
                    onNextMonth: { viewModel.showNextMonth() }
                )
                .frame(maxHeight: 330)

                Picker("图表范围", selection: Binding(
                    get: { viewModel.state.chartRange },
                    set: { viewModel.updateChartRange($0) }
                )) {
                    ForEach(ChartRange.allCases, id: \.self) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 6)

                BBTLineChartView(
                    monthDates: viewModel.state.chartDates,
                    recordsByDateKey: viewModel.chartRecordsByDateKey,
                    tagsByDateKey: viewModel.chartTagsByDateKey,
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

            HStack(spacing: 12) {
                Button(action: viewModel.presentTagInput) {
                    Image(systemName: "tag")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(
                            Circle()
                                .fill(TempureColors.sageGreen)
                                .shadow(color: TempureColors.sageGreen.opacity(colorScheme == .dark ? 0.8 : 0.35), radius: 7)
                        )
                }
                .buttonStyle(.plain)

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
            }
            .padding(.bottom, 20)
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.state.isInputSheetPresented },
                set: { if !$0 { viewModel.dismissInput() } }
            )
        ) {
            TempInputSheet(
                inputValue: $viewModel.inputValue,
                unit: viewModel.state.unit,
                range: viewModel.inputRangeForCurrentUnit,
                onSave: viewModel.saveInput,
                onDismiss: viewModel.dismissInput
            )
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.state.isTagSheetPresented },
                set: { if !$0 { viewModel.dismissTagInput() } }
            )
        ) {
            TagInputSheet(
                hasIntercourse: $viewModel.tagHasIntercourse,
                intercourseTime: $viewModel.tagIntercourseTime,
                hasMenstruation: $viewModel.tagHasMenstruation,
                menstrualFlow: $viewModel.tagMenstrualFlow,
                menstrualColor: $viewModel.tagMenstrualColor,
                hasDysmenorrhea: $viewModel.tagHasDysmenorrhea,
                onSave: viewModel.saveTagInput,
                onDismiss: viewModel.dismissTagInput
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
