//
//  EventChooseFinalTimeView.swift
//  planit
//

import SwiftUI

struct EventChooseFinalTimeView: View {
    let eventId: UUID
    var onSaved: ((Time) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var event: Event = Event(
        name: "Loading…",
        description: "",
        invitees: [],
        duration: 3600,
        bestTime: Time(startTime: Date(), endTime: Date()),
        responses: []
    )
    @State private var bestTimeOptions: [(time: Time, votes: Int)] = []
    @State private var eventResponses: [Response] = []
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var validationMessage: String?

    @State private var useManualSelection = false
    @State private var selectedBestTimeId: String?
    @State private var customStartBoundaryIndex: Int = 0
    @State private var customEndBoundaryIndex: Int = 1
    @State private var manualSelectedTimes: Set<Time> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose final time")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Pick one of the best-ranked times, or choose manually on the proposed grid.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let errorMessage {
                    Text(errorMessage)
                        .planItErrorBanner()
                } else {
                    bestTimesSection
                    if !useManualSelection {
                        customWindowSection
                    }
                    manualLink
                    if useManualSelection {
                        manualGridSection
                    }
                }

                if let validationMessage {
                    Text(validationMessage)
                        .planItErrorBanner()
                }
            }
            .padding()
        }
        .planItScreen()
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer(minLength: 0)
                Button(isSubmitting ? "Saving…" : "Confirm final time") {
                    Task { await submitFinalTime() }
                }
                .buttonStyle(PlanItPrimaryButtonStyle())
                .disabled(isLoading || isSubmitting)
                Spacer(minLength: 0)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .task {
            await loadOptions()
        }
    }

    @ViewBuilder
    private var bestTimesSection: some View {
        Text("Best times")
            .planItSectionTitle()

        if bestTimeOptions.isEmpty {
            Text("No ranked times yet. Use manual selection below to pick a time on the grid.")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("Gray: no response · Green: free for full window · Light green: partial · Red: not free")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(bestTimeOptions, id: \.time.id) { option in
                    bestTimeOptionRow(option)
                }
            }
        }
    }

    private func bestTimeOptionRow(_ option: (time: Time, votes: Int)) -> some View {
        let isSelected = !useManualSelection && selectedBestTimeId == option.time.id
        return Button {
            useManualSelection = false
            manualSelectedTimes = []
            selectedBestTimeId = option.time.id
            resetCustomWindowSelection(for: option.time)
            validationMessage = nil
        } label: {
            ZStack(alignment: .topTrailing) {
                BestTimeWindowCard(
                    timeLabel: formatTimeRange(option.time),
                    fullyAvailableCount: option.votes,
                    inviteeRows: inviteeAvailabilityRows(
                        window: option.time,
                        invitees: event.invitees,
                        proposedTimes: event.proposedTimes,
                        responses: eventResponses
                    )
                )
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.45))
                    .padding(12)
            }
            .overlay(
                RoundedRectangle(cornerRadius: PlanItTheme.cardCornerRadius, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(useManualSelection)
        .opacity(useManualSelection ? 0.55 : 1)
    }

    private var manualLink: some View {
        Button(useManualSelection ? "Back to best times" : "Or choose manually on the grid") {
            useManualSelection.toggle()
            validationMessage = nil
            if useManualSelection {
                selectedBestTimeId = nil
            } else {
                manualSelectedTimes = []
            }
        }
        .buttonStyle(PlanItTextLinkButtonStyle())
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var customWindowSection: some View {
        if needsCustomWindowSelection, let window = selectedBestTimeWindow {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose start and end")
                    .planItSectionTitle()
                Text("This block is longer than your \(formatEventDuration(event.duration)) event. Pick any span within it (at least \(formatEventDuration(event.duration)), up to the full block).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    boundaryPicker(
                        title: "Start",
                        selection: $customStartBoundaryIndex,
                        options: startBoundaryIndices,
                        boundaries: blockBoundaries(for: window)
                    )
                    boundaryPicker(
                        title: "End",
                        selection: $customEndBoundaryIndex,
                        options: endBoundaryIndices(for: window),
                        boundaries: blockBoundaries(for: window)
                    )
                }
                .planItCard()

                if let preview = customWindowTime(in: window) {
                    Text("Selected: \(formatTimeRange(preview)) (\(formatEventDuration(preview.endTime.timeIntervalSince(preview.startTime))))")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.top, 4)
            .onChange(of: customStartBoundaryIndex) { _, _ in
                clampEndIndexToValidRange(for: window)
            }
        }
    }

    private func boundaryPicker(
        title: String,
        selection: Binding<Int>,
        options: [Int],
        boundaries: [Date]
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { index in
                    Text(formatClock(boundaries[index]))
                        .tag(index)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.accentColor)
        }
    }

    private var selectedBestTimeWindow: Time? {
        guard let selectedBestTimeId else { return nil }
        return bestTimeOptions.first(where: { $0.time.id == selectedBestTimeId })?.time
    }

    private var needsCustomWindowSelection: Bool {
        guard let window = selectedBestTimeWindow else { return false }
        return windowSpanExceedsDuration(window, meetingDuration: event.duration)
    }

    private func blockBoundaries(for window: Time) -> [Date] {
        timeBoundariesWithinBlock(window, proposedTimes: event.proposedTimes)
    }

    private var startBoundaryIndices: [Int] {
        guard let window = selectedBestTimeWindow else { return [] }
        let bounds = blockBoundaries(for: window)
        guard bounds.count >= 2 else { return [] }
        return Array(0 ..< bounds.count - 1)
    }

    private func endBoundaryIndices(for window: Time) -> [Int] {
        let bounds = blockBoundaries(for: window)
        return validEndBoundaryIndices(
            startIndex: customStartBoundaryIndex,
            boundaries: bounds,
            block: window,
            meetingDuration: event.duration
        )
    }

    private func resetCustomWindowSelection(for window: Time) {
        guard windowSpanExceedsDuration(window, meetingDuration: event.duration) else { return }
        let bounds = blockBoundaries(for: window)
        customStartBoundaryIndex = 0
        let validEnds = validEndBoundaryIndices(
            startIndex: 0,
            boundaries: bounds,
            block: window,
            meetingDuration: event.duration
        )
        if let defaultEnd = validEnds.first(where: { idx in
            bounds[idx].timeIntervalSince(bounds[0]) + 0.5 >= event.duration
        }) ?? validEnds.first {
            customEndBoundaryIndex = defaultEnd
        } else {
            customEndBoundaryIndex = max(1, bounds.count - 1)
        }
    }

    private func clampEndIndexToValidRange(for window: Time) {
        let valid = endBoundaryIndices(for: window)
        if valid.isEmpty {
            customEndBoundaryIndex = min(customStartBoundaryIndex + 1, blockBoundaries(for: window).count - 1)
        } else if !valid.contains(customEndBoundaryIndex) {
            customEndBoundaryIndex = valid.last ?? valid[0]
        }
    }

    private func customWindowTime(in window: Time) -> Time? {
        let bounds = blockBoundaries(for: window)
        guard customStartBoundaryIndex >= 0,
              customStartBoundaryIndex < bounds.count,
              customEndBoundaryIndex > customStartBoundaryIndex,
              customEndBoundaryIndex < bounds.count
        else { return nil }
        return Time(
            startTime: bounds[customStartBoundaryIndex],
            endTime: bounds[customEndBoundaryIndex],
            snapMinutes: 30
        )
    }

    @ViewBuilder
    private var manualGridSection: some View {
        Text("Manual selection")
            .planItSectionTitle()
        Text("Select one contiguous stretch on the grid that is at least \(formatEventDuration(event.duration)) long.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

        TimeGridSelectionView(
            selectedTimes: $manualSelectedTimes,
            allowedSlots: Set(event.proposedTimes)
        )
        .padding(8)
        .background(PlanItTheme.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: PlanItTheme.cardCornerRadius, style: .continuous))
    }

    @MainActor
    private func loadOptions() async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let fetched = try await fetchEventFromId(idString: eventId.uuidString) else {
                errorMessage = "This event couldn’t be found."
                return
            }
            event = fetched
            let responses = try await fetchResponsesForEvent(eventIdString: eventId.uuidString)
            eventResponses = responses
            let ranked = topAvailabilityWindows(
                proposedTimes: fetched.proposedTimes,
                responses: responses,
                meetingDuration: fetched.duration,
                limit: nil
            )
            bestTimeOptions = tieredBestTimes(from: ranked, minimumCount: 3)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t load this event. Please check your connection and iCloud, then try again."
        }
    }

    @MainActor
    private func submitFinalTime() async {
        validationMessage = nil
        if let trimValidation = validationMessageForCustomWindow() {
            validationMessage = trimValidation
            return
        }

        guard let finalTime = resolvedFinalTime() else {
            if useManualSelection {
                validationMessage = "Select one contiguous stretch on the grid that is at least \(formatEventDuration(event.duration)) long."
            } else if bestTimeOptions.isEmpty {
                validationMessage = "Choose a time on the grid below."
                useManualSelection = true
            } else {
                validationMessage = "Select one of the best times, or choose manually on the grid."
            }
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await saveFinalTimeToCloudKit(finalTime, eventIdString: eventId.uuidString)
            NotificationCenter.default.post(
                name: .planitEventFinalTimeDidChange,
                object: eventId.uuidString
            )
            onSaved?(finalTime)
            dismiss()
        } catch {
            validationMessage = "Couldn’t save the final time. Please try again."
        }
    }

    private func validationMessageForCustomWindow() -> String? {
        guard !useManualSelection, needsCustomWindowSelection, let window = selectedBestTimeWindow else { return nil }
        guard let custom = customWindowTime(in: window) else {
            return "Choose a start and end time within the selected block."
        }
        let span = custom.endTime.timeIntervalSince(custom.startTime)
        if span + 0.5 < event.duration {
            return "Your selection must be at least \(formatEventDuration(event.duration)) long."
        }
        return nil
    }

    private func resolvedFinalTime() -> Time? {
        if useManualSelection {
            return finalTimeWindowFromContiguousSelection(manualSelectedTimes, meetingDuration: event.duration)
        }
        guard let window = selectedBestTimeWindow else { return nil }
        if needsCustomWindowSelection {
            return customWindowTime(in: window)
        }
        return window
    }

    private func formatTimeRange(_ time: Time) -> String {
        let day = time.startTime.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        let start = time.startTime.formatted(.dateTime.hour().minute())
        let end = time.endTime.formatted(.dateTime.hour().minute())
        return "\(day) \(start)–\(end)"
    }

    private func formatClock(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    private func formatEventDuration(_ interval: TimeInterval) -> String {
        let minutes = Int((interval / 60).rounded())
        if minutes <= 0 { return "0 minutes" }
        if minutes < 60 { return "\(minutes) minutes" }
        let hours = minutes / 60
        let rem = minutes % 60
        if rem == 0 { return hours == 1 ? "1 hour" : "\(hours) hours" }
        return "\(hours) hr \(rem) min"
    }
}

#Preview {
    NavigationStack {
        EventChooseFinalTimeView(eventId: UUID())
    }
}
