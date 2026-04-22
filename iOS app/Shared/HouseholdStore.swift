import Foundation
import CloudKit
import SwiftUI
import OSLog

/// Shared-target logger — RFLogger is in the iOS app target only.
private let householdLog = Logger(subsystem: "com.receiptfolder", category: "household")

// MARK: - Value type

/// A receipt that belongs to a household — mirrored by another device through
/// a CloudKit shared record zone. Lives outside SwiftData because the shared
/// data lives in a different CKDatabase (the shared one, not the private one)
/// and SwiftData's CloudKit integration only speaks to the private DB.
///
/// This is a read-mostly projection. Users interact with it through the
/// `HouseholdStore` (for writes back) and render it alongside their own
/// `ReceiptItem`s in the vault.
struct HouseholdReceipt: Identifiable, Hashable {
    /// Record name in CloudKit (matches the owner's ReceiptItem.id.uuidString).
    let id: String
    /// Record zone the record lives in — needed to route writes back.
    let zoneID: CKRecordZone.ID
    /// Whether the record lives in our own private DB (we own this household)
    /// or in our shared DB (we joined someone else's household). Affects which
    /// CKDatabase we write back through.
    let origin: Origin
    /// Name or email of the person who contributed this receipt, pulled from
    /// the CKShare participant record. "Shared" when unresolved.
    let ownerDisplayName: String

    // Payload
    let productName: String
    let storeName: String
    let purchaseDate: Date
    let priceCents: Int
    let returnWindowEndDate: Date?
    let warrantyEndDate: Date?
    let isReturned: Bool
    let returnedAt: Date?
    let receiptImageData: Data?
    let itemImageData: Data?
    let modifiedAt: Date

    enum Origin: Hashable {
        case owned       // in our privateCloudDatabase
        case participant // in our sharedCloudDatabase
    }

    // MARK: - Computed (mirror ReceiptItem's public interface for UI reuse)

    var formattedPrice: String {
        let dollars = Double(priceCents) / 100.0
        return dollars.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }

    var returnDaysRemaining: Int? {
        guard let end = returnWindowEndDate, !isReturned else { return nil }
        return Self.calendarDays(from: .now, to: end)
    }

    var warrantyDaysRemaining: Int? {
        guard let end = warrantyEndDate else { return nil }
        return Self.calendarDays(from: .now, to: end)
    }

    var urgencyLevel: UrgencyLevel {
        UrgencyLevel.calculate(
            returnDaysRemaining: returnDaysRemaining,
            warrantyDaysRemaining: warrantyDaysRemaining
        )
    }

    private static func calendarDays(from start: Date, to end: Date) -> Int? {
        let cal = Calendar.current
        let s = cal.startOfDay(for: start)
        let e = cal.startOfDay(for: end)
        let d = cal.dateComponents([.day], from: s, to: e).day ?? 0
        return d >= 0 ? d : nil
    }
}

// MARK: - Store

/// Reads household-shared receipts from CloudKit and publishes them as an
/// observable list. Handles both sides of the share:
///
/// - **Owners** — we created the household; shared records live in our
///   `privateCloudDatabase` under the `HouseholdZone` custom zone.
/// - **Participants** — we accepted someone else's invite; their records
///   appear in our `sharedCloudDatabase` across one or more shared zones.
///
/// The store merges both paths into one `records` array. Call `refresh()`
/// after accepting an invite, after the app foregrounds, and after the
/// owner mirrors an item through `FamilySharingService`.
@MainActor
@Observable
final class HouseholdStore {
    static let shared = HouseholdStore()

    private(set) var records: [HouseholdReceipt] = []
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var lastFetched: Date?

    private var container: CKContainer {
        CKContainer(identifier: AppGroupConstants.cloudKitContainerID)
    }

    private init() {}

    // MARK: - Refresh

    /// Full re-read from both DBs. Cheap in practice — the query is scoped
    /// to one record type across at most a handful of zones. For large
    /// households we'd switch to `CKFetchRecordZoneChangesOperation` with a
    /// change token; v1 of de-beta-ing keeps it to one query.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        var merged: [HouseholdReceipt] = []

        // Owned side — our private DB, if the household zone exists there.
        do {
            let owned = try await fetchOwnedRecords()
            merged.append(contentsOf: owned)
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .unknownItem {
            // No household owned here — normal for participants-only.
        } catch {
            householdLog.error("HouseholdStore owned-fetch failed: \(error.localizedDescription)")
            self.lastError = error.localizedDescription
        }

        // Participant side — walk all zones in our sharedCloudDatabase.
        do {
            let participant = try await fetchParticipantRecords()
            merged.append(contentsOf: participant)
        } catch {
            householdLog.error("HouseholdStore participant-fetch failed: \(error.localizedDescription)")
            self.lastError = error.localizedDescription
        }

        // De-dup by id (ownership-is-also-joined edge case) — owned wins.
        var byID: [String: HouseholdReceipt] = [:]
        for rec in merged {
            if let existing = byID[rec.id], existing.origin == .owned { continue }
            byID[rec.id] = rec
        }
        self.records = byID.values.sorted { $0.modifiedAt > $1.modifiedAt }
        self.lastFetched = .now
        if !merged.isEmpty { self.lastError = nil }
    }

