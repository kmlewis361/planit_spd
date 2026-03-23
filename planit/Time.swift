//
//  Time.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/10/26.
//
import Foundation

struct Time: Codable, Identifiable {
    let id = UUID()
    var startTime: Date
    var endTime: Date
}
