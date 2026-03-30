//
//  Event.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/10/26.
//

import Foundation

struct Event: Identifiable{
    let id = UUID()
    
    var name: String
    var description: String
    var invitees: [String]
    var duration: TimeInterval
    var bestTime: Time
//    var bestLocation: String
    var responses: [Response]
    
}
