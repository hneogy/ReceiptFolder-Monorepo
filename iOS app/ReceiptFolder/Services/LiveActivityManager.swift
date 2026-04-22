import Foundation
import ActivityKit
import SwiftUI

// MARK: - Live Activity Attributes

struct ReturnDeadlineAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var daysRemaining: Int
        var hoursRemaining: Int
        var isLastDay: Bool
    }

    var productName: String
    var storeName: String
    var returnEndDate: Date
    var itemID: String
    var isGift: Bool
}

// MARK: - Live Activity Manager

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activeActivities: [String: String] = [:] // itemID -> activityID

    private init() {
        rebuildFromSystem()
    }

    /// Rebuilds the in-memory activity map from the system's current Live Activities.
    /// Handles app force-quit scenarios where the in-memory dict is lost.
    private func rebuildFromSystem() {
        for activity in Activity<ReturnDeadlineAttributes>.activities {
            activeActivities[activity.attributes.itemID] = activity.id
        }
    }

    /// Ends any orphaned Live Activities whose items no longer exist or are archived/returned.
    /// Awaits each `end` call so the in-memory map and system state stay in sync.
    func cleanupOrphanedActivities(activeItemIDs: Set<String>) async {
        for activity in Activity<ReturnDeadlineAttributes>.activities {
            let itemID = activity.attributes.itemID
            if !activeItemIDs.contains(itemID) {
                await activity.end(nil, dismissalPolicy: .immediate)
                activeActivities.removeValue(forKey: itemID)
            }
        }
    }

    func startLiveActivity(for item: ReceiptItem) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard let returnEnd = item.returnWindowEndDate, !item.isReturned else { return }

        let daysRemaining = item.returnDaysRemaining ?? 0
        guard daysRemaining <= 3 && daysRemaining >= 0 else { return }

        // Don't start duplicate
        if activeActivities[item.id.uuidString] != nil { return }

        let attributes = ReturnDeadlineAttributes(
            productName: item.productName,
            storeName: item.storeName,
            returnEndDate: returnEnd,
            itemID: item.id.uuidString,
            isGift: item.isGift
        )

        let hoursRemaining = max(0, Int(returnEnd.timeIntervalSince(.now) / 3600))
        let state = ReturnDeadlineAttributes.ContentState(
            daysRemaining: daysRemaining,
            hoursRemaining: hoursRemaining,
            isLastDay: daysRemaining == 0
        )

        let content = ActivityContent(state: state, staleDate: returnEnd)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            activeActivities[item.id.uuidString] = activity.id
        } catch {
            RFLogger.liveActivity.error("Failed to start Live Activity: \(error)")
        }
    }

    func updateLiveActivity(for item: ReceiptItem) {
        guard let activityID = activeActivities[item.id.uuidString] else { return }
        guard let returnEnd = item.returnWindowEndDate else { return }

        let daysRemaining = item.returnDaysRemaining ?? 0
        let hoursRemaining = max(0, Int(returnEnd.timeIntervalSince(.now) / 3600))

        let state = ReturnDeadlineAttributes.ContentState(
            daysRemaining: daysRemaining,
            hoursRemaining: hoursRemaining,
            isLastDay: daysRemaining == 0
        )

        let content = ActivityContent(state: state, staleDate: returnEnd)

        Task {
            for activity in Activity<ReturnDeadlineAttributes>.activities where activity.id == activityID {
                await activity.update(content)
            }
        }
    }

    func endLiveActivity(for itemID: UUID) {
        guard let activityID = activeActivities[itemID.uuidString] else { return }

        Task {
            for activity in Activity<ReturnDeadlineAttributes>.activities where activity.id == activityID {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            activeActivities.removeValue(forKey: itemID.uuidString)
        }
    }

    func refreshAllActivities(items: [ReceiptItem]) {
        // Collect IDs that need ending first to avoid mutating dict during iteration
        var idsToEnd: [UUID] = []
        for (itemID, _) in activeActivities {
            if !items.contains(where: { $0.id.uuidString == itemID && ($0.returnDaysRemaining ?? .max) <= 3 }) {
                if let uuid = UUID(uuidString: itemID) {
                    idsToEnd.append(uuid)
                }
            }
        }
        // End them after iteration
        for id in idsToEnd {
            endLiveActivity(for: id)
        }

        // Start new activities for critical items
        for item in items where !item.isReturned && !item.isArchived {
            if let days = item.returnDaysRemaining, days <= 3 {
                startLiveActivity(for: item)
            }
        }
    }
}
