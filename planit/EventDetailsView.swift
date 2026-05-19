//
//  EventDetailsView.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/10/26.
//

import SwiftUI

struct EventDetailsView: View {
    var eventId: UUID = UUID()
    var username: String = ""
    var pendingResponse: Response? = nil

    @State private var event: Event = Event(name: "Loading…", description: "", invitees: [], duration: 3600, bestTime: Time(startTime: Date(), endTime: Date()), responses: [])
    @State private var topTimes: [RankedTime] = []
    @State private var isLoadingTopTimes: Bool = true
    @State private var topTimesRefreshToken: Int = 0
    @State private var errorMessage: String?
    @State private var lastResponsesNonEmpty: Bool = false
    @State private var eventResponses: [Response] = []

    /// Recompute ranking when event metadata loads or responses refresh.
    private var rankingTaskIdentity: String {
        "\(eventId.uuidString)-\(event.proposedTimes.count)-\(Int(event.duration))-\(topTimesRefreshToken)-\(pendingResponse?.id.uuidString ?? "none")"
    }

    private struct RankedTime: Identifiable {
        let time: Time
        let votes: Int
        var id: String { time.id }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(event.name)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isOrganizer {
                    HStack {
//                        Spacer(minLength: 0)
                        NavigationLink {
                            EventCreationView(
                                editingEventId: eventId,
                                initialEvent: event,
                                onSend: { updated in
                                    event = updated
                                    topTimesRefreshToken += 1
                                }
                            )
                        } label: {
                            Text("Edit event")
                        }
                        .buttonStyle(PlanItTextLinkButtonStyle(foregroundColor: Color.accentColor))
                        Spacer(minLength: 0)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Event description")
                        .planItSectionTitle()
                    Text(event.description.isEmpty ? "—" : event.description)
                        .planItBodyOnCard()
                    Text("Event length: \(formatEventDuration(event.duration))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .planItCard()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Who's invited?")
                        .planItSectionTitle()
                    ForEach(Array(event.invitees.enumerated()), id: \.offset) { index, invitee in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(planItDisplayHandle(invitee))
                                .font(.body)
                                .foregroundStyle(.primary)
                            if index == 0 {
                                Text("(organizer)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .planItCard()

                if event.finalTime != nil || isOrganizer {
                    finalTimeSection
                }

                Text("Best times")
                    .planItSectionTitle()
                Text("Gray: no response · Green: free for full window · Light green: partial · Red: not free")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Group {
                    if isLoadingTopTimes {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if let errorMessage {
                        Text(errorMessage)
                            .planItErrorBanner()
                    } else if topTimes.isEmpty {
                        Text(bestTimesEmptyExplanation)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(topTimes) { ranked in
                                BestTimeWindowCard(
                                    timeLabel: formatTimeRange(ranked.time),
                                    fullyAvailableCount: ranked.votes,
                                    inviteeRows: inviteeAvailabilityRows(
                                        window: ranked.time,
                                        invitees: event.invitees,
                                        proposedTimes: event.proposedTimes,
                                        responses: eventResponses
                                    )
                                )
                            }
                        }
                    }
                }

                NavigationLink {
                    EventAllResponsesView(
                        eventId: eventId,
                        initialEvent: event,
                        initialResponses: eventResponses,
                        pendingResponse: pendingResponse
                    )
                } label: {
                    Text("See all responses")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                }
                .padding(.top, 4)
            }
            .padding()
        }
        .planItScreen()
        .task {
            await refreshLocalEventFromCloudKit()
        }
        .task(id: rankingTaskIdentity) {
            await refreshTopTimesFromCloudKit(prioritizing: pendingResponse)
        }
        .onReceive(NotificationCenter.default.publisher(for: .planitEventResponsesDidChange)) { notification in
            guard let changedEventId = notification.object as? String else { return }
            guard changedEventId == eventId.uuidString else { return }
            topTimesRefreshToken += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .planitEventFinalTimeDidChange)) { notification in
            guard let changedEventId = notification.object as? String else { return }
            guard changedEventId == eventId.uuidString else { return }
            Task { await refreshLocalEventFromCloudKit() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .planitEventDidChange)) { notification in
            guard let changedEventId = notification.object as? String else { return }
            guard changedEventId == eventId.uuidString else { return }
            Task { await refreshLocalEventFromCloudKit() }
            topTimesRefreshToken += 1
        }
    }

    @ViewBuilder
    private var finalTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Final time:")
                .planItSectionTitle()
            if let finalTime = event.finalTime {
                Text(formatTimeRange(finalTime))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Not set yet")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if isOrganizer {
                HStack {
                    Spacer(minLength: 0)
                    NavigationLink {
                        EventChooseFinalTimeView(eventId: eventId) { saved in
                            event.finalTime = saved
                        }
                    } label: {
                        Text(event.finalTime == nil ? "Choose final time" : "Change final time")
                    }
                    .buttonStyle(PlanItSecondaryButtonStyle())
                    Spacer(minLength: 0)
                }
            }
        }
        .planItCard()
    }

