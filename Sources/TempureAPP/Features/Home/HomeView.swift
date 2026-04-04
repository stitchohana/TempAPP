#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var chartRenderSize: CGSize = .zero
#if canImport(UIKit)
    @State private var chartImageSaveHandler: ChartImageSaveHandler?
#endif

    public init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            background
                .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    if let accountName = viewModel.currentAccountName {
                        HStack(spacing: 6) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 13, weight: .medium))
                            Text(accountName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .font(TempureTypography.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.7))
                        )
                    }

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

                HStack(spacing: 8) {
                    Picker("图表范围", selection: Binding(
                        get: { viewModel.state.chartRange },
                        set: { viewModel.updateChartRange($0) }
                    )) {
                        ForEach(ChartRange.allCases, id: \.self) { range in
                            Text(range.title).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)

                    exportChartButton
                }
                .padding(.horizontal, 6)

                chartView
                    .frame(maxHeight: 320)
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .onAppear {
                                    chartRenderSize = proxy.size
                                }
                        }
                    )

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

                Button(action: viewModel.presentWeightInput) {
                    Image(systemName: "scalemass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(
                            Circle()
                                .fill(TempureColors.sageGreen.opacity(0.9))
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
                get: { viewModel.state.isWeightSheetPresented },
                set: { if !$0 { viewModel.dismissWeightInput() } }
            )
        ) {
            WeightInputSheet(
                inputValue: $viewModel.inputWeightValue,
                range: viewModel.inputWeightRangeKg,
                onSave: viewModel.saveWeightInput,
                onDismiss: viewModel.dismissWeightInput
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
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                viewModel.onEnterForeground()
            case .background:
                viewModel.onEnterBackground()
            default:
                break
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var chartView: some View {
        BBTLineChartView(
            monthDates: viewModel.state.chartDates,
            recordsByDateKey: viewModel.chartRecordsByDateKey,
            weightRecordsByDateKey: viewModel.chartWeightRecordsByDateKey,
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
    }

    @ViewBuilder
    private var exportChartButton: some View {
#if canImport(UIKit)
        Button(action: exportCurrentChartImage) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(TempureColors.sageGreen)
                        .shadow(color: TempureColors.sageGreen.opacity(colorScheme == .dark ? 0.8 : 0.3), radius: 4)
                )
        }
        .buttonStyle(.plain)
#endif
    }

#if canImport(UIKit)
    private func exportCurrentChartImage() {
        guard let image = renderChartImage() else {
            viewModel.errorMessage = "导出失败，请重试。"
            return
        }

        let handler = ChartImageSaveHandler { error in
            DispatchQueue.main.async {
                if let error {
                    viewModel.errorMessage = "保存失败：\(error.localizedDescription)"
                } else {
                    viewModel.errorMessage = "折线图已保存到相册。"
                }
                chartImageSaveHandler = nil
            }
        }
        chartImageSaveHandler = handler

        UIImageWriteToSavedPhotosAlbum(
            image,
            handler,
            #selector(ChartImageSaveHandler.image(_:didFinishSavingWithError:contextInfo:)),
            nil
        )
    }

    private func renderChartImage() -> UIImage? {
        let width = chartRenderSize.width > 1 ? chartRenderSize.width : max(UIScreen.main.bounds.width - 28, 320)
        let height = chartRenderSize.height > 1 ? chartRenderSize.height : 320

        let chartView = BBTLineChartView(
            monthDates: viewModel.state.chartDates,
            recordsByDateKey: viewModel.chartRecordsByDateKey,
            weightRecordsByDateKey: viewModel.chartWeightRecordsByDateKey,
            tagsByDateKey: viewModel.chartTagsByDateKey,
            selectedDate: viewModel.state.selectedDate,
            hoverRecord: viewModel.hoverRecord,
            coverlineCelsius: viewModel.state.coverline,
            isPregnancySignal: viewModel.state.isPregnancySignal,
            unit: viewModel.state.unit,
            dateService: DateService.shared,
            onSelectDate: { _ in },
            onHoverRecord: { _ in }
        )
        .frame(width: width, height: height)
        .environment(\.colorScheme, .light)

        let exportView = ZStack {
            Color.white
            chartView
        }
        .frame(width: width, height: height)

        let renderer = ImageRenderer(content: exportView)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
#endif

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

#if canImport(UIKit)
private final class ChartImageSaveHandler: NSObject {
    private let completion: (Error?) -> Void

    init(completion: @escaping (Error?) -> Void) {
        self.completion = completion
    }

    @objc
    func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeMutableRawPointer?) {
        completion(error)
    }
}
#endif
#endif
