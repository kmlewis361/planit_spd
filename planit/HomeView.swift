//
//  HomeView.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/10/26.
//

import SwiftUI

struct HomeView: View {
    var onSeeDetails: ((Event) -> Void)? = nil
    @State private var events: [Event] = [Event(name: "Birthday Party", duration: 1000, bestTime: Time(startTime: Date(), endTime: Date()), responses: []), Event(name: "Brunch", duration: 1000, bestTime: Time(startTime: Date(), endTime: Date()), responses: [])]
    var body: some View {
        VStack {
            ForEach(events) { event in
                HStack {
                    Text(event.name)
                    Spacer()
                    Button(action: {
                        onSeeDetails?(event)
                    }) {
                        Text("See details")
                    }
                }
                .padding(.vertical, 6)
            }
            Spacer()
        }
        .padding()
    }
}

#Preview {
    HomeView()
}
