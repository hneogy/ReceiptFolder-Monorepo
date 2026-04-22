import Foundation
import Testing
@testable import ReceiptFolder

@Test func urgencyLevelCalculation() {
    // Critical: ≤ 3 days
    #expect(UrgencyLevel.calculate(returnDaysRemaining: 1, warrantyDaysRemaining: 300) == .critical)
    #expect(UrgencyLevel.calculate(returnDaysRemaining: 3, warrantyDaysRemaining: 300) == .critical)

    // Warning: 4-14 days
    #expect(UrgencyLevel.calculate(returnDaysRemaining: 4, warrantyDaysRemaining: 300) == .warning)
    #expect(UrgencyLevel.calculate(returnDaysRemaining: 14, warrantyDaysRemaining: 300) == .warning)

    // Active: return > 14 days
    #expect(UrgencyLevel.calculate(returnDaysRemaining: 15, warrantyDaysRemaining: 300) == .active)

    // Warranty expiring: no return, warranty ≤ 90 days
    #expect(UrgencyLevel.calculate(returnDaysRemaining: nil, warrantyDaysRemaining: 30) == .warrantyExpiring)
    #expect(UrgencyLevel.calculate(returnDaysRemaining: nil, warrantyDaysRemaining: 90) == .warrantyExpiring)

    // Active: no return, warranty > 90 days
    #expect(UrgencyLevel.calculate(returnDaysRemaining: nil, warrantyDaysRemaining: 91) == .active)
}

@Test func returnWindowCalculatorBasic() {
    let policy = StorePolicy(
        id: "test",
        name: "Test Store",
        aliases: [],
        defaultReturnDays: 30,
        categoryOverrides: [],
        defaultWarrantyYears: 1,
        returnConditions: "Test conditions",
        returnRequirements: ["Receipt"]
    )

    let purchaseDate = Date.now
    let result = ReturnWindowCalculator.calculate(purchaseDate: purchaseDate, policy: policy)

    let expectedReturnEnd = Calendar.current.date(byAdding: .day, value: 30, to: purchaseDate)
    let expectedWarrantyEnd = Calendar.current.date(byAdding: .year, value: 1, to: purchaseDate)

    #expect(result.returnEndDate != nil)
    #expect(result.warrantyEndDate != nil)

    // Dates should be within 1 second of expected
    if let returnEnd = result.returnEndDate, let expected = expectedReturnEnd {
        #expect(abs(returnEnd.timeIntervalSince(expected)) < 1)
    }
    if let warrantyEnd = result.warrantyEndDate, let expected = expectedWarrantyEnd {
        #expect(abs(warrantyEnd.timeIntervalSince(expected)) < 1)
    }
}

@Test func unlimitedReturnPolicy() {
    let policy = StorePolicy(
        id: "costco",
        name: "Costco",
        aliases: [],
        defaultReturnDays: -1,
        categoryOverrides: [],
        defaultWarrantyYears: 0,
        returnConditions: "Anytime",
        returnRequirements: []
    )

    let result = ReturnWindowCalculator.calculate(purchaseDate: .now, policy: policy)
    #expect(result.returnEndDate == nil)
    #expect(result.warrantyEndDate == nil)
}
