import Foundation

struct StorePolicyDatabase: Codable {
    let stores: [StorePolicy]
}

struct StorePolicy: Codable, Identifiable {
    let id: String
    let name: String
    let aliases: [String]
    let defaultReturnDays: Int       // -1 = anytime, 0 = non-returnable
    let categoryOverrides: [CategoryOverride]
    let defaultWarrantyYears: Int
    let returnConditions: String
    let returnRequirements: [String]

    var isUnlimitedReturn: Bool { defaultReturnDays == -1 }
    var isNonReturnable: Bool { defaultReturnDays == 0 }

    /// Whether this policy was manually added by the user (vs bundled).
    var isCustom: Bool { id.hasPrefix("custom_") }
}

struct CategoryOverride: Codable {
    let category: String
    let returnDays: Int
    let exchangeOnly: Bool?
    let note: String?
}
