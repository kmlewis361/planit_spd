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
}

enum PlanItNotifications {
    private static let inviteCreateSubscriptionPrefix = "event-invite-create-"
    private static let inviteUpdateSubscriptionPrefix = "event-invite-update-"

    private static var planItDatabase: CKDatabase {
        CKContainer.default().publicCloudDatabase
    }

    // MARK: - Setup

    /// Requests alert permission, registers for APNs, and saves a CloudKit query subscription for new invites.
    @MainActor
    static func activateForSignedInUser() {
        let username = normalizedPlanItUsername(globalUsername).lowercased()
        guard !username.isEmpty else { return }
        Task {
            await requestAuthorizationAndRegisterForRemoteNotifications()
            do {
                try await ensureEventInviteSubscriptions(usernameLowercased: username)
                #if DEBUG
                print("PlanIt: invite push subscriptions active for @\(username)")
                #endif
            } catch {
                #if DEBUG
                print("PlanIt: invite subscription failed: \(error.localizedDescription)")
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
        createSubscription.notificationInfo = notificationInfo(alertBody: alertBody)
        _ = try await planItDatabase.save(createSubscription)

        // Fires when an organizer adds this user via `newlyInvited` on event edit (see updateEventInCloudKit).
        let updateSubscription = CKQuerySubscription(
            recordType: "Event",
            predicate: NSPredicate(format: "ANY newlyInvited == %@", usernameLowercased),
            subscriptionID: "\(inviteUpdateSubscriptionPrefix)\(usernameLowercased)",
            options: [.firesOnRecordUpdate]
        )
        updateSubscription.notificationInfo = notificationInfo(alertBody: alertBody)
        _ = try await planItDatabase.save(updateSubscription)
    }

    private static func notificationInfo(alertBody: String) -> CKSubscription.NotificationInfo {
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
        guard let eventId = await eventIdFromNotificationResponse(response) else { return }
        openEventResponse(eventId: eventId)
    }

    @MainActor
    static func openEventResponse(eventId: UUID) {
        NotificationCenter.default.post(name: .planitOpenEventResponse, object: eventId.uuidString)
    }

    private static func eventIdFromNotificationResponse(_ response: UNNotificationResponse) async -> UUID? {
        await eventIdFromCloudKitUserInfo(response.notification.request.content.userInfo)
    }

    private static func eventIdFromCloudKitUserInfo(_ userInfo: [AnyHashable: Any]) async -> UUID? {
        guard let queryNotification = CKQueryNotification(fromRemoteNotificationDictionary: userInfo),
              let recordID = queryNotification.recordID else { return nil }
        do {
            let record = try await planItDatabase.record(for: recordID)
            guard let idString = record["id"] as? String else { return nil }
            return UUID(uuidString: idString)
        } catch {
            return nil
        }
    }
}
