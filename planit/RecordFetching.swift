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

func topTimeSlots(from responses: [Response], limit: Int? = 3) -> [(time: Time, votes: Int)] {
    var counts: [Time: Int] = [:]
    for response in responses {
        // Count each slot once per user (in case of duplicates).
        for slot in Set(response.times) {
            counts[slot, default: 0] += 1
        }
    }
    let sorted = counts
        .sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key.startTime < rhs.key.startTime
        }
        .map { (time: $0.key, votes: $0.value) }
    guard let limit else { return sorted }
    return Array(sorted.prefix(max(0, limit)))
}

private func proposedSlotsAreAdjacent(_ a: Time, _ b: Time) -> Bool {
    abs(a.endTime.timeIntervalSince(b.startTime)) < 2
}

/// True when some contiguous run of `proposedTimes` spans at least `meetingDuration` (same rule as best-times windows).
func hasContiguousProposedSpan(atLeastDuration meetingDuration: TimeInterval, in proposedTimes: [Time]) -> Bool {
    guard meetingDuration > 0 else { return !proposedTimes.isEmpty }
    guard !proposedTimes.isEmpty else { return false }

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

    for chain in chains {
        let n = chain.count
        for i in 0..<n {
            for j in i..<n {
                let span = chain[j].endTime.timeIntervalSince(chain[i].startTime)
                if span + 0.5 >= meetingDuration {
                    return true
                }
            }
        }
    }
    return false
}

