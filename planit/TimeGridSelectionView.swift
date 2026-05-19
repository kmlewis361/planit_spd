import SwiftUI
import UIKit

struct TimeGridSelectionView: View {
    @Binding var selectedTimes: Set<Time>
    /// Set `true` while drag-to-paint is active so a wrapping SwiftUI `ScrollView` can use `.scrollDisabled($0)` (otherwise the sheet scrolls with the finger).
    @Binding var locksAncestorVerticalScroll: Bool
    /// If set, only these slots are selectable (others are shown disabled).
    private let allowedSlots: Set<Time>?

    private let daysToShow: Int
    /// First slot of each day starts at this hour (e.g. `0` = midnight).
    private let startHour: Int
    /// Hour **after** the last slot starts (e.g. `24` = slots through 23:30–24:00).
    private let endHour: Int
    /// Scroll view initially aligns so this hour is near the top (e.g. `8` = 8:00).
    private let initialVisibleHour: Int
    private let slotMinutes: Int
    private let height: CGFloat

    /// 0 = the week that contains today; +1 = next week, −1 = previous.
    @State private var weekOffset: Int = 0

    /// Bumped to re-align `UIScrollView` content to `initialScrollRowIndex` (replaces `ScrollViewProxy`).
    @State private var scrollPulse: Int = 0

    @State private var dragMode: DragMode? = nil
    @State private var dragVisited: Set<Time> = []
    /// Avoid treating finger-up after a paint drag as a discrete tap toggle.
    @State private var suppressTapSelectionUntil: Date?

    private enum DragMode { case selecting, deselecting }

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
    /// Fixed row height inside the scroll view (full day uses many rows).
    private let scrollRowHeight: CGFloat = 22

    // MARK: Grid contrast (readable but lighter borders than the previous pass)
    private var gridLineColor: Color { Color.primary.opacity(0.14) }
    private let gridCellStrokeWidth: CGFloat = 0.5
    private var gridChromeBackground: Color { PlanItTheme.fieldBackground }
    private var gridAvailableSlotFill: Color { Color.primary.opacity(0.05) }
    private var gridDisabledSlotFill: Color { Color.primary.opacity(0.1) }
    private var gridSelectedSlotFill: Color { Color.accentColor.opacity(0.88) }
    private var timeLabelColor: Color { Color.primary.opacity(0.68) }
    private var headerSecondaryTextColor: Color { Color.primary.opacity(0.52) }

    private var slotsPerDay: Int { max(1, ((endHour - startHour) * 60) / slotMinutes) }

    /// Row index whose **start** time is `initialVisibleHour` (clamped).
    private var initialScrollRowIndex: Int {
        let row = (initialVisibleHour - startHour) * 60 / slotMinutes
        return min(max(0, row), slotsPerDay - 1)
    }

