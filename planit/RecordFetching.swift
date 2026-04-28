//
//  RecordFetching.swift
//  planit
//
//  Created by Elise Wong-McBride on 4/23/26.
//
import CloudKit
import Foundation

func fetchEventFromId(idString: String) async -> Event? {
    let database = CKContainer.default().publicCloudDatabase
    let predicate = NSPredicate(format: "id == %@", idString)
    let query = CKQuery(recordType: "Event", predicate: predicate)
    do {
        let (matchResults, _) = try await database.records(matching: query, inZoneWith: nil)
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                print("CloudKit Event id: \(record.recordID.recordName)")
                return event(from: record)
            case .failure(let error):
                print("CloudKit record error: \(error.localizedDescription)")
            }
        }
        return nil
    } catch {
        print("CloudKit query failed: \(error.localizedDescription)")
        return nil
    }
}

func fetchEventsFromCloudKit() async -> [Event] {
    let database = CKContainer.default().publicCloudDatabase
    let query = CKQuery(recordType: "Event", predicate: NSPredicate(value: true))
    do {
        let (matchResults, _) = try await database.records(matching: query, inZoneWith: nil)
        var events: [Event] = []
        events.reserveCapacity(matchResults.count)
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                print("CloudKit Event id: \(record.recordID.recordName)")
                events.append(event(from: record))
            case .failure(let error):
                print("CloudKit record error: \(error.localizedDescription)")
            }
        }
        return events
    } catch {
        print("CloudKit query failed: \(error.localizedDescription)")
        return []
    }
}

func event(from record: CKRecord) -> Event {
    let idString = record["id"] as? String
    let id = idString.flatMap { UUID(uuidString: $0) } ?? UUID()
    let name = (record["name"] as? String) ?? ""
    let description = (record["description"] as? String) ?? ""
    let proposedTimesData = record["proposedTimesData"] as? Data
    let proposedTimes = proposedTimesData.flatMap { try? JSONDecoder().decode([Time].self, from: $0) } ?? []
    return Event(
        id: id,
        name: name,
        description: description,
        invitees: [],
        duration: 0,
        proposedTimes: proposedTimes,
        bestTime: Time(startTime: Date(), endTime: Date()),
        responses: []
    )
}
