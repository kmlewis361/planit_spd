//
//  PlanItAccountCloudKit.swift
//  planit
//

import CloudKit
import Foundation

enum PlanItAccountError: LocalizedError {
    /// Legacy bucket — prefer the more specific iCloud cases below.
    case iCloudUnavailable
    case iCloudNotSignedIn
    case iCloudRestricted
    case iCloudTemporarilyUnavailable
    case iCloudCouldNotDetermine
    /// CloudKit container/schema doesn’t include required record types (e.g. `PlanItUser` not deployed).
    case cloudKitSchemaMissing
    case noUserRecord
    case invalidUsername
    case usernameTaken

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "Sign in to iCloud in Settings to use PlanIt."
        case .iCloudNotSignedIn:
            return "Sign in to iCloud on this device (Settings → Apple ID → iCloud)."
        case .iCloudRestricted:
            return "This device’s iCloud access is restricted. Check Screen Time or device management settings."
        case .iCloudTemporarilyUnavailable:
            return "iCloud is temporarily unavailable. Try again in a moment."
        case .iCloudCouldNotDetermine:
            return "Could not verify iCloud status. Check network Settings and try again."
        case .cloudKitSchemaMissing:
            return "PlanIt account services aren’t ready yet. Update PlanIt when available, or try again later."
        case .noUserRecord:
            return "Could not read your iCloud account record."
        case .invalidUsername:
            return "Usernames must be 3–20 characters: letters, numbers, or underscores."
        case .usernameTaken:
            return "That username is already taken."
        }
    }
}

/// CloudKit often reports missing schema as a localized message mentioning “record type”.
func planItCloudKitLooksLikeMissingSchema(_ error: Error) -> Bool {
    func inspect(_ e: Error) -> Bool {
        let text = e.localizedDescription.lowercased()
        if text.contains("record type") { return true }
        if text.contains("cannot find record type") { return true }
        if text.contains("unknown record type") { return true }
        if text.contains("schema") && text.contains("cloudkit") { return true }
        return false
    }

    if inspect(error) { return true }

    let ns = error as NSError
    if let partial = ns.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
        for (_, nested) in partial where inspect(nested) {
            return true
        }
    }
    return false
}

/// Rewrites common CloudKit schema failures into `PlanItAccountError.cloudKitSchemaMissing`.
func mapPlanItAccountCloudKitError(_ error: Error) -> Error {
    if error is PlanItAccountError { return error }
    if planItCloudKitLooksLikeMissingSchema(error) {
        return PlanItAccountError.cloudKitSchemaMissing
    }
    return error
}

/// Validates PlanIt handle rules before touching CloudKit.
func normalizedPlanItUsername(_ raw: String) -> String {
    raw.trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Throws `invalidUsername` if the normalized username doesn't match rules.
func assertPlanItUsernameFormat(_ normalized: String) throws {
    guard normalized.range(of: "^[a-zA-Z0-9_]{3,20}$", options: .regularExpression) != nil else {
        throw PlanItAccountError.invalidUsername
    }
}

/// Segments of the **lowercased** handle split on `_` (e.g. `dummy_alice_test` → `dummy`, `alice`, `test`).
/// Stored on `PlanItUser.usernameSearchTokens` (**List of Strings**, **Queryable**) so autocomplete can use
/// `ANY usernameSearchTokens BEGINSWITH` for segments, not only the start of the full handle.
func planItUsernameSearchTokens(fromLowercased lowered: String) -> [String] {
    let parts = lowered.split(separator: "_", omittingEmptySubsequences: true).map(String.init)
    var seen = Set<String>()
    var out: [String] = []
    for p in parts where !seen.contains(p) {
        seen.insert(p)
        out.append(p)
    }
    if out.isEmpty, !lowered.isEmpty {
        return [lowered]
    }
    return out
}

func cloudKitOwnerRecordName() async throws -> String {
    let container = CKContainer.default()
    let status = try await container.accountStatus()
    switch status {
    case .available:
        break
    case .noAccount:
        throw PlanItAccountError.iCloudNotSignedIn
    case .restricted:
        throw PlanItAccountError.iCloudRestricted
    case .temporarilyUnavailable:
        throw PlanItAccountError.iCloudTemporarilyUnavailable
    case .couldNotDetermine:
        throw PlanItAccountError.iCloudCouldNotDetermine
    @unknown default:
        throw PlanItAccountError.iCloudUnavailable
    }
    return try await withCheckedThrowingContinuation { continuation in
        container.fetchUserRecordID { recordID, error in
            if let error {
                continuation.resume(throwing: error)
                return
            }
            guard let recordID else {
                continuation.resume(throwing: PlanItAccountError.noUserRecord)
                return
            }
            continuation.resume(returning: recordID.recordName)
        }
    }
}

/// Loads the `PlanItUser` profile for this iCloud user (public DB).
func fetchPlanItUserProfile(ownerRecordName: String) async throws -> CKRecord? {
    let database = CKContainer.default().publicCloudDatabase
    let predicate = NSPredicate(format: "ownerRecordName == %@", ownerRecordName)
    let query = CKQuery(recordType: "PlanItUser", predicate: predicate)
    do {
        let (matchResults, _) = try await database.records(matching: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1)
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                return record
            case .failure:
                break
            }
        }
        return nil
    } catch {
        throw mapPlanItAccountCloudKitError(error)
    }
}

