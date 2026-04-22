import Foundation
import CloudKit
import SwiftUI

/// Manages a CloudKit `CKShare` that represents the user's "household."
/// Family members who accept the share can see items the user has marked
/// `sharedWithHousehold = true`.
///
/// # Architecture
///
/// CloudKit shares live on a **root record** in a **custom zone**. We keep it
/// simple: one dedicated zone (`HouseholdZone`), one root record
/// (`HouseholdRoot`), one `CKShare` attached to it. Items marked for household
/// sharing are mirrored into that zone as `CKRecord`s whose parent is the
/// root — that's how CloudKit knows they're part of the share.
///
/// # v1 scope
///
/// This ship lands the **plumbing + invite flow**: zone creation, root-record
/// creation, `CKShare` creation, `UICloudSharingController` presentation,
/// participant listing, and the per-item toggle. The actual record-mirroring
/// loop (watch SwiftData changes → copy matching items into the shared zone)
/// is scaffolded with `syncSharedItems()` but runs manually for now —
/// auto-mirroring on every save is a follow-up that needs its own design
/// pass around conflict resolution.
///
/// This service is iOS-only. The macOS companion reads the same CloudKit
/// container, so shared items will appear there via SwiftData's CloudKit
/// sync without additional code.
@MainActor
@Observable
final class FamilySharingService {
    static let shared = FamilySharingService()

    // MARK: - Constants

    static let zoneName = "HouseholdZone"
    static let rootRecordType = "HouseholdRoot"
    static let rootRecordID = CKRecord.ID(
        recordName: "household-root",
        zoneID: CKRecordZone.ID(zoneName: FamilySharingService.zoneName, ownerName: CKCurrentUserDefaultName)
    )
    static let itemRecordType = "SharedReceiptItem"

    // MARK: - Observable state

    private(set) var share: CKShare?
    private(set) var participants: [CKShare.Participant] = []
    private(set) var isLoading = false
    private(set) var lastError: String?

    /// True when the current user owns the household (created it).
    var isOwner: Bool {
        guard let share else { return false }
        return share.owner.userIdentity.lookupInfo != nil &&
               share.currentUserParticipant?.role == .owner
    }

    /// True when any household share exists (owned or joined).
    var hasHousehold: Bool { share != nil }

    var shareURL: URL? { share?.url }

    // MARK: - Container

    private var container: CKContainer {
        CKContainer(identifier: CloudSyncService.containerID)
    }

    private var privateDB: CKDatabase { container.privateCloudDatabase }

    private init() {}

    // MARK: - Loading

    /// Fetches the current state of the household share (if any). Call on
    /// view appear.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Make sure the zone exists before we try to read from it.
            try await ensureZoneExists()

