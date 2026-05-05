//
//  RecordFetching.swift
//  planit
//
//  Created by Elise Wong-McBride on 4/23/26.
//
import CloudKit
import Foundation

private func responseFromRecord(_ record: CKRecord) -> Response {
    let username = (record["username"] as? String) ?? ""
    let timesData = record["timesData"] as? Data
    let times = timesData.flatMap { try? JSONDecoder().decode([Time].self, from: $0) } ?? []
    return Response(username: username, times: times)
}

func fetchResponsesForEvent(eventIdString: String) async throws -> [Response] {
    let pairs = try await fetchResponseRecordsForEvent(eventIdString: eventIdString)
    return dedupedResponsesPreferringLatestRecord(pairs)
}

/// One logical response per PlanIt username (latest CloudKit modification wins).
private func dedupedResponsesPreferringLatestRecord(_ pairs: [(record: CKRecord, response: Response)]) -> [Response] {
    var best: [String: (mod: Date, response: Response)] = [:]
    for pair in pairs {
        let key = normalizedPlanItUsername(pair.response.username).lowercased()
        guard !key.isEmpty else { continue }
        let mod = pair.record.modificationDate ?? Date.distantPast
        if let cur = best[key], cur.mod >= mod { continue }
        best[key] = (mod, pair.response)
    }
    return best.values.map(\.response)
}

/// CloudKit `Response` rows for an event, paired with `CKRecord` for upserts.
func fetchResponseRecordsForEvent(eventIdString: String) async throws -> [(record: CKRecord, response: Response)] {
    let database = CKContainer.default().publicCloudDatabase
    let predicate = NSPredicate(format: "eventId == %@", eventIdString)
    let query = CKQuery(recordType: "Response", predicate: predicate)
    do {
        let (matchResults, _) = try await database.records(matching: query, inZoneWith: nil)
        var pairs: [(CKRecord, Response)] = []
        pairs.reserveCapacity(matchResults.count)
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                pairs.append((record, responseFromRecord(record)))
            case .failure(let error):
                throw error
            }
        }
        return pairs
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

private func proposedSlotsAreAdjacent(_ a: Time, _ b: Time) -> Bool {
    abs(a.endTime.timeIntervalSince(b.startTime)) < 2
}

/// Ranks contiguous runs of **proposed** slots whose span is at least `meetingDuration`.
/// A respondent counts toward a window only if they selected **every** atomic slot in that window.
func topAvailabilityWindows(
    proposedTimes: [Time],
    responses: [Response],
    meetingDuration: TimeInterval,
    limit: Int = 3
) -> [(time: Time, votes: Int)] {
    if proposedTimes.isEmpty {
        let slots = topTimeSlots(from: responses, limit: max(limit * 4, 12))
        if meetingDuration <= 0 {
            return Array(slots.prefix(limit))
        }
        return slots
            .filter { $0.time.endTime.timeIntervalSince($0.time.startTime) + 0.5 >= meetingDuration }
            .prefix(limit)
            .map { $0 }
    }

    if meetingDuration <= 0 {
        return Array(topTimeSlots(from: responses, limit: limit))
    }

    let sorted = proposedTimes.sorted { $0.startTime < $1.startTime }
    var chains: [[Time]] = []
    var current: [Time] = []
    for slot in sorted {
        if let last = current.last, proposedSlotsAreAdjacent(last, slot) {
            current.append(slot)
        } else {
            if !current.isEmpty { chains.append(current) }
            current = [slot]
        }
    }
    if !current.isEmpty { chains.append(current) }

    var bestByWindowId: [String: (window: Time, votes: Int)] = [:]
    for chain in chains {
        let n = chain.count
        for i in 0..<n {
            for j in i..<n {
                let span = chain[j].endTime.timeIntervalSince(chain[i].startTime)
                guard span + 0.5 >= meetingDuration else { continue }
                let window = Time(startTime: chain[i].startTime, endTime: chain[j].endTime, snapMinutes: 30)
                let atoms = Array(chain[i...j])
                let votes = responses.filter { resp in
                    let chosen = Set(resp.times)
                    return atoms.allSatisfy { chosen.contains($0) }
                }.count
                let wid = window.id
                if let existing = bestByWindowId[wid] {
                    if votes > existing.votes {
                        bestByWindowId[wid] = (window, votes)
                    }
                } else {
                    bestByWindowId[wid] = (window, votes)
                }
            }
        }
    }

    return bestByWindowId.values
        .sorted { lhs, rhs in
            if lhs.votes != rhs.votes { return lhs.votes > rhs.votes }
            return lhs.window.startTime < rhs.window.startTime
        }
        .prefix(max(0, limit))
        .map { (time: $0.window, votes: $0.votes) }
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

private func eventDuration(from record: CKRecord) -> TimeInterval {
    if let d = record["duration"] as? Double { return d }
    if let n = record["duration"] as? NSNumber { return n.doubleValue }
    return 3600
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
        duration: eventDuration(from: record),
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
