//
//  EventAllResponsesView.swift
//  planit
//

import SwiftUI

struct EventAllResponsesView: View {
    let eventId: UUID
    var initialEvent: Event?
    var initialResponses: [Response] = []
    var pendingResponse: Response? = nil

    @State private var event: Event?
    @State private var responses: [Response] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private struct InviteeSection: Identifiable {
        let invitee: String
        let isOrganizer: Bool
        let response: Response?
        var id: String { invitee.lowercased() }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let errorMessage {
                    Text(errorMessage)
                        .planItErrorBanner()
                } else if let event {
                    ForEach(sections(for: event)) { section in
                        inviteeSectionCard(section, event: event)
                    }
                }
            }
            .padding()
        }
        .planItScreen()
        .navigationTitle("All responses")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }

    @ViewBuilder
    private func inviteeSectionCard(_ section: InviteeSection, event: Event) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(planItDisplayHandle(section.invitee))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(section.response == nil ? PlanItTheme.availabilityNoResponse : Color.accentColor)
                    .lineLimit(1)
                if section.isOrganizer {
                    Text("(organizer)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if section.response == nil {
                    Text("No response yet")
                        .font(.caption)
                        .foregroundStyle(PlanItTheme.availabilityNoResponse)
                        .multilineTextAlignment(.trailing)
                }
            }

            if let response = section.response {
                let proposed = Set(event.proposedTimes)
                let displayTimes = Set(response.times.filter { proposed.isEmpty || proposed.contains($0) })
                TimeGridSelectionView(
                    selectedTimes: .constant(displayTimes),
                    allowedSlots: proposed.isEmpty ? nil : proposed,
                    daysToShow: 7,
                    slotMinutes: 30,
                    height: 300,
                    readOnly: true
                )
            }
        }
        .planItCard()
    }

    private func sections(for event: Event) -> [InviteeSection] {
        let byUser = responsesByNormalizedUsername(responses)
        return event.invitees.enumerated().map { index, invitee in
            let key = normalizedPlanItUsername(invitee).lowercased()
            return InviteeSection(
                invitee: invitee,
                isOrganizer: index == 0,
                response: byUser[key]
            )
        }
    }

    @MainActor
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        if let initialEvent {
            event = initialEvent
        }
        var merged = initialResponses
        if let pendingResponse, !pendingResponse.username.isEmpty {
            let pk = normalizedPlanItUsername(pendingResponse.username).lowercased()
            merged.removeAll(where: { normalizedPlanItUsername($0.username).lowercased() == pk })
            merged.append(pendingResponse)
        }
        responses = merged

        do {
            if event == nil, let fetched = try await fetchEventFromId(idString: eventId.uuidString) {
                event = fetched
            }
            if initialResponses.isEmpty {
                var loaded = try await fetchResponsesForEvent(eventIdString: eventId.uuidString)
                if let pendingResponse, !pendingResponse.username.isEmpty {
                    let pk = normalizedPlanItUsername(pendingResponse.username).lowercased()
                    loaded.removeAll(where: { normalizedPlanItUsername($0.username).lowercased() == pk })
                    loaded.append(pendingResponse)
                }
                responses = loaded
            }
            if event == nil {
                errorMessage = "This event couldn’t be found."
            }
        } catch {
            if event == nil {
                errorMessage = "Couldn’t load responses. Please check your connection and iCloud, then try again."
            }
        }
    }

    private func planItDisplayHandle(_ raw: String) -> String {
        let normalized = normalizedPlanItUsername(raw)
        guard !normalized.isEmpty else { return raw }
        return normalized.hasPrefix("@") ? normalized : "@\(normalized)"
    }
}

#Preview {
    NavigationStack {
        EventAllResponsesView(eventId: UUID())
    }
}
