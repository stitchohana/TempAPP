#if canImport(SwiftUI)
import SwiftUI

public struct BBTLineChartView: View {
    public var monthDates: [Date]
    public var recordsByDateKey: [String: BBTRecord]
    public var selectedDate: Date
    public var hoverRecord: BBTRecord?
    public var coverlineCelsius: Double?
    public var isPregnancySignal: Bool
    public var unit: TemperatureUnit
    public var dateService: DateService
    public var onSelectDate: (Date) -> Void
    public var onHoverRecord: (BBTRecord?) -> Void

    @Environment(\.colorScheme) private var colorScheme

    public init(
        monthDates: [Date],
        recordsByDateKey: [String: BBTRecord],
        selectedDate: Date,
        hoverRecord: BBTRecord?,
        coverlineCelsius: Double?,
        isPregnancySignal: Bool,
        unit: TemperatureUnit,
        dateService: DateService,
        onSelectDate: @escaping (Date) -> Void,
        onHoverRecord: @escaping (BBTRecord?) -> Void
    ) {
        self.monthDates = monthDates
        self.recordsByDateKey = recordsByDateKey
        self.selectedDate = selectedDate
        self.hoverRecord = hoverRecord
        self.coverlineCelsius = coverlineCelsius
        self.isPregnancySignal = isPregnancySignal
        self.unit = unit
        self.dateService = dateService
        self.onSelectDate = onSelectDate
        self.onHoverRecord = onHoverRecord
    }