/// Ranks contiguous runs of **proposed** slots whose span is at least `meetingDuration`.
/// A respondent counts toward a window only if they selected **every** atomic slot in that window.
/// Pass `limit: nil` to rank every qualifying window (for tiered UI selection).
func topAvailabilityWindows(
    proposedTimes: [Time],
    responses: [Response],
    meetingDuration: TimeInterval,
    limit: Int? = 3
) -> [(time: Time, votes: Int)] {
    if proposedTimes.isEmpty {
        let poolCap = limit.map { max($0 * 4, 12) }
        let slots = topTimeSlots(from: responses, limit: poolCap)
        if meetingDuration <= 0 {
            guard let limit else { return slots }
            return Array(slots.prefix(limit))
        }
        let filtered = slots.filter { $0.time.endTime.timeIntervalSince($0.time.startTime) + 0.5 >= meetingDuration }
        guard let limit else { return filtered }
        return Array(filtered.prefix(limit))
    }

    if meetingDuration <= 0 {
        return topTimeSlots(from: responses, limit: limit)
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

    let ranked = bestByWindowId.values
        .sorted { lhs, rhs in
            if lhs.votes != rhs.votes { return lhs.votes > rhs.votes }
            return lhs.window.startTime < rhs.window.startTime
        }
        .map { (time: $0.window, votes: $0.votes) }
    guard let limit else { return ranked }
    return Array(ranked.prefix(max(0, limit)))
}

/// All slots tied for the highest vote count; if fewer than `minimumCount`, adds every slot tied for second-highest, then third-highest. Ignores zero-vote slots so empty consensus does not flood the list.
func tieredBestTimes(from ranked: [(time: Time, votes: Int)], minimumCount: Int = 3) -> [(time: Time, votes: Int)] {
    guard !ranked.isEmpty else { return [] }
    let sorted = ranked.sorted { lhs, rhs in
        if lhs.votes != rhs.votes { return lhs.votes > rhs.votes }
        return lhs.time.startTime < rhs.time.startTime
    }
    let distinctDescending = Array(Set(sorted.map(\.votes))).filter { $0 > 0 }.sorted(by: >)
    guard !distinctDescending.isEmpty else { return [] }

    var result: [(time: Time, votes: Int)] = []
    for i in 0 ..< min(3, distinctDescending.count) {
        let band = distinctDescending[i]
        result.append(contentsOf: sorted.filter { $0.votes == band })
        if result.count >= minimumCount { break }
    }
    let collapsed = dropStrictlyContainedIntervals(dedupeIdenticalIntervals(result))
    return collapsed.sorted { lhs, rhs in
        if lhs.votes != rhs.votes { return lhs.votes > rhs.votes }
        return lhs.time.startTime < rhs.time.startTime
    }
}

// MARK: - Per-invitee availability for a best-time window

enum InviteeAvailabilityStatus: Equatable {
    case notResponded
    case fullyFree
    case notFree
    case partiallyFree(summary: String)
}

struct InviteeAvailabilityRow: Identifiable {
    let invitee: String
    let status: InviteeAvailabilityStatus
    var id: String { invitee.lowercased() }
}

/// Proposed atomic slots that lie inside `window` (used to score each invitee).
func atomicSlotsInAvailabilityWindow(_ window: Time, proposedTimes: [Time]) -> [Time] {
    let epsilon: TimeInterval = 2
    let inside = proposedTimes
        .filter { slot in
            slot.startTime >= window.startTime - epsilon && slot.endTime <= window.endTime + epsilon
        }
        .sorted { $0.startTime < $1.startTime }
    if !inside.isEmpty { return inside }
    return [window]
}

func responsesByNormalizedUsername(_ responses: [Response]) -> [String: Response] {
    var map: [String: Response] = [:]
    for response in responses {
        let key = normalizedPlanItUsername(response.username).lowercased()
        guard !key.isEmpty else { continue }
        map[key] = response
    }
    return map
}

func inviteeAvailabilityRows(
    window: Time,
    invitees: [String],
    proposedTimes: [Time],
    responses: [Response]
) -> [InviteeAvailabilityRow] {
    let atoms = atomicSlotsInAvailabilityWindow(window, proposedTimes: proposedTimes)
    let byUser = responsesByNormalizedUsername(responses)
    return invitees.map { invitee in
        let key = normalizedPlanItUsername(invitee).lowercased()
        let status: InviteeAvailabilityStatus
        if let response = byUser[key] {
            status = availabilityStatus(for: response, atoms: atoms)
        } else {
            status = .notResponded
        }
        return InviteeAvailabilityRow(invitee: invitee, status: status)
    }
}

private func availabilityStatus(for response: Response, atoms: [Time]) -> InviteeAvailabilityStatus {
    let chosen = Set(response.times)
    let selected = atoms.filter { chosen.contains($0) }
    if selected.count == atoms.count {
        return .fullyFree
    }
    if selected.isEmpty {
        return .notFree
    }
    let runs = contiguousSlotRuns(selected.sorted { $0.startTime < $1.startTime })
    let summary = "Free \(runs.map(formatCompactSlotRun).joined(separator: ", "))"
    return .partiallyFree(summary: summary)
}

private func contiguousSlotRuns(_ sorted: [Time]) -> [[Time]] {
    guard !sorted.isEmpty else { return [] }
    var runs: [[Time]] = []
    var current: [Time] = [sorted[0]]
    for slot in sorted.dropFirst() {
        if let last = current.last, proposedSlotsAreAdjacent(last, slot) {
            current.append(slot)
        } else {
            runs.append(current)
            current = [slot]
        }
    }
    runs.append(current)
    return runs
}

private func formatCompactSlotRun(_ run: [Time]) -> String {
    guard let first = run.first, let last = run.last else { return "" }
    let start = first.startTime.formatted(.dateTime.hour().minute())
    let end = last.endTime.formatted(.dateTime.hour().minute())
    return "\(start)–\(end)"
}

/// Keeps the strongest vote count when the same interval appears more than once.
private func dedupeIdenticalIntervals(_ items: [(time: Time, votes: Int)]) -> [(time: Time, votes: Int)] {
    var best: [String: (time: Time, votes: Int)] = [:]
    for item in items {
        let key = item.time.id
        if let existing = best[key] {
            if item.votes > existing.votes {
                best[key] = item
            }
        } else {
            best[key] = item
        }
    }
    return Array(best.values)
}

/// Drops intervals that are strictly contained in another interval with the **same** vote count (redundant shorter window).
private func dropStrictlyContainedIntervals(_ items: [(time: Time, votes: Int)]) -> [(time: Time, votes: Int)] {
    guard items.count > 1 else { return items }
    return items.filter { cand in
        !items.contains { other in
            guard cand.time.id != other.time.id else { return false }
            guard other.votes == cand.votes else { return false }
            let os = other.time.startTime
            let oe = other.time.endTime
            let cs = cand.time.startTime
            let ce = cand.time.endTime
            guard os <= cs, ce <= oe else { return false }
            return !(cs == os && ce == oe)
        }
    }
}

func fetchEventRecordFromId(idString: String) async throws -> CKRecord? {
    let database = CKContainer.default().publicCloudDatabase
    let predicate = NSPredicate(format: "id == %@", idString)
    let query = CKQuery(recordType: "Event", predicate: predicate)
    let (matchResults, _) = try await database.records(matching: query, inZoneWith: nil)
    for (_, result) in matchResults {
        switch result {
        case .success(let record):
            return record
        case .failure(let error):
            throw error
        }
    }
    return nil
}

func fetchEventFromId(idString: String) async throws -> Event? {
    guard let record = try await fetchEventRecordFromId(idString: idString) else { return nil }
    return event(from: record)
}

/// Updates an existing CloudKit `Event` record (same `id`; preserves `finalTimeData` on the record).
func updateEventInCloudKit(_ event: Event) async throws {
    guard let record = try await fetchEventRecordFromId(idString: event.id.uuidString) else {
        throw NSError(domain: "PlanIt", code: 2, userInfo: [NSLocalizedDescriptionKey: "Event not found"])
    }
    let sortedProposed = event.proposedTimes.sorted { $0.startTime < $1.startTime }
    let proposedTimesData = try JSONEncoder().encode(sortedProposed)
    let inviteesForCloudKit = event.invitees
        .map { normalizedPlanItUsername($0).lowercased() }
        .filter { !$0.isEmpty }
    record["name"] = event.name as CKRecordValue
    record["description"] = event.description as CKRecordValue
    record["duration"] = event.duration as CKRecordValue
    record["proposedTimesData"] = proposedTimesData as CKRecordValue
    record["invitees"] = inviteesForCloudKit as NSArray
    let database = CKContainer.default().publicCloudDatabase
    _ = try await database.save(record)
}

/// Saves the organizer’s confirmed meeting time on the CloudKit `Event` record (`finalTimeData`).
func saveFinalTimeToCloudKit(_ finalTime: Time, eventIdString: String) async throws {
    guard let record = try await fetchEventRecordFromId(idString: eventIdString) else {
        throw NSError(domain: "PlanIt", code: 1, userInfo: [NSLocalizedDescriptionKey: "Event not found"])
    }
    let data = try JSONEncoder().encode(finalTime)
    record["finalTimeData"] = data as CKRecordValue
    let database = CKContainer.default().publicCloudDatabase
    _ = try await database.save(record)
}

/// Derives the meeting window from one contiguous block of selected slots spanning at least `meetingDuration`.
func finalTimeWindowFromContiguousSelection(_ selectedSlots: Set<Time>, meetingDuration: TimeInterval) -> Time? {
    guard !selectedSlots.isEmpty, meetingDuration > 0 else { return nil }
    let sorted = selectedSlots.sorted { $0.startTime < $1.startTime }
    for index in 1 ..< sorted.count {
        if !proposedSlotsAreAdjacent(sorted[index - 1], sorted[index]) { return nil }
    }
    let window = Time(startTime: sorted[0].startTime, endTime: sorted[sorted.count - 1].endTime, snapMinutes: 30)
    guard window.endTime.timeIntervalSince(window.startTime) + 0.5 >= meetingDuration else { return nil }
    return window
}

/// True when `window` spans strictly more than `meetingDuration` (organizer must pick a sub-slot).
func windowSpanExceedsDuration(_ window: Time, meetingDuration: TimeInterval) -> Bool {
    guard meetingDuration > 0 else { return false }
    return window.endTime.timeIntervalSince(window.startTime) > meetingDuration + 0.5
}

/// Grid-aligned start/end instants inside `block` (slot starts plus the block’s end).
func timeBoundariesWithinBlock(_ block: Time, proposedTimes: [Time]) -> [Date] {
    let epsilon: TimeInterval = 0.5
    let slots = proposedTimes
        .filter { $0.startTime >= block.startTime - epsilon && $0.endTime <= block.endTime + epsilon }
        .sorted { $0.startTime < $1.startTime }

    var boundaries: [Date] = []
    for slot in slots {
        if boundaries.last.map({ abs($0.timeIntervalSince(slot.startTime)) > epsilon }) ?? true {
            boundaries.append(slot.startTime)
        }
    }
    if let lastEnd = slots.last?.endTime {
        if boundaries.last.map({ abs($0.timeIntervalSince(lastEnd)) > epsilon }) ?? true {
            boundaries.append(lastEnd)
        }
    }
    if boundaries.isEmpty {
        return [block.startTime, block.endTime]
    }
    if abs(boundaries[0].timeIntervalSince(block.startTime)) > epsilon {
        boundaries.insert(block.startTime, at: 0)
    }
    if abs(boundaries[boundaries.count - 1].timeIntervalSince(block.endTime)) > epsilon {
        boundaries.append(block.endTime)
    }
    return boundaries
}

/// End-boundary indices valid for a chosen start (span at least `meetingDuration`, within `block`).
func validEndBoundaryIndices(
    startIndex: Int,
    boundaries: [Date],
    block: Time,
    meetingDuration: TimeInterval
) -> [Int] {
    guard startIndex >= 0, startIndex < boundaries.count else { return [] }
    let start = boundaries[startIndex]
    let minSpan = max(meetingDuration, 0)
    return (startIndex + 1 ..< boundaries.count).filter { idx in
        let end = boundaries[idx]
        let span = end.timeIntervalSince(start)
        return span + 0.5 >= minSpan && end <= block.endTime + 0.5
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
    let finalTime: Time? = {
        guard let data = record["finalTimeData"] as? Data else { return nil }
        return try? JSONDecoder().decode(Time.self, from: data)
    }()
    return Event(
        id: id,
        name: name,
        description: description,
        invitees: invitees,
        duration: eventDuration(from: record),
        proposedTimes: proposedTimes,
        bestTime: Time(startTime: Date(), endTime: Date()),
        finalTime: finalTime,
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

/// Earliest proposed slot start for list ordering.
func earliestProposedStart(in event: Event) -> Date? {
    event.proposedTimes.min(by: { $0.startTime < $1.startTime })?.startTime
}

/// Soonest proposed availability first; events with no proposed slots sort last.
func eventsSortedByEarliestProposedTime(_ events: [Event]) -> [Event] {
    events.sorted { lhs, rhs in
        let left = earliestProposedStart(in: lhs) ?? .distantFuture
        let right = earliestProposedStart(in: rhs) ?? .distantFuture
        if left != right { return left < right }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
