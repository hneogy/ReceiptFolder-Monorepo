import AppIntents
import SwiftData
import WidgetKit
import Foundation

/// Marks a receipt as returned directly from a widget tap — no app launch required.
///
/// Runs inside the widget extension process (or the app if it happens to be foreground).
/// The intent:
///   1. Opens the shared CloudKit-backed SwiftData container
///   2. Finds the receipt by UUID
///   3. Sets `isReturned = true` and saves
///   4. Rebuilds the widget's UserDefaults snapshot so the item disappears immediately
///   5. Asks WidgetKit to reload timelines
///
/// Side effects that need the app (cancelling scheduled notifications, ending
/// Live Activities, updating the Spotlight index) are performed by the app on
/// its next foreground launch via idempotent cleanup — see
/// `ReceiptFolderApp.task { ... syncReturnedItemSideEffects }`.
struct MarkReturnedIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Returned"
    static var description = IntentDescription(
        "Marks a receipt as returned so the countdown stops and reminders stop."
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Receipt ID")
    var receiptID: String

    init() {}

    init(itemID: UUID) {
        self.receiptID = itemID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: receiptID) else {
            return .result()
        }

        let container = try sharedContainer()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ReceiptItem>(
            predicate: #Predicate<ReceiptItem> { $0.id == uuid }
        )

        guard let item = try? context.fetch(descriptor).first else {
            // Item may have been deleted or archived elsewhere — refresh
            // the widget anyway and succeed silently.
            WidgetCenter.shared.reloadAllTimelines()
            return .result()
        }

        if !item.isReturned {
            item.isReturned = true
            try? context.save()
        }

        // Rebuild the widget snapshot so the just-returned item disappears
        // immediately from the widget stack.
        let all = FetchDescriptor<ReceiptItem>(
            predicate: #Predicate<ReceiptItem> { !$0.isArchived && !$0.isReturned },
            sortBy: [SortDescriptor(\.returnWindowEndDate, order: .forward)]
        )
        if let active = try? context.fetch(all) {
            let today = Calendar.current.startOfDay(for: .now)
            let widgetItems: [WidgetReceiptItem] = active
                .filter { $0.returnWindowEndDate == nil || $0.returnWindowEndDate! >= today }
                .sorted { (lhs, rhs) in
                    (lhs.returnDaysRemaining ?? .max) < (rhs.returnDaysRemaining ?? .max)
                }
                .prefix(5)
                .map { item in
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
            WidgetDataProvider.saveTopExpiring(widgetItems)
            WidgetDataProvider.saveNextExpiring(widgetItems.first)
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }

    // MARK: - Container access

    /// Opens the same CloudKit-backed container the app uses. The schema is
    /// visible because `ReceiptItem.swift` lives in the shared target.
    private func sharedContainer() throws -> ModelContainer {
        let schema = Schema([ReceiptItem.self])
        if let cloud = try? ModelContainer(
            for: schema,
            configurations: ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private(AppGroupConstants.cloudKitContainerID)
            )
        ) {
            return cloud
        }
        return try ModelContainer(for: schema)
    }
}
