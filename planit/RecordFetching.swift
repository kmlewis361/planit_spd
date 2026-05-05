//
//  RecordFetching.swift
//  planit
//
//  Created by Elise Wong-McBride on 4/23/26.
//
import CloudKit
import Foundation

func fetchResponsesForEvent(eventIdString: String) async throws -> [Response] {
    let database = CKContainer.default().publicCloudDatabase
    let predicate = NSPredicate(format: "eventId == %@", eventIdString)
    let query = CKQuery(recordType: "Response", predicate: predicate)
    do {
        let (matchResults, _) = try await database.records(matching: query, inZoneWith: nil)
        var responses: [Response] = []
        responses.reserveCapacity(matchResults.count)
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                let username = (record["username"] as? String) ?? ""
                let timesData = record["timesData"] as? Data
                let times = timesData.flatMap { try? JSONDecoder().decode([Time].self, from: $0) } ?? []
                responses.append(Response(username: username, times: times))
            case .failure(let error):
                throw error
            }
        }
        return responses
    } catch {
        throw error
    }
}

func topTimeSlots(from responses: [Response], limit: Int = 3) -> [(time: Time, votes: Int)] {
    var counts: [Time: Int] = [:]
    for response in responses {
        // Count each slot once per user (in case of duplicates).
        for slot in Set(response.times) {
            counts[slot, default: 0] += 1
        }
    }
    return counts
        .sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key.startTime < rhs.key.startTime
        }
        .prefix(max(0, limit))
        .map { (time: $0.key, votes: $0.value) }
}

func fetchEventFromId(idString: String) async throws -> Event? {
    let database = CKContainer.default().publicCloudDatabase
    let predicate = NSPredicate(format: "id == %@", idString)
    let query = CKQuery(recordType: "Event", predicate: predicate)
    do {
        let (matchResults, _) = try await database.records(matching: query, inZoneWith: nil)
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                return event(from: record)
            case .failure(let error):
                throw error
            }
        }
        return nil
    } catch {
        throw error
    }
}

/// Loads events where the signed-in PlanIt user appears in `invitees` (CloudKit **List** of **Strings**, lowercased; **Queryable** with `ANY invitees ==`).
func fetchEventsFromCloudKit(whereInviteeUsernameLowercased usernameLowercased: String) async throws -> [Event] {
    guard !usernameLowercased.isEmpty else { return [] }
    let database = CKContainer.default().publicCloudDatabase
    let predicate = NSPredicate(format: "ANY invitees == %@", usernameLowercased)
    let query = CKQuery(recordType: "Event", predicate: predicate)
    do {
        let (matchResults, _) = try await database.records(matching: query, inZoneWith: nil)
        var events: [Event] = []
        events.reserveCapacity(matchResults.count)
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                events.append(event(from: record))
            case .failure(let error):
                throw error
            }
        }
        return events
    } catch {
        throw error
    }
}

private func stringList(from record: CKRecord, key: String) -> [String] {
    if let raw = record[key] as? [String] {
        return raw
    }
    if let ns = record[key] as? NSArray {
        return ns.compactMap { $0 as? String }
    }
    return []
}

func event(from record: CKRecord) -> Event {
    let idString = record["id"] as? String
    let id = idString.flatMap { UUID(uuidString: $0) } ?? UUID()
    let name = (record["name"] as? String) ?? ""
    let description = (record["description"] as? String) ?? ""
    let proposedTimesData = record["proposedTimesData"] as? Data
    let proposedTimes = proposedTimesData.flatMap { try? JSONDecoder().decode([Time].self, from: $0) } ?? []
    let invitees = stringList(from: record, key: "invitees")
    return Event(
        id: id,
        name: name,
        description: description,
        invitees: invitees,
        duration: 0,
        proposedTimes: proposedTimes,
        bestTime: Time(startTime: Date(), endTime: Date()),
        responses: []
    )
}

/// True if `usernameLowercased` matches any invitee (after trim + lowercasing).
func eventIncludesInviteeLowercased(_ event: Event, usernameLowercased: String) -> Bool {
    guard !usernameLowercased.isEmpty else { return false }
    return event.invitees.contains {
        normalizedPlanItUsername($0).lowercased() == usernameLowercased
    }
}
