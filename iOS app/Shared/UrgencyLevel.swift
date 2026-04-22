import SwiftUI

enum UrgencyLevel: String, Codable, Comparable {
    case critical    // Return window ≤ 3 days
    case warning     // Return window 4–14 days
    case warrantyExpiring // Warranty ≤ 90 days, return window closed or absent
    case active      // Both windows open, no urgency

    var color: Color {
        switch self {
        case .critical: .red
        case .warning: .orange
        case .warrantyExpiring: .green
        case .active: .green.opacity(0.7)
        }
    }

    var label: String {
        switch self {
        case .critical: "Return deadline imminent"
        case .warning: "Return closing soon"
        case .warrantyExpiring: "Warranty expiring"
        case .active: "Active coverage"
        }
    }

    var sortOrder: Int {
        switch self {
        case .critical: 0
        case .warning: 1
        case .warrantyExpiring: 2
        case .active: 3
        }
    }

    static func < (lhs: UrgencyLevel, rhs: UrgencyLevel) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    static func calculate(returnDaysRemaining: Int?, warrantyDaysRemaining: Int?) -> UrgencyLevel {
        if let returnDays = returnDaysRemaining {
            if returnDays <= 3 {
                return .critical
            } else if returnDays <= 14 {
                return .warning
            }
        }

        if let warrantyDays = warrantyDaysRemaining, warrantyDays > 0, warrantyDays <= 90 {
            return .warrantyExpiring
        }

        return .active
    }
}
