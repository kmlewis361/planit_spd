//
//  Time.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/10/26.
//
import Foundation

/// A user-selected time block, designed for calendar-style drag selection.
///
/// - Uses `Date` endpoints so it can map cleanly onto calendar UI and CloudKit.
/// - `id` is derived from `(startTime, endTime)` so selections are stable in grids.
struct Time: Codable, Identifiable, Hashable {
    var startTime: Date
    var endTime: Date

    /// Stable id derived from the endpoints.
    var id: String { "\(startTime.timeIntervalSince1970)-\(endTime.timeIntervalSince1970)" }

    init(startTime: Date, endTime: Date, snapMinutes: Int = 15, calendar: Calendar = .current) {
        let snappedStart = Self.snap(startTime, toMinutes: snapMinutes, calendar: calendar, direction: .down)
        let snappedEnd = Self.snap(endTime, toMinutes: snapMinutes, calendar: calendar, direction: .up)
        if snappedEnd < snappedStart {
            self.startTime = snappedEnd
            self.endTime = snappedStart
        } else {
            self.startTime = snappedStart
            self.endTime = snappedEnd
        }
    }

    enum SnapDirection { case down, up }

    static func snap(_ date: Date, toMinutes minutes: Int, calendar: Calendar, direction: SnapDirection) -> Date {
        guard minutes > 1 else { return date }
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard
            let hour = comps.hour,
            let minute = comps.minute,
            let base = calendar.date(from: DateComponents(year: comps.year, month: comps.month, day: comps.day, hour: hour))
        else { return date }

        let remainder = minute % minutes
        let snappedMinute: Int
        switch direction {
        case .down:
            snappedMinute = minute - remainder
        case .up:
            snappedMinute = remainder == 0 ? minute : (minute + (minutes - remainder))
        }
        return calendar.date(byAdding: .minute, value: snappedMinute, to: base) ?? date
    }
}
