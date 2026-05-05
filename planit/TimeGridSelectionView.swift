import SwiftUI

struct TimeGridSelectionView: View {
    @Binding var selectedTimes: Set<Time>
    /// If set, only these slots are selectable (others are shown disabled).
    private let allowedSlots: Set<Time>?

    private let daysToShow: Int
    private let startHour: Int
    private let endHour: Int
    private let slotMinutes: Int
    private let height: CGFloat

    @State private var dragMode: DragMode? = nil
    @State private var dragVisited: Set<Time> = []
    /// 0 = the week that contains today; +1 = next week, −1 = previous.
    @State private var weekOffset: Int = 0

    private enum DragMode { case selecting, deselecting }

    private var slotsPerDay: Int { ((endHour - startHour) * 60) / slotMinutes }

    /// When non-zero, `allowedSlots` changed — reclamp week navigation for event response.
    private var allowedSlotsFingerprint: Int {
        guard let slots = allowedSlots, !slots.isEmpty else { return 0 }
        var hasher = Hasher()
        hasher.combine(slots.count)
        for t in slots.sorted(by: { $0.startTime < $1.startTime }) {
            hasher.combine(t.startTime.timeIntervalSince1970)
            hasher.combine(t.endTime.timeIntervalSince1970)
        }
        return hasher.finalize()
    }

    private let weekNavHeight: CGFloat = 40
    private let headerHeight: CGFloat = 40

    init(
        selectedTimes: Binding<Set<Time>>,
        allowedSlots: Set<Time>? = nil,
        daysToShow: Int = 7,
        startHour: Int = 8,
        endHour: Int = 20,
        slotMinutes: Int = 30,
        height: CGFloat = 320
    ) {
        self._selectedTimes = selectedTimes
        self.allowedSlots = allowedSlots
        self.daysToShow = daysToShow
        self.startHour = startHour
        self.endHour = endHour
        self.slotMinutes = slotMinutes
        self.height = height
    }

    var body: some View {
        VStack(spacing: 0) {
            weekNavigationBar
                .frame(height: weekNavHeight)
            GeometryReader { geo in
                let timeLabelWidth: CGFloat = 56
                let cellWidth = max(1, (geo.size.width - timeLabelWidth) / CGFloat(daysToShow))
                let slotRows = max(1, slotsPerDay)
                let cellHeight = max(18, (geo.size.height - headerHeight) / CGFloat(slotRows))

                VStack(spacing: 0) {
                    headerRow(cellWidth: cellWidth, timeLabelWidth: timeLabelWidth, height: headerHeight)
                    gridBody(cellWidth: cellWidth, cellHeight: cellHeight, timeLabelWidth: timeLabelWidth)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard let slot = slot(at: value.location, timeLabelWidth: timeLabelWidth, headerHeight: headerHeight, cellWidth: cellWidth, cellHeight: cellHeight) else {
                                return
                            }
                            if let allowedSlots, !allowedSlots.contains(slot) { return }
                            if dragMode == nil {
                                dragMode = selectedTimes.contains(slot) ? .deselecting : .selecting
                                dragVisited.removeAll()
                            }
                            if dragVisited.contains(slot) { return }
                            dragVisited.insert(slot)
                            switch dragMode {
                            case .selecting:
                                selectedTimes.insert(slot)
                            case .deselecting:
                                selectedTimes.remove(slot)
                            case .none:
                                break
                            }
                        }
                        .onEnded { _ in
                            dragMode = nil
                            dragVisited.removeAll()
                        }
                )
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        )
        .onAppear {
            clampWeekOffsetToAllowedRangeIfNeeded()
        }
        .onChange(of: allowedSlotsFingerprint) { _, _ in
            clampWeekOffsetToAllowedRangeIfNeeded()
        }
    }

