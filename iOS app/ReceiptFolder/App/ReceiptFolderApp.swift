import SwiftUI
import SwiftData
import TipKit
import BackgroundTasks
import CloudKit

@main
struct ReceiptFolderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("appearanceMode") private var appearanceMode: Int = 0

    let modelContainer: ModelContainer

    /// When `-UITests` is passed as a launch argument the app boots into a
    /// deterministic, hermetic state: in-memory SwiftData, onboarding skipped,
    /// biometric lock off, TipKit disabled, draft storage cleared. Used by
    /// the XCUITest bundle so tests don't depend on iCloud, prior state, or
    /// TipKit overlays.
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITests")
    }

    init() {
        if Self.isUITesting {
            Self.resetForUITests()
        }

        // Configure TipKit — skipped under UI tests so tips don't overlay buttons
        // mid-test. TipView with an unconfigured TipKit simply renders nothing.
        if !Self.isUITesting {
            try? Tips.configure([
                .displayFrequency(.weekly),
                .datastoreLocation(.applicationDefault)
            ])
        }

        // Register background tasks (skip in tests — registration asserts in test host).
        if !Self.isUITesting {
            BackgroundTaskManager.register()
        }

        // Create model container — try CloudKit first, fall back to local-only.
        // SwiftData handles lightweight migration automatically (new optional fields,
        // removed unique constraint, added defaults) — no explicit migration plan needed.
        let schema = Schema([ReceiptItem.self])

        if Self.isUITesting {
            // In-memory container so each test run starts from zero.
            do {
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                )
            } catch {
                fatalError("Failed to create in-memory test container: \(error)")
            }
        } else if let container = try? ModelContainer(
            for: schema,
            configurations: ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private(CloudSyncService.containerID)
            )
        ) {
            modelContainer = container
        } else if let container = try? ModelContainer(for: schema) {
            // CloudKit unavailable (no signing / no iCloud) — local-only
            RFLogger.storage.error("CloudKit unavailable, using local-only storage")
            modelContainer = container
        } else {
            fatalError("Failed to create ModelContainer")
        }

        // Let FamilySharingService observe SwiftData saves against this
        // container so edits to shared items auto-mirror.
        if !Self.isUITesting {
            FamilySharingService.shared.bind(modelContainer: modelContainer)
        }
    }

    /// Clears the volatile state the test target needs to be deterministic.
    private static func resetForUITests() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "hasCompletedOnboarding")
        defaults.set(false, forKey: "appLockEnabled")
        defaults.set(0, forKey: "appearanceMode")
        defaults.set(1, forKey: "defaultWarrantyYears")
        defaults.set(true, forKey: "returnNotificationsEnabled")
        defaults.set(true, forKey: "warrantyNotificationsEnabled")
        defaults.set(8, forKey: "notificationHour")
        defaults.set(0, forKey: "notificationMinute")
        // Clear any leftover draft from a previous run.
        defaults.removeObject(forKey: "receiptDraft")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    LockScreenGate {
                        MainTabView()
                    }
                } else {
                    OnboardingView()
                }
            }
            .preferredColorScheme(resolvedColorScheme)
            // Cap Dynamic Type at .accessibility1 so the fixed-size editorial
            // mastheads and hero countdowns don't break at extreme accessibility
            // sizes. Scalable body text still grows within this range.
            .dynamicTypeSize(.xSmall ... .accessibility1)
            .task {
                // Skip iCloud checks and image migration during UI tests so
                // tests start instantly and behave deterministically.
                guard !Self.isUITesting else { return }
                ReviewPromptService.recordFirstLaunchIfNeeded()
                await CloudSyncService.shared.checkAccountStatus()
                await migrateImagesToModelData()
                if CloudSyncService.shared.iCloudAvailable {
                    await HouseholdStore.shared.registerSubscriptionsIfNeeded()
                    await HouseholdStore.shared.refresh()
                }
            }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            guard !Self.isUITesting else { return }
            switch newPhase {
            case .active:
                Task { @MainActor in
                    _ = await NotificationScheduler.shared.requestPermission()
                    if hasCompletedOnboarding {
                        // Authenticate if app lock enabled
                        _ = await BiometricAuthService.shared.authenticate()
                        // Cleanup orphaned Live Activities
                        await cleanupOrphanedActivities()
                        // Sync side effects for items marked returned from a widget —
                        // the widget's MarkReturnedIntent can't touch notifications,
                        // Live Activities, or Spotlight (they need the app process).
                        syncReturnedItemSideEffects()
                        // Refresh iCloud status
                        await CloudSyncService.shared.checkAccountStatus()
                    }
                }
            case .background:
                // Lock the app when going to background
                BiometricAuthService.shared.lock()
                // Schedule background refresh
                BackgroundTaskManager.scheduleRefresh()
            default:
                break
            }
        }
    }
}

extension ReceiptFolderApp {
    /// Resolves the user's appearance preference to a `ColorScheme` (nil = follow system).
    private var resolvedColorScheme: ColorScheme? {
        switch appearanceMode {
        case 1: .light
        case 2: .dark
        default: nil // system
        }
    }

