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
    @State private var isLoadingEvent: Bool = true

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

            if isLoadingEvent {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }

            TimeGridSelectionView(
                selectedTimes: $selectedTimes,
                allowedSlots: Set(event.proposedTimes)
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
        .task {
            await loadEventFromCloudKit()
        }
        .padding()
    }

    @MainActor
    private func loadEventFromCloudKit() async {
        isLoadingEvent = true
        defer { isLoadingEvent = false }
        if let fetched = await fetchEventFromId(idString: eventId.uuidString) {
            event = fetched
            // If the allowed set changes (e.g. after loading), drop any selections that aren't allowed.
            let allowed = Set(fetched.proposedTimes)
            selectedTimes = selectedTimes.filter { allowed.contains($0) }
        }
    }
}

#Preview {
    EventResponseView()
}
