//
//  HomeView.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/10/26.
//

import SwiftUI

struct HomeView: View {
    var onSeeDetails: ((UUID) -> Void)? = nil
    @State private var events: [Event] = [Event(name: "Birthday Party", duration: 1000, bestTime: Time(startTime: Date(), endTime: Date()), responses: []), Event(name: "Brunch", duration: 1000, bestTime: Time(startTime: Date(), endTime: Date()), responses: [])]
    var body: some View {
        VStack {
            ForEach(events) { event in
                // If a navigation handler is provided, call it. Otherwise make the row a NavigationLink
                if let handler = onSeeDetails {
                    HStack {
                        Text(event.name)
                        Spacer()
                        Button(action: {
                            print("HomeView: See details tapped for event=\(event.name)")
                            handler(event.id)
                        }) {
                            Text("See details")
                        }
                    }
                    .padding(.vertical, 6)
                } else {
                    NavigationLink(destination: EventDetailsView(eventId: event.id)) {
                        HStack {
                            Text(event.name)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .onAppear {
            print("HomeView: onAppear; events count=\(events.count)")
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
