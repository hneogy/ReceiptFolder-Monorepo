import Foundation
import EventKit
import EventKitUI

@MainActor
final class CalendarService {
    static let shared = CalendarService()

    private let store = EKEventStore()

    private init() {}

    /// Marker embedded in event notes so we can dedupe by item identity,
    /// independent of title changes. Event bodies are treated as case-sensitive.
    private static func itemMarker(for id: UUID) -> String {
        "[ReceiptFolder item: \(id)]"
    }

    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    func addReturnDeadline(for item: ReceiptItem) async -> Bool {
        guard await requestAccess() else { return false }
        guard let endDate = item.returnWindowEndDate else { return false }

        let startOfDay = Calendar.current.startOfDay(for: endDate)
        let action = item.isGift ? "Exchange" : "Return"
        let eventTitle = "\(action) \(item.productName) to \(item.storeName)"
        let idMarker = Self.itemMarker(for: item.id)

        // Dedupe by embedded item ID in notes — survives renames and exact-title variations.
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = store.predicateForEvents(withStart: startOfDay, end: nextDay, calendars: nil)
        let existingEvents = store.events(matching: predicate)
        if existingEvents.contains(where: { $0.notes?.contains(idMarker) == true }) {
            return true // Already exists for this receipt, skip duplicate
        }

        let event = EKEvent(eventStore: store)
        event.title = eventTitle
        event.startDate = startOfDay
        event.endDate = startOfDay
        event.isAllDay = true
        event.calendar = store.defaultCalendarForNewEvents
        event.notes = """
        Product: \(item.productName)
        Store: \(item.storeName)
        Price: \(item.formattedPrice)

        Return Policy: \(item.returnPolicyDescription)

        What to bring:
        \(item.returnRequirements.map { "• \($0)" }.joined(separator: "\n"))

        [ReceiptFolder item: \(item.id)]
        """

        // Add alert 1 day before
        event.addAlarm(EKAlarm(relativeOffset: -86400))
        // Add alert morning of (8 AM)
        if let morningOf = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: startOfDay) {
            event.addAlarm(EKAlarm(absoluteDate: morningOf))
        }

        do {
            try store.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }

    func addWarrantyExpiry(for item: ReceiptItem) async -> Bool {
        guard await requestAccess() else { return false }
        guard let endDate = item.warrantyEndDate else { return false }

        let startOfDay = Calendar.current.startOfDay(for: endDate)
        let eventTitle = "\(item.productName) warranty expires"
        let idMarker = Self.itemMarker(for: item.id)

        // Dedupe by embedded item ID (warranty variant).
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = store.predicateForEvents(withStart: startOfDay, end: nextDay, calendars: nil)
        let existingEvents = store.events(matching: predicate)
        if existingEvents.contains(where: { $0.notes?.contains(idMarker) == true }) {
            return true // Already exists for this receipt, skip duplicate
        }

        let event = EKEvent(eventStore: store)
        event.title = eventTitle
        event.startDate = startOfDay
        event.endDate = startOfDay
        event.isAllDay = true
        event.calendar = store.defaultCalendarForNewEvents
        event.notes = """
        Warranty for \(item.productName) purchased at \(item.storeName) expires today. Test all features and file any claims before this date.

        [ReceiptFolder item: \(item.id)]
        """

        // Alert 7 days before
        event.addAlarm(EKAlarm(relativeOffset: -7 * 86400))
        // Alert 1 day before
        event.addAlarm(EKAlarm(relativeOffset: -86400))

        do {
            try store.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }
}