    public var body: some View {
        GeometryReader { proxy in
            let frame = chartFrame(in: proxy.size)
            let points = plottedPoints(in: frame)
            let segments = lineSegments(from: points)
            let marker = markerRecord

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(colorScheme == .dark ? TempureColors.warmSandDark.opacity(0.82) : Color.white.opacity(0.6))

                if let y = coverlineY(in: frame, points: points) {
                    Path { path in
                        path.move(to: CGPoint(x: frame.minX, y: y))
                        path.addLine(to: CGPoint(x: frame.maxX, y: y))
                    }
                    .stroke(
                        TempureColors.missingDash.opacity(0.85),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                    )
                }

                ForEach(segments.indices, id: \.self) { index in
                    let segment = segments[index]
                    segmentPath(from: segment.start.point, to: segment.end.point)
                        .stroke(
                            strokeForSegment(segment),
                            style: StrokeStyle(
                                lineWidth: segment.isDashed ? 1.2 : 2.6,
                                lineCap: .round,
                                dash: segment.isDashed ? [4, 4] : []
                            )
                        )
                }

                ForEach(points, id: \.key) { point in
                    Circle()
                        .fill(pointColor(for: point))
                        .frame(width: point.key == selectedDateKey ? 9 : 5, height: point.key == selectedDateKey ? 9 : 5)
                        .shadow(
                            color: point.key == selectedDateKey && colorScheme == .dark ? pointColor(for: point).opacity(0.8) : .clear,
                            radius: 6
                        )
                        .position(point.point)
                }

                if isPregnancySignal, let anchor = points.last?.point {
                    Path { path in
                        path.move(to: CGPoint(x: max(frame.minX, anchor.x - 52), y: anchor.y - 10))
                        path.addLine(to: CGPoint(x: min(frame.maxX, anchor.x + 10), y: anchor.y - 10))
                    }
                    .stroke(
                        TempureColors.dustyRose.opacity(0.95),
                        style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
                    )
                    .shadow(color: TempureColors.dustyRose.opacity(colorScheme == .dark ? 0.8 : 0.35), radius: 4)
                }

                if let marker, let point = points.first(where: { $0.key == dateService.storageKey(for: marker.date) }) {
                    markerBubble(for: marker)
                        .position(
                            x: min(max(point.point.x, frame.minX + 72), frame.maxX - 72),
                            y: frame.minY + 20
                        )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let nearest = nearestRecord(from: value.location, points: points)
                        onHoverRecord(nearest)
                        if let nearest {
                            onSelectDate(nearest.date)
                        }
                    }
            )
        }
        .animation(.easeInOut(duration: TempureMotion.medium), value: recordsByDateKey.count)
    }

    private func markerBubble(for record: BBTRecord) -> some View {
        let formatter = DateFormatter()
        formatter.calendar = dateService.calendar
        formatter.locale = Locale.current
        formatter.dateFormat = "M/d"

        let value = UnitConversionService.toDisplayValue(celsius: record.temperatureCelsius, unit: unit)
        return Text("\(formatter.string(from: record.date))  \(String(format: "%.1f", value))\(unit.symbol)")
            .font(TempureTypography.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(TempureColors.subtleDot.opacity(0.25), lineWidth: 1)
            )
    }

    private var selectedDateKey: String {
        dateService.storageKey(for: selectedDate)
    }

    private var markerRecord: BBTRecord? {
        if let hoverRecord {
            return hoverRecord
        }
        return recordsByDateKey[selectedDateKey]
    }

    private func chartFrame(in size: CGSize) -> CGRect {
        CGRect(x: 18, y: 20, width: size.width - 36, height: size.height - 34)
    }

    private func segmentPath(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }

    private func nearestRecord(from location: CGPoint, points: [PlottedPoint]) -> BBTRecord? {
        points.min(by: { abs($0.point.x - location.x) < abs($1.point.x - location.x) })?.record
    }

    private func coverlineY(in frame: CGRect, points: [PlottedPoint]) -> CGFloat? {
        guard let coverlineCelsius else { return nil }
        let value = UnitConversionService.toDisplayValue(celsius: coverlineCelsius, unit: unit)
        let range = yRange(points: points.map(\.value), include: value)
        return toY(value: value, range: range, frame: frame)
    }

    private func plottedPoints(in frame: CGRect) -> [PlottedPoint] {
        guard monthDates.count > 1 else { return [] }

        let stepX = frame.width / CGFloat(max(monthDates.count - 1, 1))
        let rawValues = monthDates.compactMap { date -> Double? in
            let key = dateService.storageKey(for: date)
            guard let record = recordsByDateKey[key] else { return nil }
            return UnitConversionService.toDisplayValue(celsius: record.temperatureCelsius, unit: unit)
        }
        let coverDisplay = coverlineCelsius.map { UnitConversionService.toDisplayValue(celsius: $0, unit: unit) }
        let range = yRange(points: rawValues, include: coverDisplay)

        return monthDates.enumerated().compactMap { index, date in
            let key = dateService.storageKey(for: date)
            guard let record = recordsByDateKey[key] else { return nil }
            let value = UnitConversionService.toDisplayValue(celsius: record.temperatureCelsius, unit: unit)
            let x = frame.minX + CGFloat(index) * stepX
            let y = toY(value: value, range: range, frame: frame)
            return PlottedPoint(
                key: key,
                dateIndex: index,
                value: value,
                record: record,
                point: CGPoint(x: x, y: y)
            )
        }
    }

    private func yRange(points: [Double?], include extra: Double?) -> ClosedRange<Double> {
        let values = points.compactMap { $0 } + (extra.map { [$0] } ?? [])
        var minValue = values.min() ?? defaultMin
        var maxValue = values.max() ?? defaultMax

        minValue = min(minValue, defaultMin)
        maxValue = max(maxValue, defaultMax)

        let pad = 0.15
        minValue -= pad
        maxValue += pad

        if maxValue - minValue < 0.3 {
            maxValue += 0.2
            minValue -= 0.2
        }
        return minValue...maxValue
    }

    private var defaultMin: Double {
        UnitConversionService.toDisplayValue(celsius: 35.5, unit: unit)
    }

    private var defaultMax: Double {
        UnitConversionService.toDisplayValue(celsius: 37.5, unit: unit)
    }

    private func toY(value: Double, range: ClosedRange<Double>, frame: CGRect) -> CGFloat {
        let ratio = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return frame.maxY - CGFloat(ratio) * frame.height
    }

    private func lineSegments(from points: [PlottedPoint]) -> [LineSegment] {
        guard points.count > 1 else { return [] }
        var output: [LineSegment] = []

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let dayGap = current.dateIndex - previous.dateIndex
            let isDashed = dayGap > 1

            output.append(
                LineSegment(
                    start: previous,
                    end: current,
                    isDashed: isDashed
                )
            )
        }
        return output
    }

    private func pointColor(for point: PlottedPoint) -> Color {
        guard let coverlineCelsius else {
            return TempureColors.sageGreen
        }
        return point.record.temperatureCelsius >= coverlineCelsius
            ? TempureColors.dustyRose
            : TempureColors.sageGreen
    }

    private func strokeForSegment(_ segment: LineSegment) -> AnyShapeStyle {
        if segment.isDashed {
            return AnyShapeStyle(TempureColors.missingDash)
        }

        guard let coverlineCelsius else {
            return AnyShapeStyle(TempureColors.sageGreen)
        }

        let isStartHigh = segment.start.record.temperatureCelsius >= coverlineCelsius
        let isEndHigh = segment.end.record.temperatureCelsius >= coverlineCelsius

        if isStartHigh == isEndHigh {
            return AnyShapeStyle(isStartHigh ? TempureColors.dustyRose : TempureColors.sageGreen)
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [TempureColors.sageGreen, TempureColors.dustyRose],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}

private struct PlottedPoint {
    let key: String
    let dateIndex: Int
    let value: Double
    let record: BBTRecord
    let point: CGPoint
}

private struct LineSegment {
    let start: PlottedPoint
    let end: PlottedPoint
    let isDashed: Bool
}
#endif
