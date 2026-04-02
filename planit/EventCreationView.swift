//
//  EventCreationView.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/10/26.
//

import SwiftUI

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
           
            Button("Send it!"){
                //TODO add functionality for actually sending the event to the backend and stuff
                events.append(event)
               onSend?()
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
