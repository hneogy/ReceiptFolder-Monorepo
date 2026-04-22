import AppIntents
import SwiftData
import SwiftUI

// MARK: - Show Expiring Items Intent

struct ShowExpiringItemsIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Expiring Items"
    static var description = IntentDescription("Opens Receipt Folder to show items with expiring return windows or warranties.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NavigationState.shared.selectedTab = .expiring
        return .result()
    }
}

// MARK: - Add Receipt Intent

struct AddReceiptIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Receipt"
    static var description = IntentDescription("Opens Receipt Folder to scan a new receipt.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NavigationState.shared.showAddItem = true
        return .result()
    }
}

// MARK: - Check Return Window Intent

/// Caches a ModelContainer across Siri invocations. AppIntents may invoke
/// `perform()` many times in quick succession; rebuilding a CloudKit-backed
/// container each time is seconds of wasted work.
actor IntentModelContainerCache {
    static let shared = IntentModelContainerCache()

    private var container: ModelContainer?

    func get() throws -> ModelContainer {
        if let container { return container }
        let schema = Schema([ReceiptItem.self])
        if let cloud = try? ModelContainer(
            for: schema,
            configurations: ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private(CloudSyncService.containerID)
            )
        ) {
            container = cloud
            return cloud
        }
        let local = try ModelContainer(for: schema)
        container = local
        return local
    }
}

struct CheckReturnWindowIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Return Window"
    static var description = IntentDescription("Check how many days are left to return a recent purchase.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Product Name")
    var productName: String?

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let name = productName else {
            return .result(value: "Open Receipt Folder to see all your return windows.")
        }

        let container = try await IntentModelContainerCache.shared.get()
        let context = ModelContext(container)
        let searchName = name
        let descriptor = FetchDescriptor<ReceiptItem>(
            predicate: #Predicate<ReceiptItem> { item in
                item.productName.localizedStandardContains(searchName) && !item.isArchived
            }
        )

        guard let items = try? context.fetch(descriptor), let item = items.first else {
            return .result(value: "No items found matching \"\(name)\". Open Receipt Folder to check your receipts.")
        }

        let message: String
        if item.isReturned {
            message = "\(item.productName) from \(item.storeName) has already been returned."
        } else if let days = item.returnDaysRemaining {
            if days == 0 {
                message = "\(item.productName) from \(item.storeName): TODAY is the last day to return!"
            } else {
                message = "\(item.productName) from \(item.storeName): \(days) day\(days == 1 ? "" : "s") left to return."
            }
        } else if item.returnWindowEndDate != nil {
            message = "\(item.productName) from \(item.storeName): return window has closed."
        } else {
            message = "\(item.productName) from \(item.storeName): no return window tracked."
        }
        return .result(value: message)
    }
}

// MARK: - App Shortcuts Provider

struct ReceiptFolderShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ShowExpiringItemsIntent(),
            phrases: [
                "Show expiring items in \(.applicationName)",
                "What's expiring soon in \(.applicationName)",
                "Check my returns in \(.applicationName)"
            ],
            shortTitle: "Expiring Items",
            systemImageName: "clock.badge.exclamationmark.fill"
        )

        AppShortcut(
            intent: AddReceiptIntent(),
            phrases: [
                "Add a receipt to \(.applicationName)",
                "Scan a receipt with \(.applicationName)",
                "New receipt in \(.applicationName)"
            ],
            shortTitle: "Add Receipt",
            systemImageName: "doc.viewfinder"
        )

        AppShortcut(
            intent: CheckReturnWindowIntent(),
            phrases: [
                "Check return window in \(.applicationName)",
                "How long to return in \(.applicationName)",
                "Return deadline in \(.applicationName)"
            ],
            shortTitle: "Check Return",
            systemImageName: "arrow.uturn.left.circle"
        )
    }
}
