//
//  EventResponseView.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/10/26.
//

import SwiftUI

struct EventResponseView: View {
    var eventId: UUID = UUID()
    //TODO fetch this from a table based off the UUID
    var onSubmit: (() -> Void)? = nil
    @State private var event: Event = Event(name: "Blank Event", description: "blank descprition", invitees: ["Hannah", "Caroline"], duration: 1, bestTime: Time(startTime: Date(), endTime: Date()), responses: [])

    @State private var selectedTimes: Set<Time> = []
    @State private var dragMode: DragMode? = nil
    @State private var dragVisited: Set<Time> = []

    public enum DragMode { case selecting, deselecting }

    var body: some View {
        Text(eventId.uuidString)
        VStack{
            Text(event.name)
                .font(.title)
                .foregroundStyle(.accent)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            Text("Event description:")
                .font(.headline)
                .foregroundStyle(.accent)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            Text(event.description)
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom)
            Text("Who's invited?")
                .font(.headline)
                .foregroundStyle(.accent)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            ForEach(event.invitees, id: \.self) {invitee in
                Text(invitee)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }

            Text("What times work?")
                .font(.headline)
                .foregroundStyle(.accent)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)

            TimeGridSelectionView(
                selectedTimes: $selectedTimes,
                dragMode: $dragMode,
                dragVisited: $dragVisited
            )
            .padding(.horizontal)
           
            Button("I'm done, show me the details!"){
                //TODO add functionality for actually sending the event to the backend and stuff
               onSubmit?()
            }
            .font(.title2)
            .padding()
                
           
            Spacer()
            
           
        }
        .padding()
    }
}


private struct TimeGridSelectionView: View {
    @Binding var selectedTimes: Set<Time>
    @Binding var dragMode: EventResponseView.DragMode?
    @Binding var dragVisited: Set<Time>

    private let daysToShow = 7
    private let startHour = 8
    private let endHour = 20
    private let slotMinutes = 30

    private var slotsPerDay: Int { ((endHour - startHour) * 60) / slotMinutes }

    var body: some View {
        GeometryReader { geo in
            let timeLabelWidth: CGFloat = 56
            let headerHeight: CGFloat = 28
            let cellWidth = max(1, (geo.size.width - timeLabelWidth) / CGFloat(daysToShow))
            let cellHeight = max(18, (geo.size.height - headerHeight) / CGFloat(slotsPerDay))

            VStack(spacing: 0) {
                headerRow(cellWidth: cellWidth, timeLabelWidth: timeLabelWidth, height: headerHeight)
                gridBody(cellWidth: cellWidth, cellHeight: cellHeight, timeLabelWidth: timeLabelWidth)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard let slot = slot(at: value.location, geo: geo, timeLabelWidth: timeLabelWidth, headerHeight: headerHeight, cellWidth: cellWidth, cellHeight: cellHeight) else {
                            return
                        }
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
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        )
    }

    private func headerRow(cellWidth: CGFloat, timeLabelWidth: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            Text("")
                .frame(width: timeLabelWidth, height: height)
            ForEach(0..<daysToShow, id: \.self) { dayIndex in
                Text(dayLabel(for: dayIndex))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                            .fill(selectedTimes.contains(slot) ? Color.accentColor.opacity(0.35) : Color.clear)
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

    private func slot(forDay dayIndex: Int, row: Int) -> Time {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let dayStart = calendar.date(byAdding: .day, value: dayIndex, to: startOfToday) ?? startOfToday
        let minutesFromStart = (startHour * 60) + (row * slotMinutes)
        let start = calendar.date(byAdding: .minute, value: minutesFromStart, to: dayStart) ?? dayStart
        let end = calendar.date(byAdding: .minute, value: minutesFromStart + slotMinutes, to: dayStart) ?? dayStart
        return Time(startTime: start, endTime: end, snapMinutes: slotMinutes, calendar: calendar)
    }

    private func slot(
        at location: CGPoint,
        geo: GeometryProxy,
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

    private func dayLabel(for dayIndex: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: dayIndex, to: Date()) ?? Date()
        return date.formatted(.dateTime.weekday(.abbreviated))
    }

    private func timeLabel(forRow row: Int) -> String {
        let minutes = (startHour * 60) + (row * slotMinutes)
        let hour = minutes / 60
        let minute = minutes % 60
        let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        return date.formatted(.dateTime.hour().minute())
    }
}

#Preview {
    EventResponseView()
}
