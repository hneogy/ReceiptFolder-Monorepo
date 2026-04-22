import Foundation
import BackgroundTasks
import SwiftData
import WidgetKit

enum BackgroundTaskManager {
    static let refreshTaskID = "com.receiptfolder.refresh"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskID, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            handleRefresh(task: task)
        }
    }

    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        // Refresh every 6 hours
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            RFLogger.general.error("Failed to submit background refresh task: \(error)")
        }
    }

    private static func handleRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh
        scheduleRefresh()

        let refreshTask = Task {
            await performRefresh()
        }

        task.expirationHandler = {
            refreshTask.cancel()
            task.setTaskCompleted(success: false)
        }

        Task {
            await refreshTask.value
            task.setTaskCompleted(success: true)
        }
    }

    @MainActor
    private static func performRefresh() async {
        // Sync widget data from SwiftData, then reload timelines
        do {
            let schema = Schema([ReceiptItem.self])
            let container: ModelContainer
            if let cloudContainer = try? ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .private(CloudSyncService.containerID))
            ) {
                container = cloudContainer
            } else {
                container = try ModelContainer(for: schema)
            }
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<ReceiptItem>(
                predicate: #Predicate<ReceiptItem> { !$0.isArchived && !$0.isReturned }
            )
            let items = try context.fetch(descriptor)
            WidgetSyncService.syncFromItems(items)
        } catch {
            // Fallback: just reload timelines with existing data
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
