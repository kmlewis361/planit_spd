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

    @State private var event: Event = Event(name: "Loading…", description: "", invitees: [], duration: 1, bestTime: Time(startTime: Date(), endTime: Date()), responses: [])
    @State private var topTimes: [RankedTime] = []
    @State private var isLoadingTopTimes: Bool = true
    @State private var topTimesRefreshToken: Int = 0
    @State private var errorMessage: String?
    private var topTimesTaskKey: String { "\(eventId.uuidString)-\(pendingResponse?.id.uuidString ?? "none")-\(topTimesRefreshToken)" }

    private struct RankedTime: Identifiable {
        let time: Time
        let votes: Int
        var id: String { time.id }
    }
    var body: some View {
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

            Text("Best times:")
                .font(.headline)
                .foregroundStyle(.accent)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)
            if isLoadingTopTimes {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.secondary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
            } else if topTimes.isEmpty {
                Text("No responses yet.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(topTimes) { ranked in
                        HStack(alignment: .firstTextBaseline) {
                            Text(formatTimeRange(ranked.time))
                                .font(.body)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(ranked.votes)")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
            }
            //add some stuff for showing more times and who's free
            
            
                
           
            Spacer()
            
           
        }
        .task {
            await refreshLocalEventFromCloudKit()
        }
        .task(id: topTimesTaskKey) {
            await refreshTopTimesFromCloudKit(prioritizing: pendingResponse)
        }
        .onReceive(NotificationCenter.default.publisher(for: .planitEventResponsesDidChange)) { notification in
            guard let changedEventId = notification.object as? String else { return }
            guard changedEventId == eventId.uuidString else { return }
            topTimesRefreshToken += 1
        }
        .padding()
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
            if let pending, !pending.username.isEmpty {
                // If CloudKit hasn't surfaced the new response yet, count it locally so the user sees their vote immediately.
                responses.removeAll(where: { $0.username == pending.username })
                responses.append(pending)
            }
            let ranked = topTimeSlots(from: responses, limit: 3)
            topTimes = ranked.map { RankedTime(time: $0.time, votes: $0.votes) }
            errorMessage = nil
        } catch {
            topTimes = []
            errorMessage = "Couldn’t load responses right now. Please check your connection and iCloud, then try again."
        }
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