/// Returns true if no other user owns this lowercased username (excluding optional owner when renaming).
func isPlanItUsernameAvailable(usernameLowercased: String, excludingOwnerRecordName: String?) async throws -> Bool {
    let database = CKContainer.default().publicCloudDatabase
    let predicate = NSPredicate(format: "usernameLowercased == %@", usernameLowercased)
    let query = CKQuery(recordType: "PlanItUser", predicate: predicate)
    do {
        let (matchResults, _) = try await database.records(matching: query, inZoneWith: nil, desiredKeys: ["ownerRecordName"], resultsLimit: 5)
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                let owner = record["ownerRecordName"] as? String
                if owner != excludingOwnerRecordName {
                    return false
                }
            case .failure:
                break
            }
        }
        return true
    } catch {
        throw mapPlanItAccountCloudKitError(error)
    }
}

/// Creates or updates the profile row linking `ownerRecordName` (CloudKit user id) to a unique PlanIt username.
func upsertPlanItUser(displayUsername: String, ownerRecordName: String) async throws -> String {
    let trimmed = normalizedPlanItUsername(displayUsername)
    try assertPlanItUsernameFormat(trimmed)
    let lowered = trimmed.lowercased()

    let database = CKContainer.default().publicCloudDatabase

    if let existing = try await fetchPlanItUserProfile(ownerRecordName: ownerRecordName) {
        let currentLower = (existing["usernameLowercased"] as? String) ?? ""
        if currentLower != lowered {
            guard try await isPlanItUsernameAvailable(usernameLowercased: lowered, excludingOwnerRecordName: ownerRecordName) else {
                throw PlanItAccountError.usernameTaken
            }
        }
        existing["username"] = trimmed as CKRecordValue
        existing["usernameLowercased"] = lowered as CKRecordValue
        existing["usernameSearchTokens"] = planItUsernameSearchTokens(fromLowercased: lowered) as CKRecordValue
        existing["ownerRecordName"] = ownerRecordName as CKRecordValue
        do {
            _ = try await database.save(existing)
        } catch {
            throw mapPlanItAccountCloudKitError(error)
        }
        return trimmed
    }

    guard try await isPlanItUsernameAvailable(usernameLowercased: lowered, excludingOwnerRecordName: nil) else {
        throw PlanItAccountError.usernameTaken
    }

    let record = CKRecord(recordType: "PlanItUser")
    record["username"] = trimmed as CKRecordValue
    record["usernameLowercased"] = lowered as CKRecordValue
    record["usernameSearchTokens"] = planItUsernameSearchTokens(fromLowercased: lowered) as CKRecordValue
    record["ownerRecordName"] = ownerRecordName as CKRecordValue
    do {
        _ = try await database.save(record)
    } catch {
        throw mapPlanItAccountCloudKitError(error)
    }
    return trimmed
}