    init(
        selectedTimes: Binding<Set<Time>>,
        locksAncestorVerticalScroll: Binding<Bool> = .constant(false),
        allowedSlots: Set<Time>? = nil,
        daysToShow: Int = 7,
        startHour: Int = 0,
        endHour: Int = 24,
        initialVisibleHour: Int = 8,
        slotMinutes: Int = 30,
        height: CGFloat = 320
    ) {
        self._selectedTimes = selectedTimes
        self._locksAncestorVerticalScroll = locksAncestorVerticalScroll
        self.allowedSlots = allowedSlots
        self.daysToShow = daysToShow
        self.startHour = startHour
        self.endHour = endHour
        self.initialVisibleHour = initialVisibleHour
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

                VStack(spacing: 0) {
                    headerRow(cellWidth: cellWidth, timeLabelWidth: timeLabelWidth, height: headerHeight)
                    TimeGridScrollContainer(
                        contentHeight: CGFloat(slotsPerDay) * scrollRowHeight,
                        rowHeight: scrollRowHeight,
                        scrollPulse: scrollPulse,
                        scrollTargetRow: initialScrollRowIndex,
                        handleTap: { point in
                            handleSlotTap(
                                at: point,
                                timeLabelWidth: timeLabelWidth,
                                cellWidth: cellWidth,
                                cellHeight: scrollRowHeight
                            )
                        },
                        handlePaint: { point in
                            handlePaintDrag(
                                at: point,
                                timeLabelWidth: timeLabelWidth,
                                cellWidth: cellWidth,
                                cellHeight: scrollRowHeight
                            )
                        },
                        handlePaintEnd: {
                            dragMode = nil
                            dragVisited.removeAll()
                        },
                        handlePaintSessionActive: { active in
                            locksAncestorVerticalScroll = active
                        }
                    ) {
                        ZStack(alignment: .topLeading) {
                            VStack(spacing: 0) {
                                ForEach(0..<slotsPerDay, id: \.self) { row in
                                    gridRow(row: row, cellWidth: cellWidth, timeLabelWidth: timeLabelWidth)
                                        .frame(height: scrollRowHeight)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .onAppear {
                        scheduleScrollToInitialHour()
                    }
                    .onChange(of: weekOffset) { _, _ in
                        scheduleScrollToInitialHour()
                    }
                    .onChange(of: allowedSlotsFingerprint) { _, _ in
                        scheduleScrollToInitialHour()
                    }
                }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            clampWeekOffsetToAllowedRangeIfNeeded()
        }
        .onChange(of: allowedSlotsFingerprint) { _, _ in
            clampWeekOffsetToAllowedRangeIfNeeded()
        }
        .onDisappear {
            locksAncestorVerticalScroll = false
        }
    }

    private func scheduleScrollToInitialHour() {
        DispatchQueue.main.async {
            scrollPulse += 1
        }
    }

    private func gridRow(row: Int, cellWidth: CGFloat, timeLabelWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Text(timeLabel(forRow: row))
                .font(.caption2)
                .foregroundStyle(timeLabelColor)
                .frame(width: timeLabelWidth, height: scrollRowHeight, alignment: .trailing)
                .padding(.trailing, 6)
                .contentShape(Rectangle())

            ForEach(0..<daysToShow, id: \.self) { dayIndex in
                let slot = slot(forDay: dayIndex, row: row)
                Rectangle()
                    .fill(fillColor(for: slot))
                    .frame(width: cellWidth, height: scrollRowHeight)
                    .overlay(
                        Rectangle()
                            .stroke(gridLineColor, lineWidth: gridCellStrokeWidth)
                    )
            }
        }
    }

    /// Location is in the overlay’s coordinate space (full grid row width including the time gutter).
    private func slotInGrid(at location: CGPoint, timeLabelWidth: CGFloat, cellWidth: CGFloat, cellHeight: CGFloat) -> Time? {
        let x = location.x - timeLabelWidth
        let y = location.y
        guard x >= 0, y >= 0 else { return nil }
        let dayIndex = Int(floor(x / cellWidth))
        let row = Int(floor(y / cellHeight))
        guard (0..<daysToShow).contains(dayIndex), (0..<slotsPerDay).contains(row) else { return nil }
        return slot(forDay: dayIndex, row: row)
    }

    private func handleSlotTap(at location: CGPoint, timeLabelWidth: CGFloat, cellWidth: CGFloat, cellHeight: CGFloat) {
        if let until = suppressTapSelectionUntil {
            if Date() < until { return }
            suppressTapSelectionUntil = nil
        }
        guard let slot = slotInGrid(at: location, timeLabelWidth: timeLabelWidth, cellWidth: cellWidth, cellHeight: cellHeight) else {
            return
        }
        if let allowedSlots, !allowedSlots.contains(slot) { return }
        if selectedTimes.contains(slot) {
            selectedTimes.remove(slot)
        } else {
            selectedTimes.insert(slot)
        }
    }

    private func handlePaintDrag(at location: CGPoint, timeLabelWidth: CGFloat, cellWidth: CGFloat, cellHeight: CGFloat) {
        guard let slot = slotInGrid(at: location, timeLabelWidth: timeLabelWidth, cellWidth: cellWidth, cellHeight: cellHeight) else {
            return
        }
        if let allowedSlots, !allowedSlots.contains(slot) { return }
        if dragMode == nil {
            dragMode = selectedTimes.contains(slot) ? .deselecting : .selecting
            dragVisited.removeAll()
        }
        if dragVisited.contains(slot) { return }
        dragVisited.insert(slot)
        // Refresh through drag so finger-up cannot fire SpatialTap before suppression exists (gesture end order is undefined).
        suppressTapSelectionUntil = Date().addingTimeInterval(0.35)
        switch dragMode {
        case .selecting:
            selectedTimes.insert(slot)
        case .deselecting:
            selectedTimes.remove(slot)
        case .none:
            break
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
            .foregroundStyle(prevDisabled ? Color.primary.opacity(0.38) : .primary)
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
            .foregroundStyle(nextDisabled ? Color.primary.opacity(0.38) : .primary)
            .disabled(nextDisabled)
            .accessibilityLabel("Next week")
        }
        .padding(.horizontal, 8)
        .background(gridChromeBackground)
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
                        .foregroundStyle(todayColumn ? Color.accentColor.opacity(0.95) : headerSecondaryTextColor)
                }
                .frame(width: cellWidth, height: height)
            }
        }
        .background(gridChromeBackground)
    }

    private func fillColor(for slot: Time) -> Color {
        if selectedTimes.contains(slot) {
            return gridSelectedSlotFill
        }
        if let allowedSlots, !allowedSlots.contains(slot) {
            return gridDisabledSlotFill
        }
        return gridAvailableSlotFill
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
        let cal = Calendar.current
        let date = cal.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        return date.formatted(.dateTime.hour().minute())
    }
}

// MARK: - UIKit scroll host (SwiftUI ScrollView + Drag/LongPress reliably blocks scrolling)

