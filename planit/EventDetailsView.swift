//
//  EventDetailsView.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/10/26.
//

import SwiftUI

struct EventDetailsView: View {
    var event: Event = Event(name: "Blank Event", duration: 1, bestTime: Time(startTime: Date(), endTime: Date()), responses: [])
    var body: some View {
        Text(event.name)
    }
}

#Preview {
    EventDetailsView()
}
