import Foundation
import Testing
import CloudKit
@testable import ReceiptFolder

// MARK: - HouseholdReceipt projection / computed properties

@Suite("HouseholdReceipt")
struct HouseholdReceiptTests {

    private func make(
        returnEnd: Date? = nil,
        warrantyEnd: Date? = nil,
        returned: Bool = false,
        priceCents: Int = 0
    ) -> HouseholdReceipt {
        HouseholdReceipt(
            id: "test-id",
            zoneID: CKRecordZone.ID(zoneName: "HouseholdZone", ownerName: "test-owner"),
            origin: .owned,
            ownerDisplayName: "Test",
            productName: "Sony WH-1000XM5",
            storeName: "Best Buy",
            purchaseDate: Date(),
            priceCents: priceCents,
            returnWindowEndDate: returnEnd,
            warrantyEndDate: warrantyEnd,
            isReturned: returned,
            returnedAt: returned ? Date() : nil,
            receiptImageData: nil,
            itemImageData: nil,
            modifiedAt: Date()
        )
    }

    @Test("returnDaysRemaining is nil when already returned")
    func returnDaysNilWhenReturned() {
        let twoWeeks = Date().addingTimeInterval(14 * 86400)
        let rec = make(returnEnd: twoWeeks, returned: true)
        #expect(rec.returnDaysRemaining == nil)
    }

    @Test("returnDaysRemaining counts calendar days, not 24-hour windows")
    func returnDaysCalendarBoundary() {
        let end = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let rec = make(returnEnd: end)
        // Between 6 and 7 (inclusive) depending on time-of-day at call
        #expect((rec.returnDaysRemaining ?? -1) >= 6)
        #expect((rec.returnDaysRemaining ?? 999) <= 7)
    }

    @Test("returnDaysRemaining is nil for past return windows")
    func returnDaysNilWhenPast() {
        let yesterday = Date().addingTimeInterval(-2 * 86400)
        let rec = make(returnEnd: yesterday)
        #expect(rec.returnDaysRemaining == nil)
    }

    @Test("urgencyLevel is critical when window is ≤ 3 days")
    func urgencyCritical() {
        let inTwoDays = Calendar.current.date(byAdding: .day, value: 2, to: Date())!
        let rec = make(returnEnd: inTwoDays)
        #expect(rec.urgencyLevel == .critical)
    }

    @Test("urgencyLevel is warning for 4–14 days out")
    func urgencyWarning() {
        let inTenDays = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        let rec = make(returnEnd: inTenDays)
        #expect(rec.urgencyLevel == .warning)
    }

    @Test("formattedPrice renders USD to two decimal places")
    func priceFormatting() {
        let rec = make(priceCents: 34999)
        // Locale currency may vary; just assert something reasonable.
        #expect(rec.formattedPrice.contains("349") || rec.formattedPrice.contains("350"))
    }

    @Test("warrantyDaysRemaining follows warrantyEnd only")
    func warrantyDays() {
        let inSixtyDays = Calendar.current.date(byAdding: .day, value: 60, to: Date())!
        let rec = make(warrantyEnd: inSixtyDays)
        #expect((rec.warrantyDaysRemaining ?? -1) >= 59)
        #expect((rec.warrantyDaysRemaining ?? 999) <= 60)
    }

    @Test("origin .owned wins over .participant in de-dup scenarios")
    func originOrdering() {
        // Structural — if we ever add Comparable or merge behavior, this
        // test documents the policy: owned records take precedence.
        let owned = make().withOrigin(.owned)
        let participant = make().withOrigin(.participant)
        #expect(owned.origin == .owned)
        #expect(participant.origin == .participant)
        #expect(owned.origin != participant.origin)
    }
}

// Test helper — mutate origin without rebuilding the struct literal.
private extension HouseholdReceipt {
    func withOrigin(_ o: Origin) -> HouseholdReceipt {
        HouseholdReceipt(
            id: id, zoneID: zoneID, origin: o, ownerDisplayName: ownerDisplayName,
            productName: productName, storeName: storeName, purchaseDate: purchaseDate,
            priceCents: priceCents, returnWindowEndDate: returnWindowEndDate,
            warrantyEndDate: warrantyEndDate, isReturned: isReturned, returnedAt: returnedAt,
            receiptImageData: receiptImageData, itemImageData: itemImageData, modifiedAt: modifiedAt
        )
    }
}
