//
//  HomeView.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/10/26.
//

import SwiftUI

struct HomeView: View {
    
    @State var event = Event(name: "Birthday Party", duration: 1000, bestTime: Time(startTime: Date(), endTime: Date()), responses: [])
    @State var events: [Event] = [Event(name: "Birthday Party", duration: 1000, bestTime: Time(startTime: Date(), endTime: Date()), responses: [])]
    var body: some View {
        VStack{
            ForEach(events) { event in
                Text(event.name)
                HStack{
                    NavigationLink(destination: EventDetailsView()){
                        Text("Go to Welcome")
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
