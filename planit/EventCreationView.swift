//
//  EventCreationView.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/10/26.
//

import SwiftUI
import CloudKit

struct EventCreationView: View {
   
    var onSend: (()-> Void)? = nil
    @State private var event = Event(name: "", description: "blank descprition", invitees: ["Hannah", "Caroline"], duration: 1, bestTime: Time(startTime: Date(), endTime: Date()), responses: [])
    @State private var inviteesString: String = ""
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
            Text("dummy best time") //TODO add time input
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
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
                record.setValuesForKeys([
                    "id": event.id.uuidString,
                    "name": event.name,
                    "description": event.description,
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
                        DispatchQueue.main.async {
                            let message =
                                """
                                Sign in to your iCloud account to write records.
                                On the Home screen, launch Settings, tap Sign in to your
                                iPhone/iPad, and enter your Apple ID. Turn iCloud Drive on.
                                """
                            let alert = UIAlertController(
                                title: "Sign in to iCloud",
                                message: message,
                                preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
//                            self.present(alert, animated: true)
                            print("NOT AUTHENTICATED")
                        }
                    }
                    else {
                        database.save(record) { record, error in
                            if let error = error {
                                print("Error saving record: \(error.localizedDescription)")
                                return
                            }
                            print("SAVED RECORD!")
                        }
                    }
                    onSend?()
                }
            }
            .font(.title2)
            .padding()
                
           
            Spacer()
            
           
        }
        .padding()
    }
}

#Preview {
    EventCreationView()
}
