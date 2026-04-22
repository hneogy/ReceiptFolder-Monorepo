import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
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
}