    /// Cleans up Live Activities that no longer correspond to active items (e.g., after force-quit).
    @MainActor
    private func cleanupOrphanedActivities() async {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<ReceiptItem>(
            predicate: #Predicate<ReceiptItem> { !$0.isArchived && !$0.isReturned }
        )
        guard let items = try? context.fetch(descriptor) else { return }
        let activeIDs = Set(items.map { $0.id.uuidString })
        await LiveActivityManager.shared.cleanupOrphanedActivities(activeItemIDs: activeIDs)
    }

    /// Idempotent cleanup for items that were marked returned outside the app —
    /// e.g., via the widget's `MarkReturnedIntent`. Cancels any stale scheduled
    /// notifications, ends lingering Live Activities, removes Spotlight entries.
    /// Safe to call on every app foreground: it's a no-op when there's nothing
    /// to reconcile.
    @MainActor
    private func syncReturnedItemSideEffects() {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<ReceiptItem>(
            predicate: #Predicate<ReceiptItem> { $0.isReturned }
        )
        guard let returnedItems = try? context.fetch(descriptor) else { return }
        for item in returnedItems {
            NotificationScheduler.shared.cancelNotifications(for: item.id)
            LiveActivityManager.shared.endLiveActivity(for: item.id)
            // Returned items stay in the Spotlight index intentionally — users
            // may still want to find them by name. Don't remove here.
        }
    }

    /// One-time migration: moves encrypted file-based images into SwiftData model data
    /// so they sync via CloudKit as CKAssets. Runs idempotently — skips items already migrated.
    /// Heavy compression work runs on a background task so app launch stays responsive.
    @MainActor
    private func migrateImagesToModelData() async {
        let hasRun = UserDefaults.standard.bool(forKey: "hasCompletedImageMigrationV2")
        guard !hasRun else { return }

        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<ReceiptItem>()
        guard let items = try? context.fetch(descriptor) else { return }

        var migrated = 0
        var legacyPathsToDelete: [String] = []

        for item in items {
            // Receipt image — load (off-main via async loadImage) then compress on a detached task.
            if item.receiptImageData == nil && !item.receiptImagePath.isEmpty {
                if let image = await ImageStorageService.shared.loadImage(relativePath: item.receiptImagePath) {
                    let data = await Task.detached(priority: .utility) {
                        ImageCompressionService.adaptiveCompress(image: image)
                    }.value
                    if let data {
                        item.receiptImageData = data
                        legacyPathsToDelete.append(item.receiptImagePath)
                        item.receiptImagePath = ""
                        migrated += 1
                    }
                }
            }

            // Item image — same pattern.
            if item.itemImageData == nil, let itemPath = item.itemImagePath, !itemPath.isEmpty {
                if let image = await ImageStorageService.shared.loadImage(relativePath: itemPath) {
                    let data = await Task.detached(priority: .utility) {
                        ImageCompressionService.adaptiveCompress(image: image)
                    }.value
                    if let data {
                        item.itemImageData = data
                        legacyPathsToDelete.append(itemPath)
                        item.itemImagePath = nil
                        migrated += 1
                    }
                }
            }
        }

        if migrated > 0 {
            do {
                try context.save()
                RFLogger.storage.info("Migrated \(migrated) images from disk to SwiftData model")

                for path in legacyPathsToDelete {
                    ImageStorageService.shared.deleteImage(relativePath: path)
                }

                UserDefaults.standard.set(true, forKey: "hasCompletedImageMigrationV2")
                ImageStorageService.shared.cleanupLegacyDirectories()
            } catch {
                RFLogger.storage.error("Image migration save failed, will retry next launch: \(error)")
            }
        } else {
            UserDefaults.standard.set(true, forKey: "hasCompletedImageMigrationV2")
        }
    }
}

/// Biometric lock gate — shows the Editorial-style lock screen when the app is locked.
struct LockScreenGate<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        if BiometricAuthService.shared.isUnlocked || !BiometricAuthService.shared.isAppLockEnabled {
            content()
        } else {
            lockScreen
        }
    }

    private var lockScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Text("RECEIPT · FOLDER")
                    .font(RFFont.mono(10))
                    .tracking(2.0)
                    .foregroundStyle(RFColors.mute)

                Rectangle().fill(RFColors.ink).frame(height: 2)
                    .frame(maxWidth: 220)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Locked")
                        .font(RFFont.hero(56))
                        .foregroundStyle(RFColors.ink)
                    Text(".")
                        .font(.system(size: 56, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(RFColors.signal)
                }
            }
            .padding(.horizontal, 40)

            Spacer().frame(height: 40)

            ZStack {
                Rectangle()
                    .stroke(RFColors.ink, lineWidth: 0.75)
                    .frame(width: 110, height: 110)

                Image(systemName: biometricIcon)
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(RFColors.ink)
            }

            Spacer().frame(height: 24)

            Text("Unlock to read your receipts.")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.mute)

            Spacer()

            Button {
                Task {
                    await BiometricAuthService.shared.authenticate()
                }
            } label: {
                Text("Unlock with \(BiometricAuthService.shared.biometricName)")
            }
            .buttonStyle(RFPrimaryButtonStyle())
            .padding(.horizontal, 40)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RFColors.paper)
    }

    private var biometricIcon: String {
        switch BiometricAuthService.shared.biometricType {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        default: "lock"
        }
    }
}