            // Try to fetch the root record; if it has a share reference, pull
            // the share and its participants.
            let record = try await fetchRootRecord()
            if let share = try await fetchShare(for: record) {
                self.share = share
                self.participants = share.participants
            } else {
                self.share = nil
                self.participants = []
            }
            self.lastError = nil
        } catch let ckError as CKError where ckError.code == .zoneNotFound || ckError.code == .unknownItem {
            self.share = nil
            self.participants = []
            self.lastError = nil
        } catch {
            RFLogger.storage.error("Household refresh failed: \(error.localizedDescription)")
            self.lastError = error.localizedDescription
        }
    }

    // MARK: - Zone & root record

    private func ensureZoneExists() async throws {
        let zone = CKRecordZone(zoneID: Self.rootRecordID.zoneID)
        do {
            _ = try await privateDB.save(zone)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Zone already exists — fine.
        }
    }

    private func fetchRootRecord() async throws -> CKRecord {
        do {
            return try await privateDB.record(for: Self.rootRecordID)
        } catch let error as CKError where error.code == .unknownItem {
            // Create it.
            let record = CKRecord(recordType: Self.rootRecordType, recordID: Self.rootRecordID)
            record["createdAt"] = Date() as NSDate
            record["label"] = "Household" as NSString
            return try await privateDB.save(record)
        }
    }

    private func fetchShare(for record: CKRecord) async throws -> CKShare? {
        guard let shareRef = record.share else { return nil }
        let shareRecord = try await privateDB.record(for: shareRef.recordID)
        return shareRecord as? CKShare
    }

    // MARK: - Create / prepare share

    /// Prepares a `CKShare` attached to the household root record. Call this
    /// before presenting `UICloudSharingController`. Returns a tuple of the
    /// share and container for the controller's initializer.
    func prepareHouseholdShare() async throws -> (CKShare, CKContainer) {
        try await ensureZoneExists()
        let root = try await fetchRootRecord()

        if let existingRef = root.share {
            if let shareRecord = try await privateDB.record(for: existingRef.recordID) as? CKShare {
                self.share = shareRecord
                self.participants = shareRecord.participants
                return (shareRecord, container)
            }
        }

        let newShare = CKShare(rootRecord: root)
        newShare[CKShare.SystemFieldKey.title] = "Receipt Folder · Household" as NSString
        newShare.publicPermission = .none

        let (savedResults, _) = try await privateDB.modifyRecords(
            saving: [root, newShare],
            deleting: [],
            savePolicy: .ifServerRecordUnchanged
        )

        // Extract the saved CKShare.
        var savedShare: CKShare?
        for (_, result) in savedResults {
            if case .success(let record) = result, let s = record as? CKShare {
                savedShare = s
            }
        }
        guard let s = savedShare else {
            throw CKError(.internalError)
        }
        self.share = s
        self.participants = s.participants
        return (s, container)
    }

    /// Called after `UICloudSharingController` reports the share was saved or
    /// changed. Re-reads the participant list.
    func reloadShareState() async {
        await refresh()
    }

    // MARK: - Stop sharing

    /// Ends the household. Removes the `CKShare` (and by extension, access
    /// for all participants). Keeps the user's own data intact.
    func stopSharing() async throws {
        guard let share else { return }
        _ = try await privateDB.modifyRecords(saving: [], deleting: [share.recordID])
        self.share = nil
        self.participants = []
    }

    // MARK: - Accept invite (called from SceneDelegate-style metadata handler)

    /// Accept an incoming household invite. The system invokes the host app
    /// with a `CKShare.Metadata` when a user taps the share URL.
    func acceptInvite(metadata: CKShare.Metadata) async throws {
        _ = try await container.accept(metadata)
        await refresh()
    }

    // MARK: - Per-item sync (scaffolded; manual for v1)

    /// Mirrors all items flagged `sharedWithHousehold == true` into the
    /// household shared zone. v1 ships this as a manual action exposed in the
    /// Family Sharing settings screen; a future pass will wire it up to
    /// SwiftData change notifications so mirroring is automatic.
    func syncSharedItems(_ items: [ReceiptItem]) async {
        guard hasHousehold else { return }
        do {
            try await ensureZoneExists()
            let root = try await fetchRootRecord()
            let flagged = items.filter(\.sharedWithHousehold)

            var toSave: [CKRecord] = []
            for item in flagged {
                let id = CKRecord.ID(recordName: item.id.uuidString, zoneID: Self.rootRecordID.zoneID)
                let record = CKRecord(recordType: Self.itemRecordType, recordID: id)
                record.parent = CKRecord.Reference(record: root, action: .none)
                record.setParent(root)
                record["productName"] = item.productName as NSString
                record["storeName"] = item.storeName as NSString
                record["purchaseDate"] = item.purchaseDate as NSDate
                record["priceCents"] = item.priceCents as NSNumber
                if let end = item.returnWindowEndDate {
                    record["returnWindowEndDate"] = end as NSDate
                }
                if let warranty = item.warrantyEndDate {
                    record["warrantyEndDate"] = warranty as NSDate
                }
                record["isReturned"] = (item.isReturned ? 1 : 0) as NSNumber
                toSave.append(record)
            }
            if !toSave.isEmpty {
                _ = try await privateDB.modifyRecords(saving: toSave, deleting: [], savePolicy: .allKeys)
            }
        } catch {
            RFLogger.storage.error("Household item sync failed: \(error.localizedDescription)")
            self.lastError = error.localizedDescription
        }
    }
}
