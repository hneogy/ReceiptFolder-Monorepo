import Foundation
import SwiftData
import WidgetKit

/// Syncs receipt data to App Group UserDefaults so widgets display current information.
@MainActor
enum WidgetSyncService {

    /// Call after any data mutation (add, delete, archive, mark returned) to keep widgets current.
    static func sync(modelContext: ModelContext) {
        do {
            let descriptor = FetchDescriptor<ReceiptItem>(
                predicate: #Predicate<ReceiptItem> { !$0.isArchived && !$0.isReturned },
                sortBy: [SortDescriptor(\.returnWindowEndDate, order: .forward)]
            )
            let activeItems = try modelContext.fetch(descriptor)
            syncWidgetData(from: activeItems)
        } catch {
            RFLogger.widget.error("Widget sync fetch failed: \(error.localizedDescription)")
            // Trigger a timeline reload anyway so the widget falls back to its cached snapshot
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Sync from a pre-fetched item array (e.g., from background refresh).
    static func syncFromItems(_ items: [ReceiptItem]) {
        let active = items.filter { !$0.isArchived && !$0.isReturned }
        syncWidgetData(from: active)
    }

    // MARK: - Private

    private static func syncWidgetData(from items: [ReceiptItem]) {
        // Build widget-compatible items sorted by urgency (most urgent first)
        let today = Calendar.current.startOfDay(for: .now)
        let widgetItems: [WidgetReceiptItem] = items
            .filter { $0.returnWindowEndDate == nil || $0.returnWindowEndDate! >= today }
            .sorted { lhs, rhs in
                let lhsDays = lhs.returnDaysRemaining ?? Int.max
                let rhsDays = rhs.returnDaysRemaining ?? Int.max
                return lhsDays < rhsDays
            }
            .prefix(5)
            .map { mapToWidget($0) }

        // Save top expiring items for home screen widget
        WidgetDataProvider.saveTopExpiring(widgetItems)

        // Save the single next expiring item for lock screen widget
        WidgetDataProvider.saveNextExpiring(widgetItems.first)

        // Tell WidgetKit to refresh
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func mapToWidget(_ item: ReceiptItem) -> WidgetReceiptItem {
        WidgetReceiptItem(
            id: item.id.uuidString,
            productName: item.productName,
            storeName: item.storeName,
            daysUntilReturnExpiry: item.returnDaysRemaining,
            daysUntilWarrantyExpiry: item.warrantyDaysRemaining,
            urgencyLevel: item.urgencyLevel.rawValue,
            isGift: item.isGift
        )
    }
}
