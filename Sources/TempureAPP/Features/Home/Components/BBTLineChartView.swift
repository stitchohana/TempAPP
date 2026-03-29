#if canImport(SwiftUI)
import SwiftUI

public struct BBTLineChartView: View {
    public var monthDates: [Date]
    public var recordsByDateKey: [String: BBTRecord]
    public var tagsByDateKey: [String: DailyTag]
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
        tagsByDateKey: [String: DailyTag],
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
        self.tagsByDateKey = tagsByDateKey
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
            let tagMarkers = tagMarkers(from: points)
            let axisRange = rangeForAxis(points: points)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(colorScheme == .dark ? TempureColors.warmSandDark.opacity(0.82) : Color.white.opacity(0.6))

                ForEach(temperatureTicks(range: axisRange, frame: frame)) { tick in
                    Text(String(format: "%.1f", tick.value))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(TempureColors.subtleDot.opacity(0.92))
                        .position(x: frame.minX - 20, y: tick.y)
                }

                ForEach(dateTicks(frame: frame)) { tick in
                    Text(tick.label)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(TempureColors.subtleDot.opacity(0.92))
                        .position(x: tick.x, y: frame.maxY + 13)
                }

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

                ForEach(tagMarkers) { marker in
                    tagSymbolStack(for: marker.tag)
                        .position(marker.point)
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

    private var intercourseMarker: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(TempureColors.dustyRose)
            .shadow(color: TempureColors.dustyRose.opacity(colorScheme == .dark ? 0.8 : 0.35), radius: 2)
    }

    private var menstruationMarker: some View {
        Image(systemName: "diamond.fill")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Color(red: 0.86, green: 0.23, blue: 0.26))
            .shadow(color: Color(red: 0.86, green: 0.23, blue: 0.26).opacity(colorScheme == .dark ? 0.8 : 0.35), radius: 2)
    }

    @ViewBuilder
    private func tagSymbolStack(for tag: DailyTag) -> some View {
        let symbolCount = (tag.hasIntercourse ? 1 : 0) + (tag.hasMenstruation ? 1 : 0)
        if symbolCount <= 1 {
            if tag.hasIntercourse {
                intercourseMarker
            } else if tag.hasMenstruation {
                menstruationMarker
            }
        } else {
            HStack(spacing: 2) {
                if tag.hasIntercourse {
                    intercourseMarker
                }
                if tag.hasMenstruation {
                    menstruationMarker
                }
            }
        }
    }

    private func markerBubble(for record: BBTRecord) -> some View {
        let formatter = DateFormatter()
        formatter.calendar = dateService.calendar
        formatter.locale = Locale.current
        formatter.dateFormat = "M/d"

        let value = UnitConversionService.toDisplayValue(celsius: record.temperatureCelsius, unit: unit)
        let tagText = tagText(for: record.date)
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(formatter.string(from: record.date))  \(String(format: "%.1f", value))\(unit.symbol)")
                .font(TempureTypography.caption)
            if let tagText {
                Text(tagText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(TempureColors.subtleDot)
            }
        }
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

    private func rangeForAxis(points: [PlottedPoint]) -> ClosedRange<Double> {
        let coverDisplay = coverlineCelsius.map { UnitConversionService.toDisplayValue(celsius: $0, unit: unit) }
        return yRange(points: points.map(\.value), include: coverDisplay)
    }

    private func tagText(for date: Date) -> String? {
        let key = dateService.storageKey(for: date)
        guard let tag = tagsByDateKey[key], tag.hasAnyTag else {
            return nil
        }

        var items: [String] = []
        if tag.hasIntercourse {
            items.append("同房")
        }
        if tag.hasMenstruation {
            if let flow = tag.menstrualFlow {
                items.append("月经(\(flow.displayText))")
            } else {
                items.append("月经")
            }
        }
        return items.isEmpty ? nil : items.joined(separator: " · ")
    }

    private func chartFrame(in size: CGSize) -> CGRect {
        let leftInset: CGFloat = 48
        let rightInset: CGFloat = 14
        let topInset: CGFloat = 16
        let bottomInset: CGFloat = 28
        let width = max(size.width - leftInset - rightInset, 40)
        let height = max(size.height - topInset - bottomInset, 40)
        return CGRect(x: leftInset, y: topInset, width: width, height: height)
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

    private func tagMarkers(from points: [PlottedPoint]) -> [TagMarker] {
        points.compactMap { point in
            guard let tag = tagsByDateKey[point.key], tag.hasAnyTag else {
                return nil
            }
            return TagMarker(key: point.key, point: point.point, tag: tag)
        }
    }

    private func temperatureTicks(range: ClosedRange<Double>, frame: CGRect) -> [TemperatureAxisTick] {
        [
            TemperatureAxisTick(id: 0, value: roundToTenth(range.upperBound), y: frame.minY),
            TemperatureAxisTick(id: 1, value: roundToTenth((range.upperBound + range.lowerBound) / 2), y: frame.midY),
            TemperatureAxisTick(id: 2, value: roundToTenth(range.lowerBound), y: frame.maxY),
        ]
    }

    private func dateTicks(frame: CGRect) -> [DateAxisTick] {
        guard !monthDates.isEmpty else { return [] }
        let denominator = CGFloat(max(monthDates.count - 1, 1))
        let rawIndices = [0, monthDates.count / 2, monthDates.count - 1]
        let uniqueIndices = Array(Set(rawIndices)).sorted()

        return uniqueIndices.compactMap { index in
            guard monthDates.indices.contains(index) else { return nil }
            let x = frame.minX + CGFloat(index) * (frame.width / denominator)
            let day = dateService.calendar.component(.day, from: monthDates[index])
            return DateAxisTick(id: index, label: "\(day)日", x: x)
        }
    }

    private func roundToTenth(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    private func yRange(points: [Double?], include extra: Double?) -> ClosedRange<Double> {
        let values = points.compactMap { $0 }.filter(\.isFinite) + (extra.map { [$0] } ?? []).filter(\.isFinite)
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
        guard value.isFinite else { return frame.midY }
        let denominator = range.upperBound - range.lowerBound
        guard denominator > 0, denominator.isFinite else { return frame.midY }
        let ratio = (value - range.lowerBound) / denominator
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

private struct TagMarker: Identifiable {
    let key: String
    let point: CGPoint
    let tag: DailyTag

    var id: String { key }
}

private struct TemperatureAxisTick: Identifiable {
    let id: Int
    let value: Double
    let y: CGFloat
}

private struct DateAxisTick: Identifiable {
    let id: Int
    let label: String
    let x: CGFloat
}
#endif
