import Foundation

enum ReturnWindowCalculator {
    struct Result {
        let returnEndDate: Date?
        let warrantyEndDate: Date?
        let policyDescription: String
        let returnRequirements: [String]
    }

    static func calculate(
        purchaseDate: Date,
        policy: StorePolicy,
        categoryOverride: String? = nil,
        warrantyYears: Int? = nil
    ) -> Result {
        // Determine return days
        var returnDays = policy.defaultReturnDays

        if let category = categoryOverride {
            if let override = policy.categoryOverrides.first(where: {
                $0.category.lowercased() == category.lowercased()
            }) {
                returnDays = override.returnDays
            }
        }

        // Calculate return end date
        let returnEndDate: Date?
        var effectivePolicyDescription = policy.returnConditions
        if returnDays == -1 {
            // Unlimited returns (Costco, Nordstrom, etc.) — no end date
            returnEndDate = nil
        } else if returnDays == 0 {
            // Non-returnable — stamp the policy description so the UI can
            // distinguish "explicitly non-returnable" from "no window tracked".
            returnEndDate = nil
            let prefix = "This retailer does not accept returns."
            let conditions = policy.returnConditions.trimmingCharacters(in: .whitespacesAndNewlines)
            effectivePolicyDescription = conditions.isEmpty ? prefix : "\(prefix) \(conditions)"
        } else {
            returnEndDate = Calendar.current.date(byAdding: .day, value: returnDays, to: purchaseDate)
        }

        // Calculate warranty end date
        let years = warrantyYears ?? policy.defaultWarrantyYears
        let warrantyEndDate: Date?
        if years > 0 {
            warrantyEndDate = Calendar.current.date(byAdding: .year, value: years, to: purchaseDate)
        } else {
            warrantyEndDate = nil
        }

        return Result(
            returnEndDate: returnEndDate,
            warrantyEndDate: warrantyEndDate,
            policyDescription: effectivePolicyDescription,
            returnRequirements: policy.returnRequirements
        )
    }

    static func calculateManual(
        purchaseDate: Date,
        returnDays: Int,
        warrantyYears: Int
    ) -> Result {
        let returnEndDate: Date?
        if returnDays > 0 {
            returnEndDate = Calendar.current.date(byAdding: .day, value: returnDays, to: purchaseDate)
        } else {
            returnEndDate = nil
        }

        let warrantyEndDate: Date?
        if warrantyYears > 0 {
            warrantyEndDate = Calendar.current.date(byAdding: .year, value: warrantyYears, to: purchaseDate)
        } else {
            warrantyEndDate = nil
        }

        return Result(
            returnEndDate: returnEndDate,
            warrantyEndDate: warrantyEndDate,
            policyDescription: "",
            returnRequirements: []
        )
    }
}