    // MARK: - Write-back

    /// Flip `isReturned` on a household record and push the change back to
    /// the right database. Routes by `origin` — owner writes go to the
    /// private DB, participant writes go to the shared DB.
    func markReturned(_ id: String, returned: Bool = true) async throws {
        guard let rec = records.first(where: { $0.id == id }) else { return }
        let db = (rec.origin == .owned) ? container.privateCloudDatabase : container.sharedCloudDatabase
        let recordID = CKRecord.ID(recordName: rec.id, zoneID: rec.zoneID)

        let ck = try await db.record(for: recordID)
        ck["isReturned"] = (returned ? 1 : 0) as NSNumber
        ck["returnedAt"] = (returned ? Date() : nil) as NSDate?

        _ = try await db.modifyRecords(
            saving: [ck], deleting: [],
            savePolicy: .changedKeys  // last-writer-wins on just the fields we touched
        )
        await refresh()
    }

    // MARK: - Private fetch helpers

    private func fetchOwnedRecords() async throws -> [HouseholdReceipt] {
        let db = container.privateCloudDatabase
        let zoneID = HouseholdConstants.rootRecordID.zoneID
        return try await fetchAllRecords(
            in: db, zoneID: zoneID, origin: .owned, ownerDisplayName: "You"
        )
    }

    private func fetchParticipantRecords() async throws -> [HouseholdReceipt] {
        let db = container.sharedCloudDatabase
        let zones = try await db.allRecordZones()
        var all: [HouseholdReceipt] = []
        for zone in zones {
            // Best-effort owner name — the zone's owner record name is an
            // opaque CloudKit identifier, not human text. We fetch the share
            // root to try for a CKShare.Metadata that carries a display name.
            let name = (try? await participantDisplayName(in: zone, db: db)) ?? "Shared"
            let zoneRecords = try await fetchAllRecords(
                in: db, zoneID: zone.zoneID, origin: .participant, ownerDisplayName: name
            )
            all.append(contentsOf: zoneRecords)
        }
        return all
    }

    /// Core query loop — pulls every `SharedReceiptItem` in a zone and
    /// maps them into `HouseholdReceipt`s.
    private func fetchAllRecords(
        in db: CKDatabase,
        zoneID: CKRecordZone.ID,
        origin: HouseholdReceipt.Origin,
        ownerDisplayName: String
    ) async throws -> [HouseholdReceipt] {
        let query = CKQuery(
            recordType: HouseholdConstants.itemRecordType,
            predicate: NSPredicate(value: true)
        )
        var cursor: CKQueryOperation.Cursor?
        var out: [HouseholdReceipt] = []

        repeat {
            let page: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
            if let cursor {
                page = try await db.records(continuingMatchFrom: cursor)
            } else {
                page = try await db.records(matching: query, inZoneWith: zoneID)
            }
            for (_, result) in page.matchResults {
                if case .success(let ck) = result {
                    out.append(map(record: ck, origin: origin, ownerDisplayName: ownerDisplayName))
                }
            }
            cursor = page.queryCursor
        } while cursor != nil

        return out
    }

    private func participantDisplayName(in zone: CKRecordZone, db: CKDatabase) async throws -> String? {
        // The share itself is a regular record named `cloudkit.zoneshare`
        // (well-known). Fetching it gives us access to participants — the
        // owner is identifiable there.
        let shareID = CKRecord.ID(recordName: "cloudkit.zoneshare", zoneID: zone.zoneID)
        guard let share = try? await db.record(for: shareID) as? CKShare else { return nil }
        if let owner = share.participants.first(where: { $0.role == .owner }),
           let components = owner.userIdentity.nameComponents {
            return components.formatted()
        }
        return share.participants.first(where: { $0.role == .owner })?
            .userIdentity.lookupInfo?.emailAddress
    }

    private func map(record: CKRecord, origin: HouseholdReceipt.Origin, ownerDisplayName: String) -> HouseholdReceipt {
        func data(for key: String) -> Data? {
            guard let asset = record[key] as? CKAsset, let url = asset.fileURL else { return nil }
            return try? Data(contentsOf: url)
        }
        return HouseholdReceipt(
            id: record.recordID.recordName,
            zoneID: record.recordID.zoneID,
            origin: origin,
            ownerDisplayName: ownerDisplayName,
            productName: (record["productName"] as? String) ?? "",
            storeName: (record["storeName"] as? String) ?? "",
            purchaseDate: (record["purchaseDate"] as? Date) ?? .now,
            priceCents: (record["priceCents"] as? Int) ?? 0,
            returnWindowEndDate: record["returnWindowEndDate"] as? Date,
            warrantyEndDate: record["warrantyEndDate"] as? Date,
            isReturned: ((record["isReturned"] as? Int) ?? 0) == 1,
            returnedAt: record["returnedAt"] as? Date,
            receiptImageData: data(for: "receiptImage"),
            itemImageData: data(for: "itemImage"),
            modifiedAt: record.modificationDate ?? .now
        )
    }
}
