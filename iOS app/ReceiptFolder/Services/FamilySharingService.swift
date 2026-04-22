import Foundation
import CloudKit
import SwiftUI
import SwiftData
import Combine

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

    // Constants re-exported from HouseholdConstants for call-site clarity.
    // Keep FamilySharingService.rootRecordID etc. as sugar; single source of
    // truth for the wire format is HouseholdConstants (Shared/ target).
    static var zoneName: String { HouseholdConstants.zoneName }
    static var rootRecordType: String { HouseholdConstants.rootRecordType }
    static var rootRecordID: CKRecord.ID { HouseholdConstants.rootRecordID }
    static var itemRecordType: String { HouseholdConstants.itemRecordType }

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

    // MARK: - Auto-mirror plumbing

    /// Observer token for `ModelContext.didSave`. Held so we can remove on
    /// deinit (not actually called — singleton — but defensive).
    private var didSaveObserver: NSObjectProtocol?
    /// Debounce window for the save-driven full sync. SwiftData fires a
    /// `.didSave` notification on every save; users typing a note field
    /// will fire many of these in a row.
    private var debouncedSyncTask: Task<Void, Never>?
    /// The app owns one ModelContainer; we remember it so `didSave` can
    /// feed current state into `syncSharedItems`.
    private weak var modelContainer: ModelContainer?

    private init() {
        didSaveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.onModelContextDidSave() }
        }
    }

    /// Registers the app's ModelContainer so the save observer can read the
    /// latest item state without a per-context reference. Called from
    /// `ReceiptFolderApp.init` once the container is built.
    func bind(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    @MainActor
    private func onModelContextDidSave() {
        guard hasHousehold, let modelContainer else { return }
        // Debounce: wait 1.5s for additional saves (like wheel-spinning a
        // price field) before pulling all items and syncing.
        debouncedSyncTask?.cancel()
        debouncedSyncTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            let ctx = ModelContext(modelContainer)
            let descriptor = FetchDescriptor<ReceiptItem>(
                predicate: #Predicate { !$0.isArchived }
            )
            guard let items = try? ctx.fetch(descriptor) else { return }
            await self?.syncSharedItems(items)
        }
    }

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

    // MARK: - Per-item sync

    /// Full resync: mirrors everything flagged `sharedWithHousehold == true`
    /// into the household zone, and deletes stale records for items that
    /// were un-flagged since the last sync. Idempotent; safe to call on
    /// every foreground.
    func syncSharedItems(_ items: [ReceiptItem]) async {
        guard hasHousehold else { return }
        do {
            try await ensureZoneExists()
            let root = try await fetchRootRecord()
            let flagged = items.filter(\.sharedWithHousehold)
            let flaggedIDs = Set(flagged.map(\.id.uuidString))

            // Saves.
            var toSave: [CKRecord] = []
            for item in flagged {
                toSave.append(buildCKRecord(for: item, parent: root))
            }
            if !toSave.isEmpty {
                _ = try await privateDB.modifyRecords(
                    saving: toSave, deleting: [], savePolicy: .changedKeys
                )
            }

            // Deletes — anything in the zone that isn't flagged anymore.
            let existing = try await fetchAllSharedRecordIDs()
            let stale = existing.filter { !flaggedIDs.contains($0.recordName) && $0.recordName != Self.rootRecordID.recordName }
            if !stale.isEmpty {
                _ = try await privateDB.modifyRecords(saving: [], deleting: stale)
            }

            await HouseholdStore.shared.refresh()
        } catch {
            RFLogger.storage.error("Household item sync failed: \(error.localizedDescription)")
            self.lastError = error.localizedDescription
        }
    }

    /// Upsert a single item. Called from auto-mirror hooks (item toggle,
    /// item edit) so we don't pay the cost of a full resync on every save.
    func mirrorItem(_ item: ReceiptItem) async {
        guard hasHousehold, item.sharedWithHousehold else { return }
        do {
            try await ensureZoneExists()
            let root = try await fetchRootRecord()
            let record = buildCKRecord(for: item, parent: root)
            _ = try await privateDB.modifyRecords(
                saving: [record], deleting: [], savePolicy: .changedKeys
            )
            await HouseholdStore.shared.refresh()
        } catch {
            RFLogger.storage.error("Household mirror of item \(item.id) failed: \(error.localizedDescription)")
            self.lastError = error.localizedDescription
        }
    }

    /// Remove the mirrored copy of an item — call when the user toggles
    /// `sharedWithHousehold` off, or deletes the source item outright.
    func removeMirror(for itemID: UUID) async {
        guard hasHousehold else { return }
        let recordID = CKRecord.ID(recordName: itemID.uuidString, zoneID: Self.rootRecordID.zoneID)
        do {
            _ = try await privateDB.modifyRecords(saving: [], deleting: [recordID])
            await HouseholdStore.shared.refresh()
        } catch let error as CKError where error.code == .unknownItem {
            // Already gone — nothing to do.
        } catch {
            RFLogger.storage.error("Household remove of item \(itemID) failed: \(error.localizedDescription)")
            self.lastError = error.localizedDescription
        }
    }

    // MARK: - CKRecord construction (with CKAsset images)

    /// Builds a `SharedReceiptItem` CKRecord for the given SwiftData item.
    /// Images are written as `CKAsset`s pointing at temp files so CloudKit
    /// handles upload as blobs rather than inlining the Data into the
    /// record (records have a 1MB field cap; receipt photos routinely
    /// exceed that).
    private func buildCKRecord(for item: ReceiptItem, parent: CKRecord) -> CKRecord {
        let id = CKRecord.ID(recordName: item.id.uuidString, zoneID: Self.rootRecordID.zoneID)
        let record = CKRecord(recordType: Self.itemRecordType, recordID: id)
        record.setParent(parent)

        record["productName"] = item.productName as NSString
        record["storeName"] = item.storeName as NSString
        record["purchaseDate"] = item.purchaseDate as NSDate
        record["priceCents"] = item.priceCents as NSNumber
        record["notes"] = item.notes as NSString
        record["isReturned"] = (item.isReturned ? 1 : 0) as NSNumber

        if let end = item.returnWindowEndDate {
            record["returnWindowEndDate"] = end as NSDate
        }
        if let warranty = item.warrantyEndDate {
            record["warrantyEndDate"] = warranty as NSDate
        }
        if let returnedAt = item.returnedAt {
            record["returnedAt"] = returnedAt as NSDate
        }

        if let receiptData = item.receiptImageData, let asset = Self.makeAsset(from: receiptData, hint: "receipt") {
            record["receiptImage"] = asset
        }
        if let itemData = item.itemImageData, let asset = Self.makeAsset(from: itemData, hint: "item") {
            record["itemImage"] = asset
        }
        return record
    }

    /// Writes Data to a temp file and returns a CKAsset pointing at it.
    /// CloudKit will upload the file contents on record save.
    private static func makeAsset(from data: Data, hint: String) -> CKAsset? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("household-\(hint)-\(UUID().uuidString).dat")
        do {
            try data.write(to: url, options: .atomic)
            return CKAsset(fileURL: url)
        } catch {
            RFLogger.storage.error("makeAsset failed for \(hint): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Full-zone enumeration (used by stale-record cleanup)

    private func fetchAllSharedRecordIDs() async throws -> [CKRecord.ID] {
        let query = CKQuery(recordType: Self.itemRecordType, predicate: NSPredicate(value: true))
        var cursor: CKQueryOperation.Cursor?
        var ids: [CKRecord.ID] = []
        repeat {
            let page: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
            if let cursor {
                page = try await privateDB.records(continuingMatchFrom: cursor)
            } else {
                page = try await privateDB.records(matching: query, inZoneWith: Self.rootRecordID.zoneID)
            }
            ids.append(contentsOf: page.matchResults.map(\.0))
            cursor = page.queryCursor
        } while cursor != nil
        return ids
    }
}
