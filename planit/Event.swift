//
//  Event.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/10/26.
//

import Foundation

struct Event: Identifiable {
    let id: UUID

    var name: String
    var description: String
    var invitees: [String]
    var duration: TimeInterval
    var bestTime: Time
//    var bestLocation: String
    var responses: [Response]

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        invitees: [String],
        duration: TimeInterval,
        bestTime: Time,
        responses: [Response]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.invitees = invitees
        self.duration = duration
        self.bestTime = bestTime
        self.responses = responses
    }
}