    /// Earliest / latest `weekOffset` (relative to “this calendar week”) that still contains a proposed slot. `nil` when not restricting navigation (creation flow).
    private func allowedWeekOffsetBounds(calendar: Calendar = .current) -> ClosedRange<Int>? {
        guard let slots = allowedSlots, !slots.isEmpty else { return nil }
        let refStart = startOfWeek(containing: calendar.startOfDay(for: Date()), calendar: calendar)
        var minWeekStart: Date?
        var maxWeekStart: Date?
        for t in slots {
            let ws = startOfWeek(containing: t.startTime, calendar: calendar)
            minWeekStart = minWeekStart.map { min($0, ws) } ?? ws
            maxWeekStart = maxWeekStart.map { max($0, ws) } ?? ws
        }
        guard let loWeek = minWeekStart, let hiWeek = maxWeekStart else { return nil }
        let lo = weeksOffset(fromReferenceWeekStart: refStart, toWeekStart: loWeek, calendar: calendar)
        let hi = weeksOffset(fromReferenceWeekStart: refStart, toWeekStart: hiWeek, calendar: calendar)
        return lo...hi
    }

    private func weeksOffset(fromReferenceWeekStart ref: Date, toWeekStart target: Date, calendar: Calendar) -> Int {
        let days = calendar.dateComponents([.day], from: ref, to: target).day ?? 0
        return days / 7
    }

    private func clampWeekOffsetToAllowedRangeIfNeeded() {
        guard let bounds = allowedWeekOffsetBounds() else { return }
        weekOffset = min(max(weekOffset, bounds.lowerBound), bounds.upperBound)
    }

