import Testing
@testable import ReceiptFolder

// MARK: - StorePolicyService Tests

@Suite("StorePolicyService")
@MainActor
struct StorePolicyServiceTests {

    @Test("findPolicy with exact name 'Target' returns Target policy")
    func findPolicyExactMatch() {
        let service = StorePolicyService.shared
        let policy = service.findPolicy(storeName: "Target")

        #expect(policy != nil)
        #expect(policy?.name == "Target")
    }

    @Test("findPolicy is case-insensitive")
    func findPolicyCaseInsensitive() {
        let service = StorePolicyService.shared
        let policy = service.findPolicy(storeName: "target")

        #expect(policy != nil)
        #expect(policy?.name == "Target")
    }

    @Test("findPolicy matches alias 'BEST BUY CO'")
    func findPolicyAliasMatch() {
        let service = StorePolicyService.shared
        let policy = service.findPolicy(storeName: "BEST BUY CO")

        #expect(policy != nil)
        #expect(policy?.name == "Best Buy")
    }

    @Test("findPolicy returns nil for unknown store")
    func findPolicyUnknownStore() {
        let service = StorePolicyService.shared
        let policy = service.findPolicy(storeName: "nonexistent-store")

        #expect(policy == nil)
    }

    @Test("allPolicies returns non-empty array")
    func allPoliciesNotEmpty() {
        let service = StorePolicyService.shared
        let policies = service.allPolicies()

        #expect(!policies.isEmpty)
    }

    @Test("findPolicyFromOCRText matches 'TARGET' in receipt header")
    func findPolicyFromOCRText() {
        let service = StorePolicyService.shared
        let policy = service.findPolicyFromOCRText("Thank you for shopping at TARGET")

        #expect(policy != nil)
        #expect(policy?.name == "Target")
    }
}
