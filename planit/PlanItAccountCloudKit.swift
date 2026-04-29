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
    record["ownerRecordName"] = ownerRecordName as CKRecordValue
    do {
        _ = try await database.save(record)
    } catch {
        throw mapPlanItAccountCloudKitError(error)
    }
    return trimmed
}

/// Public-directory lookup for invite autocomplete (`usernameLowercased` should be QUERYABLE in CloudKit).
func searchPlanItUsernames(prefix rawPrefix: String, limit: Int = 10) async throws -> [String] {
    let prefix = normalizedPlanItUsername(rawPrefix).lowercased()
    guard !prefix.isEmpty else { return [] }
    guard prefix.range(of: "^[a-z0-9_]+$", options: .regularExpression) != nil else { return [] }

    let database = CKContainer.default().publicCloudDatabase
    let predicate = NSPredicate(format: "usernameLowercased BEGINSWITH %@", prefix)
    let query = CKQuery(recordType: "PlanItUser", predicate: predicate)
    do {
        let (matchResults, _) = try await database.records(matching: query, inZoneWith: nil, desiredKeys: ["username"], resultsLimit: limit)
        var names: [String] = []
        names.reserveCapacity(matchResults.count)
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                if let u = record["username"] as? String {
                    let trimmed = normalizedPlanItUsername(u)
                    if !trimmed.isEmpty {
                        names.append(trimmed)
                    }
                }
            case .failure:
                break
            }
        }
        return Array(Set(names)).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    } catch {
        throw mapPlanItAccountCloudKitError(error)
    }
}
