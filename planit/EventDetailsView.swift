//
//  EventDetailsView.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/10/26.
//

import SwiftUI

struct EventDetailsView: View {
//    var event: Event = Event(name: "Blank Event", duration: 1, bestTime: Time(startTime: Date(), endTime: Date()), responses: [])
    var eventId: UUID = UUID()
    var username: String = ""
    //TODO fetch this from a table based off the UUID
    
    @State private var event: Event = Event(name: "Blank Event", description: "blank descprition", invitees: ["Hannah", "Caroline"], duration: 1, bestTime: Time(startTime: Date(), endTime: Date()), responses: [])
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

            Text("Best times:")
                .font(.headline)
                .foregroundStyle(.accent)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)
            Text("dummy best time") //TODO
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            //add some stuff for showing more times and who's free
            
            
                
           
            Spacer()
            
           
        }
        .task {
            await refreshLocalEventFromCloudKit()
        }
        .padding()
    }
    @MainActor
    private func refreshLocalEventFromCloudKit() async {
        if let fetched = await fetchEventFromId(idString: eventId.uuidString) {
            event = fetched
        }
    }
}

#Preview {
    EventDetailsView()
}
