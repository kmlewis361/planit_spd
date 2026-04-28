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
    @State private var event = Event(name: "", description: "blank descprition", invitees: ["Hannah", "Caroline"], duration: 1, bestTime: Time(startTime: Date(), endTime: Date()), responses: [])
    @State private var inviteesString: String = ""
    @State private var proposedTimes: Set<Time> = []
    var body: some View {
        VStack{
            TextField("Event Name", text: $event.name)
                .font(.title)
                .foregroundStyle(.accent)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            Text("Add a description!")
                .font(.headline)
                .foregroundStyle(.accent)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            TextField("Event description", text: $event.description)
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
            //TODO add text input with autocomplete and stuff
            TextField("Enter usernames (split by commas)", text: $inviteesString)
                .font(.body)
               .foregroundStyle(.primary)
               .multilineTextAlignment(.leading)
               .frame(maxWidth: .infinity, alignment: .leading)
               .padding(.horizontal)
               .onChange(of: inviteesString) {
                   event.invitees = inviteesString.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
                   print(event.invitees)
               }
                   

            Text("Propose times:")
                .font(.headline)
                .foregroundStyle(.accent)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)
            TimeGridSelectionView(selectedTimes: $proposedTimes, daysToShow: 7, startHour: 8, endHour: 20, slotMinutes: 30, height: 260)
                .padding(.horizontal)
//            var name: String
//            var description: String
//            var invitees: [String]
//            var duration: TimeInterval
//            var bestTime: Time
        //    var bestLocation: String
//            var responses: [Response]
            Button("Send it!"){
                //TODO add functionality for actually sending the event to the backend and stuff
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
                record.setValuesForKeys([
                    "id": event.id.uuidString,
                    "name": event.name,
                    "description": event.description,
                    "proposedTimesData": proposedTimesData as Any,
//                    "invitees": event.invitees,
//                    "duration": event.duration,
//                    "bestTime": event.bestTime,
//                    "bestLocation": event.bestLocation,
//                    "responses": event.responses
//                    "dueDate": DateComponents(
//                        calendar: Calendar.current,
//                        year: 2019,
//                        month: 10,
//                        day: 28).date!,
                    
                ])
                
                CKContainer.default().accountStatus { accountStatus, error in
                    if accountStatus == .noAccount {
                        Task { @MainActor in
                            print("NOT AUTHENTICATED")
                            onSend?(event)
                        }
                        return
                    }
                    database.save(record) { _, error in
                        Task { @MainActor in
                            if let error {
                                print("Error saving record: \(error.localizedDescription)")
                            } else {
                                print("SAVED RECORD!")
                            }
                            onSend?(createdEvent)
                        }
                    }
                }
            }
            .font(.title2)
            .padding()
                
           
            Spacer()
            
           
        }
        .padding()
    }

    private func encodeProposedTimesForCloudKit(_ times: Set<Time>) -> Data? {
        // CloudKit can store `Data` directly; encoding keeps the schema simple.
        let sorted = times.sorted { $0.startTime < $1.startTime }
        return try? JSONEncoder().encode(sorted)
    }
}

#Preview {
    EventCreationView(onSend: { _ in })
}
