//
//  EventResponseView.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/10/26.
//

import SwiftUI
import CloudKit

struct EventResponseView: View {
    var eventId: UUID = UUID()
    var onSubmit: ((Response) -> Void)? = nil
    @State private var event: Event = Event(name: "Loading…", description: "", invitees: [], duration: 3600, bestTime: Time(startTime: Date(), endTime: Date()), responses: [])

    @State private var selectedTimes: Set<Time> = []
    @State private var isLoadingEvent: Bool = true
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    /// CloudKit row for this user’s response when reopening the respond screen (nil → insert).
    @State private var existingResponseRecord: CKRecord?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(event.name)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Event description")
                        .planItSectionTitle()
                    Text(event.description.isEmpty ? "—" : event.description)
                        .planItBodyOnCard()
                }
                .planItCard()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Who's invited?")
                        .planItSectionTitle()
                    ForEach(event.invitees, id: \.self) { invitee in
                        Text(invitee)
                            .planItBodyOnCard()
                    }
                }
                .planItCard()

                Text("What times work?")
                    .planItSectionTitle()

                if isLoadingEvent {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .planItErrorBanner()
                }

                TimeGridSelectionView(
                    selectedTimes: $selectedTimes,
                    allowedSlots: Set(event.proposedTimes)
                )
                .padding(8)
                .background(PlanItTheme.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: PlanItTheme.cardCornerRadius, style: .continuous))

                Button("I'm done, show me the details!") {
                    Task { await submitResponseToCloudKitAndContinue() }
                }
                .buttonStyle(PlanItPrimaryButtonStyle(fillsAvailableWidth: true))
                .disabled(isSubmitting || isLoadingEvent)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.bottom)
        .planItScreen()
        .task {
            await loadEventFromCloudKit()
        }
    }

    @MainActor
    private func loadEventFromCloudKit() async {
        isLoadingEvent = true
        defer { isLoadingEvent = false }
        do {
            if let fetched = try await fetchEventFromId(idString: eventId.uuidString) {
                event = fetched
                errorMessage = nil
                let allowed = Set(fetched.proposedTimes)

                let meKey = normalizedPlanItUsername(globalUsername).lowercased()
                if !meKey.isEmpty {
                    do {
                        let pairs = try await fetchResponseRecordsForEvent(eventIdString: eventId.uuidString)
                        let mine = pairs.filter {
                            normalizedPlanItUsername($0.response.username).lowercased() == meKey
                        }
                        if let best = mine.max(by: { lhs, rhs in
                            let l = lhs.record.modificationDate ?? Date.distantPast
                            let r = rhs.record.modificationDate ?? Date.distantPast
                            return l < r
                        }) {
                            existingResponseRecord = best.record
                            selectedTimes = Set(best.response.times.filter { allowed.contains($0) })
                        } else {
                            existingResponseRecord = nil
                            selectedTimes = []
                        }
                    } catch {
                        existingResponseRecord = nil
                        selectedTimes = []
                    }
                } else {
                    existingResponseRecord = nil
                    selectedTimes = selectedTimes.filter { allowed.contains($0) }
                }
            } else {
                errorMessage = "This event couldn’t be found."
            }
        } catch {
            errorMessage = "Couldn’t load this event. Please check your connection and iCloud, then try again."
        }
    }

    @MainActor
    private func submitResponseToCloudKitAndContinue() async {
        let username = globalUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let times = selectedTimes.sorted { $0.startTime < $1.startTime }
        let localResponse = Response(username: username, times: times)
        if username.isEmpty {
            onSubmit?(localResponse)
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        let database = CKContainer.default().publicCloudDatabase
        let record: CKRecord
        if let existing = existingResponseRecord {
            record = existing
        } else {
            record = CKRecord(recordType: "Response")
            record["eventId"] = eventId.uuidString as CKRecordValue
            record["username"] = normalizedPlanItUsername(username).lowercased() as CKRecordValue
        }

        let timesData = (try? JSONEncoder().encode(times)) ?? Data()
        record["timesData"] = timesData as CKRecordValue

        do {
            let saved = try await database.save(record)
            existingResponseRecord = saved
            errorMessage = nil
            NotificationCenter.default.post(
                name: .planitEventResponsesDidChange,
                object: eventId.uuidString
            )
        } catch {
            errorMessage = "Couldn’t submit your response. Please try again."
        }

        onSubmit?(localResponse)
    }
}

#Preview {
    EventResponseView()
}
