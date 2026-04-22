import Foundation

/// Analyzes whether returning an item is worth the user's effort.
enum ReturnDecisionEngine {

    enum Recommendation: String {
        case stronglyReturn = "Strongly recommend returning"
        case worthReturning = "Worth returning"
        case probablyKeep = "Probably keep it"
        case tooLate = "Return window closed"
    }

    struct ReturnAdvice {
        let recommendation: Recommendation
        let worthItScore: Int // 0-100
        let reasoning: String
        let tips: [String]
    }

    static func analyze(item: ReceiptItem, policy: StorePolicy?) -> ReturnAdvice? {
        // Skip items the user has already resolved (returned or archived).
        guard !item.isReturned, !item.isArchived else { return nil }

        // Only analyze items with open return windows
        guard let daysRemaining = item.returnDaysRemaining, daysRemaining >= 0 else {
            if item.returnWindowEndDate != nil {
                return ReturnAdvice(
                    recommendation: .tooLate,
                    worthItScore: 0,
                    reasoning: "The return window has closed.",
                    tips: ["Check if the store offers exchange-only options past the return date."]
                )
            }
            return nil
        }

        var score = 50 // baseline
        var factors: [String] = []
        var tips: [String] = []

        // Factor 1: Item value (0-30 points)
        let dollars = Double(item.priceCents) / 100.0
        if dollars >= 100 {
            score += 30
            factors.append("High-value item (\(item.formattedPrice))")
        } else if dollars >= 50 {
            score += 20
            factors.append("Moderate-value item (\(item.formattedPrice))")
        } else if dollars >= 20 {
            score += 10
            factors.append("Item valued at \(item.formattedPrice)")
        } else if dollars > 0 {
            score -= 10
            factors.append("Low-value item (\(item.formattedPrice)) — may not be worth the trip")
        }

        // Factor 2: Time urgency (0-25 points)
        if daysRemaining <= 1 {
            score += 25
            factors.append("Last day — act now or lose the option")
        } else if daysRemaining <= 3 {
            score += 20
            factors.append("Only \(daysRemaining) days left — deadline approaching fast")
        } else if daysRemaining <= 7 {
            score += 10
            factors.append("\(daysRemaining) days remaining — good time to decide")
        } else if daysRemaining <= 14 {
            score += 5
            factors.append("\(daysRemaining) days remaining — no rush yet")
        } else {
            score -= 5
            factors.append("Plenty of time (\(daysRemaining) days) — you can wait")
        }

        // Factor 3: Policy strictness (-10 to +10 points)
        if let policy = policy {
            if !policy.returnRequirements.isEmpty {
                tips.append(contentsOf: policy.returnRequirements.prefix(3))
            }

            // Check for restocking fees or exchange-only in category overrides
            let hasRestockingRisk = policy.categoryOverrides.contains { override in
                override.exchangeOnly == true || override.returnDays == 0
            }
            if hasRestockingRisk {
                score -= 5
                factors.append("Some categories at \(policy.name) are exchange-only")
            }

            if policy.isUnlimitedReturn {
                score -= 15
                factors.append("\(policy.name) has a generous return policy — no rush")
            }
        }

        // Clamp score
        score = max(0, min(100, score))

        // Determine recommendation
        let recommendation: Recommendation
        if score >= 75 {
            recommendation = .stronglyReturn
        } else if score >= 50 {
            recommendation = .worthReturning
        } else {
            recommendation = .probablyKeep
        }

        // Build reasoning string
        let reasoning = factors.prefix(2).joined(separator: ". ") + "."

        // Add general tips if needed
        if tips.isEmpty {
            if item.isGift {
                tips.append("As a gift return, check if the store offers gift receipts or store credit.")
            }
            tips.append("Bring your receipt and original packaging for the smoothest experience.")
        }

        return ReturnAdvice(
            recommendation: recommendation,
            worthItScore: score,
            reasoning: reasoning,
            tips: tips
        )
    }
}
