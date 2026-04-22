import Foundation
import Testing
import SwiftData
@testable import ReceiptFolder

// MARK: - ReturnDecisionEngine Tests

@Suite("ReturnDecisionEngine")
struct ReturnDecisionEngineTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: ReceiptItem.self, configurations: config)
    }

    private func makeItem(
        priceCents: Int = 5000,
        returnWindowEndDate: Date? = nil,
        isReturned: Bool = false,
        isGift: Bool = false,
        context: ModelContext
    ) -> ReceiptItem {
        let item = ReceiptItem(
            productName: "Test Product",
            storeName: "Test Store",
            purchaseDate: .now,
            priceCents: priceCents,
            returnWindowEndDate: returnWindowEndDate,
            isGift: isGift,
            isReturned: isReturned
        )
        context.insert(item)
        return item
    }

    @Test("High-value item with few days left returns stronglyReturn")
    func highValueFewDaysLeft() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let endDate = Calendar.current.date(byAdding: .day, value: 2, to: .now)!
        let item = makeItem(priceCents: 15000, returnWindowEndDate: endDate, context: context)

        let advice = ReturnDecisionEngine.analyze(item: item, policy: nil)

        #expect(advice != nil)
        #expect(advice?.recommendation == .stronglyReturn)
    }

    @Test("Low-value item with plenty of time returns probablyKeep")
    func lowValuePlentyOfTime() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let endDate = Calendar.current.date(byAdding: .day, value: 60, to: .now)!
        let item = makeItem(priceCents: 500, returnWindowEndDate: endDate, context: context)

        let advice = ReturnDecisionEngine.analyze(item: item, policy: nil)

        #expect(advice != nil)
        #expect(advice?.recommendation == .probablyKeep)
    }

    @Test("Item with 1 day left gets urgency boost in score")
    func oneDayLeftUrgencyBoost() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        // Use 1.5 days to ensure returnDaysRemaining computes as 1 (not 0 due to timing)
        let endDate = Date.now.addingTimeInterval(36 * 3600)
        let item = makeItem(priceCents: 5000, returnWindowEndDate: endDate, context: context)

        let advice = ReturnDecisionEngine.analyze(item: item, policy: nil)

        #expect(advice != nil)
        // Baseline 50 + 20 (moderate value) + 25 (last day) = 95
        #expect(advice!.worthItScore >= 75)
    }

    @Test("Item with closed return window returns tooLate")
    func closedReturnWindow() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let endDate = Calendar.current.date(byAdding: .day, value: -5, to: .now)!
        let item = makeItem(priceCents: 5000, returnWindowEndDate: endDate, context: context)

        let advice = ReturnDecisionEngine.analyze(item: item, policy: nil)

        #expect(advice != nil)
        #expect(advice?.recommendation == .tooLate)
        #expect(advice?.worthItScore == 0)
    }

    @Test("Item with no return window returns nil")
    func noReturnWindow() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let item = makeItem(priceCents: 5000, returnWindowEndDate: nil, context: context)

        let advice = ReturnDecisionEngine.analyze(item: item, policy: nil)

        #expect(advice == nil)
    }

    @Test("Already returned item returns nil")
    func alreadyReturned() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let endDate = Calendar.current.date(byAdding: .day, value: 10, to: .now)!
        let item = makeItem(priceCents: 5000, returnWindowEndDate: endDate, isReturned: true, context: context)

        let advice = ReturnDecisionEngine.analyze(item: item, policy: nil)

        #expect(advice == nil)
    }
}
