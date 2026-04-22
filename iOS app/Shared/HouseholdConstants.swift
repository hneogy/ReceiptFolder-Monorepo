import Foundation
import CloudKit

/// Shared constants for the household sharing feature. Both
/// `HouseholdStore` (readable by all targets) and `FamilySharingService`
/// (iOS-only, because it uses UICloudSharingController-adjacent UI) pull
/// these from here so the wire format stays in one place.
enum HouseholdConstants {
    static let zoneName = "HouseholdZone"
    static let rootRecordType = "HouseholdRoot"
    static let itemRecordType = "SharedReceiptItem"

    static var rootRecordID: CKRecord.ID {
        CKRecord.ID(
            recordName: "household-root",
            zoneID: CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        )
    }
}