/// Public-directory lookup for invite autocomplete.
///
/// Uses **`usernameLowercased BEGINSWITH`** (full handle prefix) plus **`ANY usernameSearchTokens BEGINSWITH`**
/// on a **List of Strings** field populated from segments split on `_` (see `planItUsernameSearchTokens`).
/// Add `usernameSearchTokens` in the CloudKit Dashboard as **List** → **Strings**, **Queryable** (Searchable is not required).
///
/// Existing `PlanItUser` rows without `usernameSearchTokens` are only matched by full-handle prefix until the profile is saved again (or DEBUG seed recreates them).
func searchPlanItUsernames(prefix rawPrefix: String, limit: Int = 10) async throws -> [String] {
    let fragment = normalizedPlanItUsername(rawPrefix).lowercased()
    guard !fragment.isEmpty else { return [] }
    guard fragment.range(of: "^[a-z0-9_]+$", options: .regularExpression) != nil else { return [] }

    let database = CKContainer.default().publicCloudDatabase
    let desiredKeys = ["username", "usernameLowercased"] as [CKRecord.FieldKey]

    func displayName(from record: CKRecord) -> String? {
        if let u = record["username"] as? String {
            let t = normalizedPlanItUsername(u)
            if !t.isEmpty { return t }
        }
        if let u = record["usernameLowercased"] as? String {
            let t = normalizedPlanItUsername(u)
            if !t.isEmpty { return t }
        }
        return nil
    }

    func collect(from matchResults: [(CKRecord.ID, Result<CKRecord, any Error>)], into names: inout [String], seen: inout Set<String>) {
        for (_, result) in matchResults {
            guard case .success(let record) = result else { continue }
            guard let trimmed = displayName(from: record) else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            names.append(trimmed)
            if names.count >= limit { break }
        }
    }

    func queryPlanItUsers(predicate: NSPredicate, resultsLimit: Int) async throws -> [(CKRecord.ID, Result<CKRecord, any Error>)] {
        let query = CKQuery(recordType: "PlanItUser", predicate: predicate)
        let (matchResults, _) = try await database.records(matching: query, inZoneWith: nil, desiredKeys: desiredKeys, resultsLimit: resultsLimit)
        return Array(matchResults)
    }

    var names: [String] = []
    var seenLower = Set<String>()

    // 1) Prefix on the full lowercased handle (Queryable).
    let beginRows = try await queryPlanItUsers(
        predicate: NSPredicate(format: "usernameLowercased BEGINSWITH %@", fragment),
        resultsLimit: limit
    )
    collect(from: beginRows, into: &names, seen: &seenLower)

    // 2) Prefix on any `_`-segment (e.g. `alice` → `dummy_alice_test` when tokens include `alice`).
    if names.count < limit {
        let remaining = limit - names.count
        let tokenPred = NSPredicate(format: "ANY usernameSearchTokens BEGINSWITH %@", fragment)
        if let tokenRows = try? await queryPlanItUsers(predicate: tokenPred, resultsLimit: remaining) {
            collect(from: tokenRows, into: &names, seen: &seenLower)
        }
    }

    // 3) Legacy rows that only index `username` for prefix search.
    if names.count < limit {
        let remaining = limit - names.count
        do {
            let rows = try await queryPlanItUsers(
                predicate: NSPredicate(format: "username BEGINSWITH %@", fragment),
                resultsLimit: remaining
            )
            collect(from: rows, into: &names, seen: &seenLower)
        } catch {
            // `username` may not be Queryable; other paths are enough.
        }
    }

    return names.sorted {
        $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
    }
}

#if DEBUG
/// Inserts a few `PlanItUser` rows in the **public** CloudKit database so invite autocomplete has matches.
/// Skips usernames that are already taken. `ownerRecordName` values are synthetic and never match a real iCloud user.
func seedPlanItAutocompleteDummyUsersForDebug() async -> String {
    let database = CKContainer.default().publicCloudDatabase
    let dummies: [(ownerRecordName: String, username: String)] = [
        ("__planit_seed_owner_01", "dummy_alice_test"),
        ("__planit_seed_owner_02", "dummy_bob_smith"),
        ("__planit_seed_owner_03", "seed_charlie_dev"),
    ]
    var created: [String] = []
    var skippedTaken: [String] = []
    var failures: [String] = []

    for pair in dummies {
        let trimmed = normalizedPlanItUsername(pair.username)
        do {
            try assertPlanItUsernameFormat(trimmed)
        } catch {
            failures.append("\(pair.username): invalid format")
            continue
        }
        let lowered = trimmed.lowercased()
        do {
            guard try await isPlanItUsernameAvailable(usernameLowercased: lowered, excludingOwnerRecordName: nil) else {
                skippedTaken.append(trimmed)
                continue
            }
            let record = CKRecord(recordType: "PlanItUser")
            record["username"] = trimmed as CKRecordValue
            record["usernameLowercased"] = lowered as CKRecordValue
            record["usernameSearchTokens"] = planItUsernameSearchTokens(fromLowercased: lowered) as CKRecordValue
            record["ownerRecordName"] = pair.ownerRecordName as CKRecordValue
            _ = try await database.save(record)
            created.append(trimmed)
        } catch {
            let mapped = mapPlanItAccountCloudKitError(error)
            failures.append("\(trimmed): \(mapped.localizedDescription)")
        }
    }

    var lines: [String] = []
    if !created.isEmpty {
        lines.append("Created: \(created.joined(separator: ", ")). Add CloudKit field `usernameSearchTokens` (List of Strings, Queryable) if saves failed; try typing alice, bob, dummy, seed.")
    }
    if !skippedTaken.isEmpty {
        lines.append("Already existed (skipped): \(skippedTaken.joined(separator: ", "))")
    }
    if !failures.isEmpty {
        lines.append(failures.joined(separator: " · "))
    }
    if lines.isEmpty {
        return "Nothing to do."
    }
    return lines.joined(separator: "\n")
}
#endif