    private var weekNavigationBar: some View {
        let calendar = Calendar.current
        let start = firstDayOfDisplayedWeek(calendar: calendar)
        let end = calendar.date(byAdding: .day, value: daysToShow - 1, to: start) ?? start
        let bounds = allowedWeekOffsetBounds(calendar: calendar)
        let prevDisabled = bounds.map { weekOffset <= $0.lowerBound } ?? false
        let nextDisabled = bounds.map { weekOffset >= $0.upperBound } ?? false

        return HStack(spacing: 12) {
            Button {
                weekOffset -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(prevDisabled ? Color.secondary.opacity(0.35) : .primary)
            .disabled(prevDisabled)
            .accessibilityLabel("Previous week")

            Spacer(minLength: 8)

            Text(weekRangeTitle(start: start, end: end, calendar: calendar))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 8)

            Button {
                weekOffset += 1
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(nextDisabled ? Color.secondary.opacity(0.35) : .primary)
            .disabled(nextDisabled)
            .accessibilityLabel("Next week")
        }
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.06))
    }

    private func weekRangeTitle(start: Date, end: Date, calendar: Calendar) -> String {
        let m1 = start.formatted(.dateTime.month(.abbreviated).day())
        let y1 = start.formatted(.dateTime.year())
        let m2 = end.formatted(.dateTime.month(.abbreviated).day())
        let y2 = end.formatted(.dateTime.year())
        if y1 == y2 {
            return "\(m1) – \(m2), \(y1)"
        }
        return "\(m1), \(y1) – \(m2), \(y2)"
    }

    /// First column = start of the **calendar week** (respects locale `firstWeekday`) + `weekOffset` full weeks.
    private func firstDayOfDisplayedWeek(calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: Date())
        let weekStart = startOfWeek(containing: today, calendar: calendar)
        return calendar.date(byAdding: .day, value: weekOffset * 7, to: weekStart) ?? weekStart
    }

    private func startOfWeek(containing date: Date, calendar: Calendar) -> Date {
        let dayStart = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: dayStart)
        let first = calendar.firstWeekday
        let daysFromStart = (weekday - first + 7) % 7
        return calendar.date(byAdding: .day, value: -daysFromStart, to: dayStart) ?? dayStart
    }

    private func headerRow(cellWidth: CGFloat, timeLabelWidth: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            Text("")
                .frame(width: timeLabelWidth, height: height)
            ForEach(0..<daysToShow, id: \.self) { dayIndex in
                let todayColumn = isTodayColumn(dayIndex)
                VStack(spacing: 2) {
                    Text(dayName(for: dayIndex))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(todayColumn ? Color.accentColor : .primary)
                    Text(calendarDateLine(for: dayIndex))
                        .font(.caption2)
                        .foregroundStyle(todayColumn ? Color.accentColor.opacity(0.9) : .secondary)
                }
                .frame(width: cellWidth, height: height)
            }
        }
        .background(Color.secondary.opacity(0.06))
    }

    private func gridBody(cellWidth: CGFloat, cellHeight: CGFloat, timeLabelWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<slotsPerDay, id: \.self) { row in
                HStack(spacing: 0) {
                    Text(timeLabel(forRow: row))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: timeLabelWidth, height: cellHeight, alignment: .trailing)
                        .padding(.trailing, 6)
                    ForEach(0..<daysToShow, id: \.self) { dayIndex in
                        let slot = slot(forDay: dayIndex, row: row)
                        Rectangle()
                            .fill(fillColor(for: slot))
                            .frame(width: cellWidth, height: cellHeight)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
                            )
                    }
                }
            }
        }
    }

    private func fillColor(for slot: Time) -> Color {
        if selectedTimes.contains(slot) {
            return Color.accentColor.opacity(0.35)
        }
        if let allowedSlots, !allowedSlots.contains(slot) {
            return Color.secondary.opacity(0.06)
        }
        return Color.clear
    }

    private func slot(forDay dayIndex: Int, row: Int) -> Time {
        let calendar = Calendar.current
        let weekFirst = firstDayOfDisplayedWeek(calendar: calendar)
        let dayStart = calendar.date(byAdding: .day, value: dayIndex, to: weekFirst) ?? weekFirst
        let minutesFromStart = (startHour * 60) + (row * slotMinutes)
        let start = calendar.date(byAdding: .minute, value: minutesFromStart, to: dayStart) ?? dayStart
        let end = calendar.date(byAdding: .minute, value: minutesFromStart + slotMinutes, to: dayStart) ?? dayStart
        return Time(startTime: start, endTime: end, snapMinutes: slotMinutes, calendar: calendar)
    }

    private func slot(
        at location: CGPoint,
        timeLabelWidth: CGFloat,
        headerHeight: CGFloat,
        cellWidth: CGFloat,
        cellHeight: CGFloat
    ) -> Time? {
        let x = location.x - timeLabelWidth
        let y = location.y - headerHeight
        guard x >= 0, y >= 0 else { return nil }
        let dayIndex = Int(floor(x / cellWidth))
        let row = Int(floor(y / cellHeight))
        guard (0..<daysToShow).contains(dayIndex), (0..<slotsPerDay).contains(row) else { return nil }
        return slot(forDay: dayIndex, row: row)
    }

    private func isTodayColumn(_ dayIndex: Int) -> Bool {
        let calendar = Calendar.current
        let weekFirst = firstDayOfDisplayedWeek(calendar: calendar)
        guard let date = calendar.date(byAdding: .day, value: dayIndex, to: weekFirst) else { return false }
        return calendar.isDateInToday(date)
    }

    private func dayName(for dayIndex: Int) -> String {
        let calendar = Calendar.current
        let weekFirst = firstDayOfDisplayedWeek(calendar: calendar)
        let date = calendar.date(byAdding: .day, value: dayIndex, to: weekFirst) ?? weekFirst
        return date.formatted(.dateTime.weekday(.abbreviated))
    }

    private func calendarDateLine(for dayIndex: Int) -> String {
        let calendar = Calendar.current
        let weekFirst = firstDayOfDisplayedWeek(calendar: calendar)
        let date = calendar.date(byAdding: .day, value: dayIndex, to: weekFirst) ?? weekFirst
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func timeLabel(forRow row: Int) -> String {
        let minutes = (startHour * 60) + (row * slotMinutes)
        let hour = minutes / 60
        let minute = minutes % 60
        let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        return date.formatted(.dateTime.hour().minute())
    }
}
