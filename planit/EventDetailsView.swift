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
    var body: some View {
        Text(eventId.uuidString)
    }
}

#Preview {
    EventDetailsView()
}