    private var isOrganizer: Bool {
        guard let organizer = event.invitees.first else { return false }
        let me = normalizedPlanItUsername(globalUsername).lowercased()
        guard !me.isEmpty else { return false }
        return normalizedPlanItUsername(organizer).lowercased() == me
    }

    private var bestTimesEmptyExplanation: String {
        if !lastResponsesNonEmpty {
            return "No responses yet."
        }
        return "No stretches of proposed slots are at least \(formatEventDuration(event.duration)) long where everyone who responded is free for every slot in that stretch."
    }

    private func formatEventDuration(_ interval: TimeInterval) -> String {
        let minutes = Int((interval / 60).rounded())
        if minutes <= 0 {
            return "0 minutes"
        }
        if minutes < 60 {
            return "\(minutes) minutes"
        }
        let hours = minutes / 60
        let rem = minutes % 60
        if rem == 0 {
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
        return "\(hours) hr \(rem) min"
    }
    @MainActor
    private func refreshLocalEventFromCloudKit() async {
        do {
            if let fetched = try await fetchEventFromId(idString: eventId.uuidString) {
                event = fetched
            }
        } catch {
            // Keep showing whatever we already have; the responses section will surface the error state.
        }
    }

    @MainActor
    private func refreshTopTimesFromCloudKit(prioritizing pending: Response?) async {
        isLoadingTopTimes = true
        defer { isLoadingTopTimes = false }
        do {
            var responses = try await fetchResponsesForEvent(eventIdString: eventId.uuidString)
            lastResponsesNonEmpty = !responses.isEmpty
            if let pending, !pending.username.isEmpty {
                // If CloudKit hasn't surfaced the new response yet, count it locally so the user sees their vote immediately.
                let pk = normalizedPlanItUsername(pending.username).lowercased()
                responses.removeAll(where: { normalizedPlanItUsername($0.username).lowercased() == pk })
                responses.append(pending)
                lastResponsesNonEmpty = true
            }
            eventResponses = responses
            let ranked = topAvailabilityWindows(
                proposedTimes: event.proposedTimes,
                responses: responses,
                meetingDuration: event.duration,
                limit: nil
            )
            topTimes = tieredBestTimes(from: ranked, minimumCount: 3).map { RankedTime(time: $0.time, votes: $0.votes) }
            errorMessage = nil
        } catch {
            topTimes = []
            eventResponses = []
            errorMessage = "Couldn’t load responses right now. Please check your connection and iCloud, then try again."
        }
    }

    private func planItDisplayHandle(_ raw: String) -> String {
        let normalized = normalizedPlanItUsername(raw)
        guard !normalized.isEmpty else { return raw }
        return normalized.hasPrefix("@") ? normalized : "@\(normalized)"
    }

    private func formatTimeRange(_ time: Time) -> String {
        let day = time.startTime.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        let start = time.startTime.formatted(.dateTime.hour().minute())
        let end = time.endTime.formatted(.dateTime.hour().minute())
        return "\(day) \(start)–\(end)"
    }
}

#Preview {
    EventDetailsView()
}
