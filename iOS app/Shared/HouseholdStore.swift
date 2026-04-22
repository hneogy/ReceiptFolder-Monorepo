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

    // MARK: - Delta-sync state
    //
    // We fetch with CKFetchRecordZoneChangesOperation on every refresh, not
    // a full CKQueryOperation. That means after the initial seed, each
    // refresh only transfers the records that actually changed since our
    // last server change token. For a household with a thousand receipts
    // and one daily edit, this drops the payload from ~N records to 1.
    //
    // State we maintain:
    //  - `zoneRecords`: in-memory cache of every record we've seen, keyed
    //     by CKRecord.ID. The source of truth for what we render.
    //  - `zoneTokens`: per-zone CKServerChangeToken, persisted in UserDefaults
    //     so a cold launch doesn't re-download everything.
    //  - `databaseTokens`: per-database change token (private + shared), also
    //     persisted. Used by CKFetchDatabaseChangesOperation to discover new
    //     or removed zones (e.g. a freshly-accepted invite adds a new zone
    //     to sharedCloudDatabase).

    private struct CachedRecord {
        let record: CKRecord
        let origin: HouseholdReceipt.Origin
        let ownerDisplayName: String
    }

    /// Flat cache keyed by CKRecord.ID so a delete token from CloudKit can
    /// be applied in O(1).
    private var cache: [CKRecord.ID: CachedRecord] = [:]

    private enum DefaultsKey {
        static let privateDBToken = "household.privateDBToken.v1"
        static let sharedDBToken = "household.sharedDBToken.v1"
        static let zoneTokenPrefix = "household.zoneToken.v1."
    }

    private init() {
        // Load any persisted cached records. We keep the CKRecord objects
        // themselves only in memory — persisting CKRecords between launches
        // is possible (archivedData + CKRecord(coder:)) but the savings
        // aren't worth the complexity for v1; a cold launch re-fetches
        // everything against the existing tokens, which returns an empty
        // delta (no network payload) and tells us "you're up to date."
        // What does persist are the tokens themselves.
    }

    // MARK: - Push subscriptions
    //
    // Silent CKDatabaseSubscriptions on both the private and shared
    // databases mean CloudKit pushes a notification whenever *any* record
    // in either database changes. We register once per install (keyed in
    // UserDefaults) and refresh the store when the push lands.

    private enum SubscriptionKey {
        static let registered = "householdSubscriptionsRegistered.v2"
        static let privateID = "rf-household-private"
        static let sharedID = "rf-household-shared"
    }

    /// Registers silent database subscriptions for both the private and
    /// shared CloudKit databases. Idempotent — a completed registration is
    /// cached in UserDefaults so we don't hit the CloudKit API on every
    /// launch. Call once during app foreground after account status is
    /// known.
    func registerSubscriptionsIfNeeded() async {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: SubscriptionKey.registered) else { return }

        do {
            try await registerDatabaseSubscription(
                on: container.privateCloudDatabase,
                id: SubscriptionKey.privateID
            )
            try await registerDatabaseSubscription(
                on: container.sharedCloudDatabase,
                id: SubscriptionKey.sharedID
            )
            defaults.set(true, forKey: SubscriptionKey.registered)
        } catch {
            householdLog.error("Subscription registration failed: \(error.localizedDescription)")
        }
    }

    private func registerDatabaseSubscription(on db: CKDatabase, id: String) async throws {
        let subscription = CKDatabaseSubscription(subscriptionID: id)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true   // silent push
        subscription.notificationInfo = notificationInfo

        do {
            _ = try await db.save(subscription)
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Already exists — fine.
        }
    }

    /// Called from the app's remote-notification handler when a CloudKit
    /// subscription fires. Triggers a full refresh; the records array
    /// recomputes with fresh data from both databases.
    func handlePushedChange() async {
        await refresh()
    }

    // MARK: - Refresh

    /// Pulls deltas from both CloudKit databases using change tokens and
    /// rebuilds the `records` array from the in-memory cache. Call on:
    ///
    /// - App foreground (warm path — typically no-op if nothing changed)
    /// - Incoming silent push (`handlePushedChange`)
    /// - Right after accepting an invite (seeds the cache for the new zone)
    /// - Right after an outbound mirror write (optimistic UI catch-up)
    ///
    /// Cold-launch semantics: tokens persist in UserDefaults but the
    /// in-memory cache does not. On the first refresh after launch, if
    /// the cache is empty, we invalidate the stored tokens and do a full
    /// seed fetch. That gives us the records we need to render without
    /// having to serialize CKRecords between launches.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        // Cold launch recovery: tokens without cache is useless — CloudKit
        // would return an empty delta, leaving the vault blank. Drop the
        // tokens so the upcoming fetches seed from scratch.
        if cache.isEmpty && (storedDatabaseToken(.private) != nil || storedDatabaseToken(.shared) != nil) {
            householdLog.info("Cache empty on cold launch; invalidating persisted tokens for full reseed")
            clearAllTokens()
        }

        // Private DB — our owned household zone, if it exists.
        do {
            try await syncDatabase(.private)
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .unknownItem {
            // Fine — no household owned here.
        } catch {
            householdLog.error("HouseholdStore private-sync failed: \(error.localizedDescription)")
            self.lastError = error.localizedDescription
        }

        // Shared DB — all zones we've joined.
        do {
            try await syncDatabase(.shared)
        } catch {
            householdLog.error("HouseholdStore shared-sync failed: \(error.localizedDescription)")
            self.lastError = error.localizedDescription
        }

        rebuildRecordsFromCache()
        self.lastFetched = .now
    }

    private func rebuildRecordsFromCache() {
        // De-dup by record name — owned wins over participant for the edge
        // case where the owner is also somehow joined.
        var byID: [String: HouseholdReceipt] = [:]
        for (_, cached) in cache {
            let projected = map(
                record: cached.record,
                origin: cached.origin,
                ownerDisplayName: cached.ownerDisplayName
            )
            if let existing = byID[projected.id], existing.origin == .owned { continue }
            byID[projected.id] = projected
        }
        self.records = byID.values.sorted { $0.modifiedAt > $1.modifiedAt }
        if !cache.isEmpty { self.lastError = nil }
    }

    // MARK: - Write-back

    /// Flip `isReturned` on a household record and push the change back to
    /// the right database. Routes by `origin` — owner writes go to the
    /// private DB, participant writes go to the shared DB.
    ///
    /// Conflict policy: `.changedKeys` ensures we only overwrite the two
    /// fields we touch (isReturned, returnedAt). If the server record has
    /// been changed out from under us in another key, we leave those
    /// untouched. On the rare `.serverRecordChanged` (e.g. a concurrent
    /// mark-returned from another device with the same keys), we retry
    /// once by re-fetching and re-applying our change on top.
    func markReturned(_ id: String, returned: Bool = true) async throws {
        guard let rec = records.first(where: { $0.id == id }) else { return }
        let db = (rec.origin == .owned) ? container.privateCloudDatabase : container.sharedCloudDatabase
        let recordID = CKRecord.ID(recordName: rec.id, zoneID: rec.zoneID)

        func attempt() async throws {
            let ck = try await db.record(for: recordID)
            ck["isReturned"] = (returned ? 1 : 0) as NSNumber
            ck["returnedAt"] = (returned ? Date() : nil) as NSDate?
            _ = try await db.modifyRecords(
                saving: [ck], deleting: [], savePolicy: .changedKeys
            )
        }

        do {
            try await attempt()
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Another device touched the same keys between our fetch and
            // save. Re-fetch and try once more — if it fails again we bail
            // and let the caller surface the error.
            householdLog.info("markReturned: serverRecordChanged, retrying once")
            try await attempt()
        }
        await refresh()
    }

    // MARK: - Delta sync — database + zone changes

    private enum DatabaseKind {
        case `private`, shared
    }

    /// Resolve the CKDatabase for a given kind — separated so tests can
    /// substitute fakes and the per-kind default-key lookup stays readable.
    private func db(for kind: DatabaseKind) -> CKDatabase {
        switch kind {
        case .private: return container.privateCloudDatabase
        case .shared: return container.sharedCloudDatabase
        }
    }

    /// Drive a full delta sync against one database. Two-phase:
    /// 1. `CKFetchDatabaseChangesOperation` discovers which zones have
    ///    changed, been added, or been removed since our last DB token.
    /// 2. For each changed zone, `CKFetchRecordZoneChangesOperation` pulls
    ///    the per-record deltas (adds, modifies, deletes).
    private func syncDatabase(_ kind: DatabaseKind) async throws {
        let database = db(for: kind)

        // Phase 1: discover changed zones.
        let dbResult = try await fetchDatabaseChanges(on: database, kind: kind)

        // Apply zone-level deletions first (revoked shares, etc.).
        for zoneID in dbResult.deletedZoneIDs {
            evictZoneFromCache(zoneID)
            clearZoneToken(zoneID)
        }

        // For the private DB, the only zone we care about is our household
        // zone. If we've never synced it, discover says "no changes" because
        // the server's tracked state for us is empty. Seed it explicitly.
        var zonesToSync = dbResult.changedZoneIDs
        if kind == .private {
            let ownedZone = HouseholdConstants.rootRecordID.zoneID
            if !zonesToSync.contains(ownedZone) && storedZoneToken(ownedZone) == nil {
                zonesToSync.append(ownedZone)
            }
        }

        // Phase 2: pull record deltas per zone.
        for zoneID in zonesToSync {
            let ownerName: String
            if kind == .private {
                ownerName = "You"
            } else {
                ownerName = (try? await participantDisplayName(in: zoneID, db: database)) ?? "Shared"
            }
            try await syncZone(
                zoneID,
                in: database,
                origin: kind == .private ? .owned : .participant,
                ownerDisplayName: ownerName
            )
        }
    }

    /// Runs `CKFetchDatabaseChangesOperation` and collects the results into a
    /// simple value type. Resumes the async continuation only after the
    /// operation's completion block — not inside per-record blocks — so the
    /// caller sees a single, coherent result.
    private func fetchDatabaseChanges(
        on database: CKDatabase,
        kind: DatabaseKind
    ) async throws -> DatabaseChangeResult {
        let result: DatabaseChangeResult = try await withCheckedThrowingContinuation { continuation in
            let op = CKFetchDatabaseChangesOperation(
                previousServerChangeToken: storedDatabaseToken(kind)
            )
            var changed: [CKRecordZone.ID] = []
            var deleted: [CKRecordZone.ID] = []
            var newToken: CKServerChangeToken?

            op.recordZoneWithIDChangedBlock = { changed.append($0) }
            op.recordZoneWithIDWasDeletedBlock = { deleted.append($0) }
            op.changeTokenUpdatedBlock = { newToken = $0 }
            op.fetchDatabaseChangesResultBlock = { outcome in
                switch outcome {
                case .success(let (token, _)):
                    newToken = token
                    continuation.resume(returning: DatabaseChangeResult(
                        changedZoneIDs: changed,
                        deletedZoneIDs: deleted,
                        newToken: newToken
                    ))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(op)
        }

        // Persist the new database token once the operation succeeds, so
        // the next call only fetches zones that changed after this one.
        if let token = result.newToken {
            setDatabaseToken(token, for: kind)
        }
        return result
    }

    private struct DatabaseChangeResult {
        let changedZoneIDs: [CKRecordZone.ID]
        let deletedZoneIDs: [CKRecordZone.ID]
        let newToken: CKServerChangeToken?
    }

    /// Pulls one zone's record deltas and folds them into the cache.
    /// Applies deletions, upserts changed/added records, and persists the
    /// updated per-zone change token on success.
    private func syncZone(
        _ zoneID: CKRecordZone.ID,
        in database: CKDatabase,
        origin: HouseholdReceipt.Origin,
        ownerDisplayName: String
    ) async throws {
        let previousToken = storedZoneToken(zoneID)

        let result: ZoneChangeResult = try await withCheckedThrowingContinuation { continuation in
            let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            config.previousServerChangeToken = previousToken
            let op = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: config]
            )
            var changed: [CKRecord] = []
            var deletedIDs: [CKRecord.ID] = []
            var newToken: CKServerChangeToken?

            op.recordWasChangedBlock = { _, outcome in
                if case .success(let record) = outcome {
                    changed.append(record)
                }
            }
            op.recordWithIDWasDeletedBlock = { id, _ in
                deletedIDs.append(id)
            }
            op.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
                if let token { newToken = token }
            }
            op.recordZoneFetchResultBlock = { _, outcome in
                switch outcome {
                case .success(let (token, _, _)):
                    newToken = token
                case .failure:
                    break // surfaced in fetchRecordZoneChangesResultBlock
                }
            }
            op.fetchRecordZoneChangesResultBlock = { outcome in
                switch outcome {
                case .success:
                    continuation.resume(returning: ZoneChangeResult(
                        changedRecords: changed,
                        deletedRecordIDs: deletedIDs,
                        newToken: newToken
                    ))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(op)
        }

        // Apply deletions.
        for id in result.deletedRecordIDs {
            cache.removeValue(forKey: id)
        }
        // Upsert changes — but skip CKShare / HouseholdRoot records; we
        // only cache SharedReceiptItem entries for vault display.
        for record in result.changedRecords where record.recordType == HouseholdConstants.itemRecordType {
            cache[record.recordID] = CachedRecord(
                record: record,
                origin: origin,
                ownerDisplayName: ownerDisplayName
            )
        }
        // Persist the new token so the next sync is a no-op if nothing
        // changed again.
        if let newToken = result.newToken {
            setZoneToken(newToken, for: zoneID)
        }
    }

    private struct ZoneChangeResult {
        let changedRecords: [CKRecord]
        let deletedRecordIDs: [CKRecord.ID]
        let newToken: CKServerChangeToken?
    }

    private func evictZoneFromCache(_ zoneID: CKRecordZone.ID) {
        cache = cache.filter { $0.key.zoneID != zoneID }
    }

    private func participantDisplayName(in zoneID: CKRecordZone.ID, db: CKDatabase) async throws -> String? {
        // The share itself is a regular record named `cloudkit.zoneshare`
        // (well-known). Fetching it gives us access to participants — the
        // owner is identifiable there.
        let shareID = CKRecord.ID(recordName: "cloudkit.zoneshare", zoneID: zoneID)
        guard let share = try? await db.record(for: shareID) as? CKShare else { return nil }
        if let owner = share.participants.first(where: { $0.role == .owner }),
           let components = owner.userIdentity.nameComponents {
            return components.formatted()
        }
        return share.participants.first(where: { $0.role == .owner })?
            .userIdentity.lookupInfo?.emailAddress
    }

    // MARK: - Token persistence
    //
    // CKServerChangeToken conforms to NSSecureCoding. We archive to Data
    // with NSKeyedArchiver and stash in UserDefaults, keyed by DB kind or
    // zone ID. Small (~200 bytes per token), safe across app restarts.

    private func storedDatabaseToken(_ kind: DatabaseKind) -> CKServerChangeToken? {
        let key = (kind == .private) ? DefaultsKey.privateDBToken : DefaultsKey.sharedDBToken
        return readToken(forKey: key)
    }

    private func setDatabaseToken(_ token: CKServerChangeToken, for kind: DatabaseKind) {
        let key = (kind == .private) ? DefaultsKey.privateDBToken : DefaultsKey.sharedDBToken
        writeToken(token, forKey: key)
    }

    private func storedZoneToken(_ zoneID: CKRecordZone.ID) -> CKServerChangeToken? {
        readToken(forKey: zoneTokenKey(zoneID))
    }

    private func setZoneToken(_ token: CKServerChangeToken, for zoneID: CKRecordZone.ID) {
        writeToken(token, forKey: zoneTokenKey(zoneID))
    }

    private func clearZoneToken(_ zoneID: CKRecordZone.ID) {
        UserDefaults.standard.removeObject(forKey: zoneTokenKey(zoneID))
    }

    /// Wipe every token. Used on cold-launch cache-empty detection to
    /// force a full reseed.
    private func clearAllTokens() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: DefaultsKey.privateDBToken)
        defaults.removeObject(forKey: DefaultsKey.sharedDBToken)
        // Zone tokens — we don't know every key, so sweep the prefix.
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(DefaultsKey.zoneTokenPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    private func zoneTokenKey(_ zoneID: CKRecordZone.ID) -> String {
        "\(DefaultsKey.zoneTokenPrefix)\(zoneID.ownerName)/\(zoneID.zoneName)"
    }

    private func readToken(forKey key: String) -> CKServerChangeToken? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            return try NSKeyedUnarchiver.unarchivedObject(
                ofClass: CKServerChangeToken.self, from: data
            )
        } catch {
            householdLog.error("readToken(\(key)) decode failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func writeToken(_ token: CKServerChangeToken, forKey key: String) {
        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: token, requiringSecureCoding: true
            )
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            householdLog.error("writeToken(\(key)) encode failed: \(error.localizedDescription)")
        }
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
