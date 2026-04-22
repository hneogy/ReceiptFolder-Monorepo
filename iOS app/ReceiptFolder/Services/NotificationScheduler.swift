import Foundation
import UserNotifications

@MainActor
final class NotificationScheduler {
    static let shared = NotificationScheduler()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleNotifications(for item: ReceiptItem) {
        cancelNotifications(for: item.id)

        let returnEnabled = UserDefaults.standard.object(forKey: "returnNotificationsEnabled") as? Bool ?? true
        let warrantyEnabled = UserDefaults.standard.object(forKey: "warrantyNotificationsEnabled") as? Bool ?? true

        if returnEnabled, let returnEnd = item.returnWindowEndDate, !item.isReturned, returnEnd > .now {
            scheduleReturnNotifications(item: item, endDate: returnEnd)
        }

        if warrantyEnabled, let warrantyEnd = item.warrantyEndDate, !item.isWarrantyClaimed, !item.isReturned, warrantyEnd > .now {
            scheduleWarrantyNotifications(item: item, endDate: warrantyEnd)
        }
    }

    func cancelNotifications(for itemID: UUID) {
        let prefix = "rf.\(itemID.uuidString)"
        let identifiers = [
            "\(prefix).return.72h",
            "\(prefix).return.24h",
            "\(prefix).return.morning",
            "\(prefix).return.14d",
            "\(prefix).return.7d",
            "\(prefix).warranty.90d",
            "\(prefix).warranty.30d",
            "\(prefix).warranty.7d"
        ]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func rescheduleAll(items: [ReceiptItem]) {
        center.removeAllPendingNotificationRequests()
        for item in items where !item.isArchived && !item.isReturned {
            scheduleNotifications(for: item)
        }
    }

    // MARK: - Return Notifications

    private func scheduleReturnNotifications(item: ReceiptItem, endDate: Date) {
        let itemName = item.productName
        let storeName = item.storeName
        let isGift = item.isGift
        let action = isGift ? "exchange" : "return"

        // 72 hours before
        if let fireDate = Calendar.current.date(byAdding: .hour, value: -72, to: endDate), fireDate > .now {
            schedule(
                id: "rf.\(item.id).return.72h",
                title: "3 days left to \(action) your \(itemName)",
                body: "\(storeName)'s return window closes in 3 days. Tap to see what to bring.",
                date: fireDate
            )
        }

        // 24 hours before
        if let fireDate = Calendar.current.date(byAdding: .hour, value: -24, to: endDate), fireDate > .now {
            schedule(
                id: "rf.\(item.id).return.24h",
                title: isGift ? "Last day to exchange your \(itemName)" : "Last day to return your \(itemName)",
                body: "Return window at \(storeName) closes tomorrow. Don't miss it.",
                date: fireDate
            )
        }

        // Morning of last day
        let lastDayComponents = Calendar.current.dateComponents([.year, .month, .day], from: endDate)
        var morningComponents = lastDayComponents
        let preferredHour = UserDefaults.standard.object(forKey: "notificationHour") as? Int ?? 8
        let preferredMinute = UserDefaults.standard.object(forKey: "notificationMinute") as? Int ?? 0
        morningComponents.hour = preferredHour
        morningComponents.minute = preferredMinute
        if let morningDate = Calendar.current.date(from: morningComponents), morningDate > .now {
            schedule(
                id: "rf.\(item.id).return.morning",
                title: "\(action.capitalized) your \(itemName) today",
                body: "Last day to \(action) to \(storeName). Tap to see receipt, store info, and what you need to bring.",
                date: morningDate
            )
        }

        // 7 days before (amber zone)
        if let fireDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate), fireDate > .now {
            schedule(
                id: "rf.\(item.id).return.7d",
                title: "7 days left to \(action) your \(itemName)",
                body: "\(storeName)'s return window closes soon. Still on the fence? Now's the time to decide.",
                date: fireDate
            )
        }

        // 14 days before (amber zone)
        if let fireDate = Calendar.current.date(byAdding: .day, value: -14, to: endDate), fireDate > .now {
            schedule(
                id: "rf.\(item.id).return.14d",
                title: "2 weeks left to \(action) your \(itemName)",
                body: "\(storeName)'s return window is closing. Tap to view details.",
                date: fireDate
            )
        }
    }

    // MARK: - Warranty Notifications

    private func scheduleWarrantyNotifications(item: ReceiptItem, endDate: Date) {
        let itemName = item.productName

        // 90 days before
        if let fireDate = Calendar.current.date(byAdding: .day, value: -90, to: endDate), fireDate > .now {
            schedule(
                id: "rf.\(item.id).warranty.90d",
                title: "\(itemName) warranty expires in 90 days",
                body: "Good time to test every feature while you're still covered. Tap to view warranty details.",
                date: fireDate
            )
        }

        // 30 days before
        if let fireDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate), fireDate > .now {
            schedule(
                id: "rf.\(item.id).warranty.30d",
                title: "\(itemName) warranty expires in 30 days",
                body: "Run a full check of your \(itemName). Claim now if anything's wrong.",
                date: fireDate
            )
        }

        // 7 days before
        if let fireDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate), fireDate > .now {
            schedule(
                id: "rf.\(item.id).warranty.7d",
                title: "\(itemName) warranty expires in 7 days",
                body: "Last chance to file a warranty claim. Consider extended warranty if available.",
                date: fireDate
            )
        }
    }

    // MARK: - Helper

    private func schedule(id: String, title: String, body: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        center.add(request)
    }
}