private final class TimeGridScrollCoordinator: NSObject, UIGestureRecognizerDelegate {
    weak var scrollView: UIScrollView?
    var hostingController: UIHostingController<AnyView>?

    let rowHeight: CGFloat

    var onTap: ((CGPoint) -> Void)?
    var onPaint: ((CGPoint) -> Void)?
    var onPaintEnd: (() -> Void)?
    var onPaintSessionActive: ((Bool) -> Void)?

    var lastScrollPulse: Int = -1

    /// Long-press paint reached `.began` — inner `UIScrollView` and ancestor scroll should be locked.
    private var paintSessionActive = false

    init(rowHeight: CGFloat) {
        self.rowHeight = rowHeight
    }

    func gestureRecognizer(_: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool {
        true
    }

    @objc func handleTap(_ g: UITapGestureRecognizer) {
        guard let v = hostingController?.view else { return }
        onTap?(g.location(in: v))
    }

    @objc func handleLongPress(_ g: UILongPressGestureRecognizer) {
        guard let sv = scrollView, let v = hostingController?.view else { return }
        let p = g.location(in: v)
        switch g.state {
        case .began:
            paintSessionActive = true
            sv.isScrollEnabled = false
            sv.panGestureRecognizer.isEnabled = false
            onPaintSessionActive?(true)
            onPaint?(p)
        case .changed:
            onPaint?(p)
        case .ended, .cancelled, .failed:
            if paintSessionActive {
                paintSessionActive = false
                sv.isScrollEnabled = true
                sv.panGestureRecognizer.isEnabled = true
                onPaintSessionActive?(false)
            }
            onPaintEnd?()
        default:
            break
        }
    }

    func applyScroll(scrollView: UIScrollView, row: Int) {
        scrollView.layoutIfNeeded()
        guard scrollView.bounds.height > 1 else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.applyScroll(scrollView: scrollView, row: row)
            }
            return
        }
        let y = CGFloat(row) * rowHeight
        let maxY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        let clamped = min(max(0, y), maxY)
        scrollView.setContentOffset(CGPoint(x: 0, y: clamped), animated: false)
    }
}

private struct TimeGridScrollContainer<Content: View>: UIViewRepresentable {
    let contentHeight: CGFloat
    let rowHeight: CGFloat
    var scrollPulse: Int
    var scrollTargetRow: Int

    let handleTap: (CGPoint) -> Void
    let handlePaint: (CGPoint) -> Void
    let handlePaintEnd: () -> Void
    let handlePaintSessionActive: (Bool) -> Void

    @ViewBuilder var content: () -> Content

    func makeCoordinator() -> TimeGridScrollCoordinator {
        TimeGridScrollCoordinator(rowHeight: rowHeight)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let coordinator = context.coordinator
        let sv = UIScrollView()
        coordinator.scrollView = sv
        sv.alwaysBounceVertical = true
        sv.showsVerticalScrollIndicator = true
        sv.backgroundColor = .clear
        sv.delaysContentTouches = false
        sv.canCancelContentTouches = true

        let hc = UIHostingController(rootView: AnyView(content()))
        hc.view.backgroundColor = .clear
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        coordinator.hostingController = hc

        sv.addSubview(hc.view)

        NSLayoutConstraint.activate([
            hc.view.leadingAnchor.constraint(equalTo: sv.contentLayoutGuide.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: sv.contentLayoutGuide.trailingAnchor),
            hc.view.topAnchor.constraint(equalTo: sv.contentLayoutGuide.topAnchor),
            hc.view.bottomAnchor.constraint(equalTo: sv.contentLayoutGuide.bottomAnchor),
            hc.view.widthAnchor.constraint(equalTo: sv.frameLayoutGuide.widthAnchor),
            hc.view.heightAnchor.constraint(equalToConstant: contentHeight),
        ])

        let tap = UITapGestureRecognizer(target: coordinator, action: #selector(TimeGridScrollCoordinator.handleTap(_:)))
        tap.delegate = coordinator
        sv.addGestureRecognizer(tap)

        let longPress = UILongPressGestureRecognizer(target: coordinator, action: #selector(TimeGridScrollCoordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.16
        longPress.allowableMovement = 14
        longPress.delegate = coordinator
        sv.addGestureRecognizer(longPress)

        coordinator.onTap = handleTap
        coordinator.onPaint = handlePaint
        coordinator.onPaintEnd = handlePaintEnd
        coordinator.onPaintSessionActive = handlePaintSessionActive

        return sv
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.hostingController?.rootView = AnyView(content())
        coordinator.onTap = handleTap
        coordinator.onPaint = handlePaint
        coordinator.onPaintEnd = handlePaintEnd
        coordinator.onPaintSessionActive = handlePaintSessionActive

        if coordinator.lastScrollPulse != scrollPulse {
            coordinator.lastScrollPulse = scrollPulse
            DispatchQueue.main.async {
                coordinator.applyScroll(scrollView: scrollView, row: scrollTargetRow)
            }
        }
    }
}
