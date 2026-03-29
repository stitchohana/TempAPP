#if canImport(SwiftUI)
import SwiftUI

public struct MatrixCalendarView: View {
    public var month: Date
    public var selectedDate: Date
    public var recordedDateKeys: Set<String>
    public var dateService: DateService
    public var onSelectDate: (Date) -> Void
    public var onPreviousMonth: () -> Void
    public var onNextMonth: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    public init(
        month: Date,
        selectedDate: Date,
        recordedDateKeys: Set<String>,
        dateService: DateService,
        onSelectDate: @escaping (Date) -> Void,
        onPreviousMonth: @escaping () -> Void,
        onNextMonth: @escaping () -> Void
    ) {
        self.month = month
        self.selectedDate = selectedDate
        self.recordedDateKeys = recordedDateKeys
        self.dateService = dateService
        self.onSelectDate = onSelectDate
        self.onPreviousMonth = onPreviousMonth
        self.onNextMonth = onNextMonth
    }

    public var body: some View {
        VStack(spacing: 10) {
            header
            weekdays
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(monthCells.indices, id: \.self) { index in
                    if let date = monthCells[index] {
                        dayCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 34)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(colorScheme == .dark ? TempureColors.warmSandDark.opacity(0.8) : Color.white.opacity(0.55))
        )
        .gesture(
            DragGesture(minimumDistance: 18)
                .onEnded { value in
                    if value.translation.width < -30 {
                        onNextMonth()
                    } else if value.translation.width > 30 {
                        onPreviousMonth()
                    }
                }
        )
    }

    private var header: some View {
        HStack {
            Button(action: onPreviousMonth) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthTitle)
                .font(TempureTypography.header)

            Spacer()

            Button(action: onNextMonth) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(colorScheme == .dark ? TempureColors.neutralTextDark : TempureColors.neutralText)
    }

    private var weekdays: some View {
        let labels = ["一", "二", "三", "四", "五", "六", "日"]
        return HStack(spacing: 8) {
            ForEach(labels, id: \.self) { label in
                Text(label)
                    .font(TempureTypography.caption)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(TempureColors.subtleDot)
            }
        }
    }

    private func dayCell(for date: Date) -> some View {
        let key = dateService.storageKey(for: date)
        let isSelected = dateService.storageKey(for: selectedDate) == key
        let hasRecord = recordedDateKeys.contains(key)
        let day = dateService.calendar.component(.day, from: date)

        return Button {
            onSelectDate(date)
        } label: {
            VStack(spacing: 3) {
                Text("\(day)")
                    .font(TempureTypography.body)
                    .foregroundStyle(colorScheme == .dark ? TempureColors.neutralTextDark : TempureColors.neutralText)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .stroke(
                                isSelected ? TempureColors.dustyRose.opacity(0.9) : .clear,
                                lineWidth: 1.8
                            )
                            .shadow(color: isSelected ? TempureColors.dustyRose.opacity(colorScheme == .dark ? 0.9 : 0.35) : .clear, radius: 7)
                    )

                Circle()
                    .fill(hasRecord ? TempureColors.subtleDot : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var monthCells: [Date?] {
        let days = dateService.daysInMonth(containing: month)
        guard let firstDay = days.first else { return [] }
        let weekday = dateService.calendar.component(.weekday, from: firstDay)
        let mondayStartOffset = (weekday + 5) % 7
        return Array(repeating: nil, count: mondayStartOffset) + days
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = dateService.calendar
        formatter.locale = Locale.current
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: month)
    }
}
#endif
