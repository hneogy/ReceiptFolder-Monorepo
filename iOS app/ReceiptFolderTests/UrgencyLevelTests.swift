import Testing
@testable import ReceiptFolder

// MARK: - UrgencyLevel Tests

@Suite("UrgencyLevel.calculate")
struct UrgencyLevelTests {

    @Test("Return days = 1 is critical")
    func returnDays1IsCritical() {
        let level = UrgencyLevel.calculate(returnDaysRemaining: 1, warrantyDaysRemaining: nil)
        #expect(level == .critical)
    }

    @Test("Return days = 3 is critical")
    func returnDays3IsCritical() {
        let level = UrgencyLevel.calculate(returnDaysRemaining: 3, warrantyDaysRemaining: nil)
        #expect(level == .critical)
    }

    @Test("Return days = 4 is warning")
    func returnDays4IsWarning() {
        let level = UrgencyLevel.calculate(returnDaysRemaining: 4, warrantyDaysRemaining: nil)
        #expect(level == .warning)
    }

    @Test("Return days = 14 is warning")
    func returnDays14IsWarning() {
        let level = UrgencyLevel.calculate(returnDaysRemaining: 14, warrantyDaysRemaining: nil)
        #expect(level == .warning)
    }

    @Test("Return days = 15 is active (beyond warning threshold)")
    func returnDays15IsActive() {
        let level = UrgencyLevel.calculate(returnDaysRemaining: 15, warrantyDaysRemaining: nil)
        #expect(level == .active)
    }

    @Test("No return window, warranty = 30 is warrantyExpiring")
    func warrantyExpiring30Days() {
        let level = UrgencyLevel.calculate(returnDaysRemaining: nil, warrantyDaysRemaining: 30)
        #expect(level == .warrantyExpiring)
    }

    @Test("No return window, warranty = 91 is active")
    func warranty91DaysIsActive() {
        let level = UrgencyLevel.calculate(returnDaysRemaining: nil, warrantyDaysRemaining: 91)
        #expect(level == .active)
    }

    @Test("Both nil returns active")
    func bothNilIsActive() {
        let level = UrgencyLevel.calculate(returnDaysRemaining: nil, warrantyDaysRemaining: nil)
        #expect(level == .active)
    }

    @Test("Comparison ordering: critical < warning < warrantyExpiring < active")
    func comparisonOrdering() {
        #expect(UrgencyLevel.critical < UrgencyLevel.warning)
        #expect(UrgencyLevel.warning < UrgencyLevel.warrantyExpiring)
        #expect(UrgencyLevel.warrantyExpiring < UrgencyLevel.active)
    }
}
