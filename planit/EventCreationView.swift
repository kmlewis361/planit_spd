//
//  EventCreationView.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/10/26.
//

import SwiftUI
import CloudKit

struct EventCreationView: View {
   
    /// Called on the main actor after save (or if iCloud is unavailable). Passes the event so the home list can merge it even if CloudKit query lags.
    var onSend: ((Event) -> Void)? = nil
    @State private var event = Event(name: "", description: "", invitees: [], duration: 3600, bestTime: Time(startTime: Date(), endTime: Date()), responses: [])
    @State private var inviteesString: String = ""
    @State private var inviteSuggestions: [String] = []
    @State private var inviteSearchTask: Task<Void, Never>?
    @State private var inviteAutocompleteSearching = false
    @State private var inviteAutocompleteShowNoMatches = false
    @State private var proposedTimes: Set<Time> = []
    @State private var lockOuterScrollForTimeGridPaint = false
    #if DEBUG
    @State private var debugPlanItSeedStatus: String?
    #endif
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                TextField("Event name", text: $event.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .planItField()

                Text("Add a description!")
                    .planItSectionTitle()

                TextField("Event description", text: $event.description, axis: .vertical)
                    .lineLimit(3...6)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .planItField()

                Text("Event duration")
                    .planItSectionTitle()

                Stepper(
                    value: Binding(
                        get: { Int(max(30, event.duration / 60)) },
                        set: { event.duration = TimeInterval($0 * 60) }
                    ),
                    in: 30...480,
                    step: 15
                ) {
                    Text("\(Int(event.duration / 60)) minutes")
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                .planItField()

                Text("Who's invited?")
                    .planItSectionTitle()

                if !organizerPlanItUsername.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Organizer (you):")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(organizerPlanItUsername)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                inviteesAutocompleteSection

                Text("Propose times")
                    .planItSectionTitle()
                    .padding(.top, 4)

                TimeGridSelectionView(
                    selectedTimes: $proposedTimes,
                    locksAncestorVerticalScroll: $lockOuterScrollForTimeGridPaint,
                    daysToShow: 7,
                    slotMinutes: 30,
                    height: 320
                )
                .padding(8)
                .background(PlanItTheme.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: PlanItTheme.cardCornerRadius, style: .continuous))

                HStack {
                    Spacer(minLength: 0)
                Button("Send it!") {
                    // Saves the event to CloudKit (public database).
                    events.append(event)
                    let container = CKContainer.default()
                    let database = container.publicCloudDatabase
                    let record = CKRecord(recordType: "Event")
                    let proposedTimesData = encodeProposedTimesForCloudKit(proposedTimes)
                    let createdEvent = Event(
                        id: event.id,
                        name: event.name,
                        description: event.description,
                        invitees: event.invitees,
                        duration: event.duration,
                        proposedTimes: proposedTimes.sorted { $0.startTime < $1.startTime },
                        bestTime: event.bestTime,
                        responses: event.responses
                    )
                    let inviteesForCloudKit = createdEvent.invitees
                        .map { normalizedPlanItUsername($0).lowercased() }
                        .filter { !$0.isEmpty }
                    record.setValuesForKeys([
                        "id": event.id.uuidString,
                        "name": event.name,
                        "description": event.description,
                        "duration": event.duration as CKRecordValue,
                        "proposedTimesData": proposedTimesData as Any,
                        "invitees": inviteesForCloudKit as NSArray,
                    ])

                    CKContainer.default().accountStatus { accountStatus, _ in
                        if accountStatus == .noAccount {
                            Task { @MainActor in
                                onSend?(createdEvent)
                            }
                            return
                        }
                        database.save(record) { _, _ in
                            Task { @MainActor in
                                onSend?(createdEvent)
                            }
                        }
                    }
                }
                .buttonStyle(PlanItPrimaryButtonStyle())
                    Spacer(minLength: 0)
                }
                .padding(.top, 8)

                Color.clear.frame(height: 24)
            }
            .padding()
        }
        .planItScreen()
        .scrollDismissesKeyboard(.interactively)
        .scrollDisabled(lockOuterScrollForTimeGridPaint)
    }

    private var inviteesAutocompleteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Invite others (comma-separated, optional)", text: $inviteesString)
                .font(.body)
                .foregroundStyle(.primary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .textContentType(nil)
                .planItField()

            if inviteAutocompleteSearching {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Looking up usernames…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !inviteSuggestions.isEmpty {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(inviteSuggestions.indices, id: \.self) { idx in
                        let name = inviteSuggestions[idx]
                        Button {
                            applyInviteeSuggestion(name)
                        } label: {
                            HStack {
                                Text(name)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if idx < inviteSuggestions.count - 1 {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .background(PlanItTheme.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: PlanItTheme.fieldCornerRadius, style: .continuous))
            } else if inviteAutocompleteShowNoMatches {
                Text("No matching PlanIt users for that text.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            #if DEBUG
            debugAutocompleteSeedControls
            #endif
        }
        .onAppear {
            hydrateAdditionalInviteesFieldFromEvent()
            syncInviteesFromString()
        }
        .onChange(of: inviteesString) { _, newValue in
            inviteAutocompleteShowNoMatches = false
            syncInviteesFromString()
            scheduleInviteAutocomplete(for: newValue)
        }
    }

    #if DEBUG
    @ViewBuilder
    private var debugAutocompleteSeedControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button("Insert CloudKit test users (DEBUG)") {
                Task {
                    let message = await seedPlanItAutocompleteDummyUsersForDebug()
                    await MainActor.run { debugPlanItSeedStatus = message }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            if let debugPlanItSeedStatus {
                Text(debugPlanItSeedStatus)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 4)
    }
    #endif

    private func encodeProposedTimesForCloudKit(_ times: Set<Time>) -> Data? {
        // CloudKit can store `Data` directly; encoding keeps the schema simple.
        let sorted = times.sorted { $0.startTime < $1.startTime }
        return try? JSONEncoder().encode(sorted)
    }

    /// Normalized signed-in user; stored as `event.invitees[0]` (organizer).
    private var organizerPlanItUsername: String {
        normalizedPlanItUsername(globalUsername)
    }

    /// `inviteesString` holds everyone except the organizer; `event.invitees` is `[organizer] + extras`.
    private func syncInviteesFromString() {
        let org = organizerPlanItUsername
        var extras = inviteesString
            .split(separator: ",")
            .map { normalizedPlanItUsername(String($0)) }
            .filter { !$0.isEmpty }
        if !org.isEmpty {
            extras.removeAll { $0.caseInsensitiveCompare(org) == .orderedSame }
        }
        if org.isEmpty {
            event.invitees = extras
        } else {
            event.invitees = [org] + extras
        }
    }

    /// Loads the text field from `event.invitees`, stripping the leading organizer row when present.
    private func hydrateAdditionalInviteesFieldFromEvent() {
        let org = organizerPlanItUsername
        guard inviteesString.isEmpty, !event.invitees.isEmpty else {
            return
        }
        if !org.isEmpty,
           let first = event.invitees.first,
           first.caseInsensitiveCompare(org) == .orderedSame {
            inviteesString = event.invitees.dropFirst().joined(separator: ", ")
        } else {
            inviteesString = event.invitees.joined(separator: ", ")
        }
    }

    private func currentInviteeTypingFragment(from fullText: String) -> String {
        let segments = fullText.split(separator: ",", omittingEmptySubsequences: false).map { normalizedPlanItUsername(String($0)) }
        return segments.last ?? ""
    }

    private func committedInviteeSet(from fullText: String) -> Set<String> {
        let segments = fullText.split(separator: ",", omittingEmptySubsequences: false).map { normalizedPlanItUsername(String($0)) }
        guard segments.count > 1 else { return [] }
        return Set(segments.dropLast().filter { !$0.isEmpty }.map { $0.lowercased() })
    }

    private func scheduleInviteAutocomplete(for fullText: String) {
        inviteSearchTask?.cancel()
        inviteSearchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            await refreshInviteSuggestions(for: fullText)
        }
    }

    @MainActor
    private func refreshInviteSuggestions(for fullText: String) async {
        inviteAutocompleteSearching = true
        inviteAutocompleteShowNoMatches = false
        defer { inviteAutocompleteSearching = false }

        let fragment = currentInviteeTypingFragment(from: fullText)
        guard fragment.count >= 1 else {
            inviteSuggestions = []
            return
        }
        guard fragment.range(of: "^[a-zA-Z0-9_]*$", options: .regularExpression) != nil else {
            inviteSuggestions = []
            return
        }

        do {
            var names = try await searchPlanItUsernames(prefix: fragment, limit: 12)
            let committed = committedInviteeSet(from: fullText)
            let org = organizerPlanItUsername
            names.removeAll { name in
                if !org.isEmpty, name.caseInsensitiveCompare(org) == .orderedSame {
                    return true
                }
                return committed.contains(name.lowercased())
            }
            inviteSuggestions = names
            inviteAutocompleteShowNoMatches = names.isEmpty && fragment.count >= 2
        } catch {
            inviteSuggestions = []
            inviteAutocompleteShowNoMatches = false
        }
    }

    private func applyInviteeSuggestion(_ picked: String) {
        let trimmedPick = normalizedPlanItUsername(picked)
        guard !trimmedPick.isEmpty else { return }

        var chunks = inviteesString.split(separator: ",", omittingEmptySubsequences: false).map { String($0) }
        if chunks.isEmpty {
            chunks = [trimmedPick]
        } else {
            chunks[chunks.count - 1] = trimmedPick
        }
        inviteesString = chunks.joined(separator: ", ") + ", "
        inviteSuggestions = []
        syncInviteesFromString()
    }
}

#Preview {
    EventCreationView(onSend: { _ in })
}
