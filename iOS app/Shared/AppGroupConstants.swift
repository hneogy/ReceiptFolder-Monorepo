import Foundation
import OSLog

enum AppGroupConstants {
    static let suiteName = "group.com.receiptfolder.app"

    /// Private CloudKit container shared across all targets (app, widget, intents).
    static let cloudKitContainerID = "iCloud.com.receiptfolder.app"

    /// The shared UserDefaults backing both the app and the widget.
    /// If this is nil, the App Group entitlement is misconfigured — every
    /// widget read/write will no-op silently, so we log loudly on first access
    /// to surface the misconfiguration during development and TestFlight.
    static let sharedDefaults: UserDefaults? = {
        if let defaults = UserDefaults(suiteName: suiteName) {
            return defaults
        }
        Logger(subsystem: "com.receiptfolder", category: "app-group")
            .error("UserDefaults(suiteName: \(suiteName, privacy: .public)) returned nil — App Group entitlement is missing or misconfigured. Widget data will not persist.")
        return nil
    }()

    enum Keys {
        static let topExpiringItems = "topExpiringItems"
        static let nextExpiringItem = "nextExpiringItem"
    }
}
