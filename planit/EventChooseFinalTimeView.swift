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
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var validationMessage: String?

    @State private var useManualSelection = false
    @State private var selectedBestTimeId: String?
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
            validationMessage = nil
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatTimeRange(option.time))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    Text("\(option.votes) fully available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.45))
            }
            .planItCard()
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

    private func resolvedFinalTime() -> Time? {
        if useManualSelection {
            return finalTimeWindowFromContiguousSelection(manualSelectedTimes, meetingDuration: event.duration)
        }
        guard let selectedBestTimeId else { return nil }
        return bestTimeOptions.first(where: { $0.time.id == selectedBestTimeId })?.time
    }

    private func formatTimeRange(_ time: Time) -> String {
        let day = time.startTime.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        let start = time.startTime.formatted(.dateTime.hour().minute())
        let end = time.endTime.formatted(.dateTime.hour().minute())
        return "\(day) \(start)–\(end)"
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
