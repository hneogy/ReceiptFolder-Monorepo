import SwiftUI
import SwiftData

/// Native macOS entry point for Receipt Folder.
///
/// Not Mac Catalyst. This is a separate `App` that uses macOS-native
/// chrome: `NavigationSplitView` sidebar, toolbar, menu-bar commands, and
/// window restoration. Data syncs with the iOS app via the shared
/// CloudKit container (private zone).
///
/// Scope for v1: browse + edit existing receipts, add by hand, export.
/// Omitted (iOS exclusives): camera scan, Live Activities, widgets, Siri
/// shortcuts, background refresh, biometric lock. These features wouldn't
/// translate cleanly to macOS conventions.
@main
struct MacReceiptFolderApp: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([ReceiptItem.self])
        do {
            if let cloud = try? ModelContainer(
                for: schema,
                configurations: ModelConfiguration(
                    schema: schema,
                    cloudKitDatabase: .private(AppGroupConstants.cloudKitContainerID)
                )
            ) {
                modelContainer = cloud
            } else {
                modelContainer = try ModelContainer(for: schema)
            }
        } catch {
            fatalError("Failed to create macOS ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MacRootView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .modelContainer(modelContainer)
        .windowResizability(.contentSize)
        .commands {
            // File menu — drag-drop onto the window is the primary add path.
            CommandGroup(after: .newItem) {
                Button("Add Receipt…") {
                    NotificationCenter.default.post(name: .macAddReceipt, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            // Edit menu — search focus.
            CommandGroup(after: .pasteboard) {
                Button("Find in Vault…") {
                    NotificationCenter.default.post(name: .macFocusSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }
            // File → Export — reuses the iOS export logic.
            CommandGroup(after: .saveItem) {
                Button("Export Receipts…") {
                    NotificationCenter.default.post(name: .macExport, object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)
            }
        }
    }
}

// Command-channel names used by menu items → receiving views. Keeping this
// tiny: no state machine, just broadcast + listen in whatever view currently
// owns the action.
extension Notification.Name {
    static let macAddReceipt   = Notification.Name("macAddReceipt")
    static let macFocusSearch  = Notification.Name("macFocusSearch")
    static let macExport       = Notification.Name("macExport")
}
