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
    /// Invitees; index `0` is always the organizer’s PlanIt username (set when creating an event).
    var invitees: [String]
    var duration: TimeInterval
    /// Time blocks proposed by the event creator (the grid the invitees can choose from).
    var proposedTimes: [Time]
    var bestTime: Time
    /// Organizer-confirmed meeting time; persisted to CloudKit when set.
    var finalTime: Time?
//    var bestLocation: String
    var responses: [Response]

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        invitees: [String],
        duration: TimeInterval,
        proposedTimes: [Time] = [],
        bestTime: Time,
        finalTime: Time? = nil,
        responses: [Response]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.invitees = invitees
        self.duration = duration
        self.proposedTimes = proposedTimes
        self.bestTime = bestTime
        self.finalTime = finalTime
        self.responses = responses
    }
}
