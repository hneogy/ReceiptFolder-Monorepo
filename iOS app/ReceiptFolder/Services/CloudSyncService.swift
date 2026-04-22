import Foundation
import CloudKit

/// Monitors iCloud sync status and provides user-facing sync information.
@MainActor @Observable
final class CloudSyncService {
    static let shared = CloudSyncService()

    /// Shared CloudKit container identifier — read by everything that
    /// constructs a ModelContainer or CKContainer for this app. Sourced from
    /// `AppGroupConstants` so the widget and intent targets share the same
    /// value without having to link against this service.
    nonisolated static let containerID = AppGroupConstants.cloudKitContainerID

    private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    private(set) var lastChecked: Date?
    /// Populated when `checkAccountStatus()` throws. Allows the UI to
    /// distinguish "we haven't checked yet" from "the check failed".
    private(set) var lastError: String?

    var iCloudAvailable: Bool {
        accountStatus == .available
    }

    var statusDescription: String {
        if lastError != nil, accountStatus == .couldNotDetermine {
            return "Unable to check status"
        }
        switch accountStatus {
        case .available: return "Connected"
        case .noAccount: return "No iCloud Account"
        case .restricted: return "Restricted"
        case .couldNotDetermine: return "Checking…"
        case .temporarilyUnavailable: return "Temporarily Unavailable"
        @unknown default: return "Unknown"
        }
    }

    var statusIcon: String {
        if lastError != nil, accountStatus == .couldNotDetermine { return "exclamationmark.icloud" }
        switch accountStatus {
        case .available: return "checkmark.icloud.fill"
        case .noAccount: return "xmark.icloud"
        case .restricted: return "lock.icloud"
        case .couldNotDetermine: return "icloud"
        case .temporarilyUnavailable: return "exclamationmark.icloud"
        @unknown default: return "icloud.slash"
        }
    }

    private init() {}

    func checkAccountStatus() async {
        do {
            let container = CKContainer(identifier: Self.containerID)
            let status = try await container.accountStatus()
            accountStatus = status
            lastError = nil
            lastChecked = .now
        } catch {
            RFLogger.storage.error("Failed to check iCloud account status: \(error.localizedDescription)")
            lastError = error.localizedDescription
            accountStatus = .couldNotDetermine
            lastChecked = .now
        }
    }
}
