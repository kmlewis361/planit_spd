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
    private static let inviteSubscriptionPrefix = "event-invite-"

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
                try await ensureEventInviteSubscription(usernameLowercased: username)
                #if DEBUG
                print("PlanIt: invite push subscription active for @\(username)")
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

    private static func ensureEventInviteSubscription(usernameLowercased: String) async throws {
        let subscriptionID = "\(inviteSubscriptionPrefix)\(usernameLowercased)"
        let predicate = NSPredicate(format: "ANY invitees == %@", usernameLowercased)
        let subscription = CKQuerySubscription(
            recordType: "Event",
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation]
        )
        let info = CKSubscription.NotificationInfo()
        info.alertBody = "You've been invited to a new PlanIt event. Tap to share your availability."
        info.soundName = "default"
        info.shouldBadge = true
        info.desiredKeys = ["id", "name"]
        subscription.notificationInfo = info
        _ = try await planItDatabase.save(subscription)
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
