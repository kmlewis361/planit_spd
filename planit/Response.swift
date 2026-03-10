//
//  Response.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/10/26.
//

import Foundation

struct Response: Identifiable{
    let id = UUID()
    
    var username: String
    var times: [Time]
//    var locations: [String]
}
