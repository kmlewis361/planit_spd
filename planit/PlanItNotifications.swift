//
//  PlanItNotifications.swift
//  planit
//

import CloudKit
import Foundation
import UserNotifications
import UIKit

extension Notification.Name {
    /// Posted with the event `UUID` string as `object` to open `EventResponseView`.
    static let planitOpenEventResponse = Notification.Name("planitOpenEventResponse")
    /// Posted with the event `UUID` string as `object` to open `EventDetailsView`.
    static let planitOpenEventDetails = Notification.Name("planitOpenEventDetails")
}

enum PlanItNotifications {
    private static let inviteCreateSubscriptionPrefix = "event-invite-create-"
    private static let inviteUpdateSubscriptionPrefix = "event-invite-update-"
    private static let finalTimeSubscriptionPrefix = "event-final-time-"
    private static let eventEditedSubscriptionPrefix = "event-edited-"

    private static var planItDatabase: CKDatabase {
        CKContainer.default().publicCloudDatabase
    }

    // MARK: - Setup

    /// Requests alert permission, registers for APNs, and saves CloudKit query subscriptions for invites and final times.
    @MainActor
    static func activateForSignedInUser() {
        let username = normalizedPlanItUsername(globalUsername).lowercased()
        guard !username.isEmpty else { return }
        Task {
            await requestAuthorizationAndRegisterForRemoteNotifications()
            do {
                try await ensureEventInviteSubscriptions(usernameLowercased: username)
                try await ensureFinalTimeSubscription(usernameLowercased: username)
                try await ensureEventEditedSubscription(usernameLowercased: username)
                #if DEBUG
                print("PlanIt: push subscriptions active for @\(username)")
                #endif
            } catch {
                #if DEBUG
                print("PlanIt: push subscription failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    @MainActor
    private static func requestAuthorizationAndRegisterForRemoteNotifications() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        #if DEBUG
        let status = await center.notificationSettings()
        print("PlanIt: notification permission granted=\(granted) authorization=\(status.authorizationStatus.rawValue)")
        #endif
        guard granted else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    private static func ensureEventInviteSubscriptions(usernameLowercased: String) async throws {
        let alertBody = "You've been invited to a new PlanIt event. Tap to share your availability."

        let createSubscription = CKQuerySubscription(
            recordType: "Event",
            predicate: NSPredicate(format: "ANY invitees == %@", usernameLowercased),
            subscriptionID: "\(inviteCreateSubscriptionPrefix)\(usernameLowercased)",
            options: [.firesOnRecordCreation]
        )
        createSubscription.notificationInfo = eventNotificationInfo(alertBody: alertBody)
        _ = try await planItDatabase.save(createSubscription)

        // Fires when an organizer adds this user via `newlyInvited` on event edit (see updateEventInCloudKit).
        let updateSubscription = CKQuerySubscription(
            recordType: "Event",
            predicate: NSPredicate(format: "ANY newlyInvited == %@", usernameLowercased),
            subscriptionID: "\(inviteUpdateSubscriptionPrefix)\(usernameLowercased)",
            options: [.firesOnRecordUpdate]
        )
        updateSubscription.notificationInfo = eventNotificationInfo(alertBody: alertBody)
        _ = try await planItDatabase.save(updateSubscription)
    }

    /// Fires when the organizer sets or updates `finalTimeData` (see `saveFinalTimeToCloudKit`).
    private static func ensureFinalTimeSubscription(usernameLowercased: String) async throws {
        let alertBody = "A final time was set for your PlanIt event. Tap to view details."
        let subscription = CKQuerySubscription(
            recordType: "Event",
            predicate: NSPredicate(format: "ANY finalTimeNotifiedInvitees == %@", usernameLowercased),
            subscriptionID: "\(finalTimeSubscriptionPrefix)\(usernameLowercased)",
            options: [.firesOnRecordUpdate]
        )
        subscription.notificationInfo = eventNotificationInfo(alertBody: alertBody)
        _ = try await planItDatabase.save(subscription)
    }

    /// Fires when the organizer saves event edits (see `updateEventInCloudKit`).
    private static func ensureEventEditedSubscription(usernameLowercased: String) async throws {
        let alertBody = "An event you're invited to was updated. Tap to view details."
        let subscription = CKQuerySubscription(
            recordType: "Event",
            predicate: NSPredicate(format: "ANY eventEditedNotifiedInvitees == %@", usernameLowercased),
            subscriptionID: "\(eventEditedSubscriptionPrefix)\(usernameLowercased)",
            options: [.firesOnRecordUpdate]
        )
        subscription.notificationInfo = eventNotificationInfo(alertBody: alertBody)
        _ = try await planItDatabase.save(subscription)
    }

    private static func eventNotificationInfo(alertBody: String) -> CKSubscription.NotificationInfo {
        let info = CKSubscription.NotificationInfo()
        info.alertBody = alertBody
        info.soundName = "default"
        info.shouldBadge = true
        info.desiredKeys = ["id", "name"]
        return info
    }

    // MARK: - Navigation

    @MainActor
    static func handleNotificationResponse(_ response: UNNotificationResponse) async {
        guard let destination = await notificationDestination(from: response) else { return }
        switch destination {
        case .eventResponse(let eventId):
            openEventResponse(eventId: eventId)
        case .eventDetails(let eventId):
            openEventDetails(eventId: eventId)
        }
    }

    @MainActor
    static func openEventResponse(eventId: UUID) {
        NotificationCenter.default.post(name: .planitOpenEventResponse, object: eventId.uuidString)
    }

    @MainActor
    static func openEventDetails(eventId: UUID) {
        NotificationCenter.default.post(name: .planitOpenEventDetails, object: eventId.uuidString)
    }

    private enum NotificationDestination {
        case eventResponse(UUID)
        case eventDetails(UUID)
    }

    private static func notificationDestination(from response: UNNotificationResponse) async -> NotificationDestination? {
        guard let queryNotification = CKQueryNotification(
            fromRemoteNotificationDictionary: response.notification.request.content.userInfo
        ) else { return nil }

        guard let eventId = await eventIdFromEventNotification(queryNotification) else { return nil }

        let subscriptionID = queryNotification.subscriptionID ?? ""
        if subscriptionID.hasPrefix(finalTimeSubscriptionPrefix)
            || subscriptionID.hasPrefix(eventEditedSubscriptionPrefix) {
            return .eventDetails(eventId)
        }
        return .eventResponse(eventId)
    }

    private static func eventIdFromEventNotification(_ queryNotification: CKQueryNotification) async -> UUID? {
        if let fields = queryNotification.recordFields,
           let idString = fields["id"] as? String,
           let eventId = UUID(uuidString: idString) {
            return eventId
        }
        guard let recordID = queryNotification.recordID else { return nil }
        do {
            let record = try await planItDatabase.record(for: recordID)
            guard record.recordType == "Event",
                  let idString = record["id"] as? String,
                  let eventId = UUID(uuidString: idString) else { return nil }
            return eventId
        } catch {
            return nil
        }
    }
}
