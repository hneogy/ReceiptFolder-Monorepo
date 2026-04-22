import UIKit
import UserNotifications
import CloudKit

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Register for silent CloudKit pushes. Content-available pushes do
        // not require explicit user permission — APNs delivers them to the
        // app regardless of notification authorization status.
        application.registerForRemoteNotifications()
        return true
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // Handle notification tap — deep-link to the specific receipt.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let identifier = response.notification.request.identifier
        // Identifier format: rf.<UUID>.<type>.<interval>  (UUIDs use hyphens, not dots)
        let components = identifier.split(separator: ".")
        let itemUUID: UUID?
        if components.count >= 3, components[0] == "rf" {
            let uuidString = String(components[1])
            itemUUID = UUID(uuidString: uuidString)
            if itemUUID == nil {
                RFLogger.general.error("Notification identifier had non-UUID component: \(uuidString, privacy: .public)")
            }
        } else {
            RFLogger.general.error("Notification identifier did not match expected format: \(identifier, privacy: .public)")
            itemUUID = nil
        }

        await MainActor.run {
            NavigationState.shared.selectedTab = .vault
            if let id = itemUUID {
                NavigationState.shared.pendingItemID = id
            }
        }
    }

    // MARK: - CloudKit share acceptance
    //
    // iOS calls this when the user taps a household-share URL and chooses
    // "Accept" in the system sheet. We forward the metadata to
    // FamilySharingService, which calls `CKContainer.accept(_:)` and refreshes
    // its participant list.
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task { @MainActor in
            do {
                try await FamilySharingService.shared.acceptInvite(metadata: cloudKitShareMetadata)
                await HouseholdStore.shared.refresh()
                RFLogger.storage.info("Accepted household CKShare invite")
            } catch {
                RFLogger.storage.error("Failed to accept CKShare: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - CloudKit push notifications
    //
    // Silent pushes from our CKDatabaseSubscriptions. When a co-owner
    // edits a record in the shared zone, CloudKit notifies us here, and
    // we tell HouseholdStore to re-fetch. The user sees the vault refresh
    // in the background without tapping anything.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            completionHandler(.noData)
            return
        }
        guard notification.notificationType == .database else {
            completionHandler(.noData)
            return
        }
        Task { @MainActor in
            await HouseholdStore.shared.handlePushedChange()
            completionHandler(.newData)
        }
    }
}
