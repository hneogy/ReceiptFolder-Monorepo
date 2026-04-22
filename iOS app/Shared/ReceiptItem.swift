import Foundation
import SwiftData

@Model
final class ReceiptItem {
    // MARK: - CloudKit requires all fields to have defaults (no @Attribute(.unique))

    var id: UUID = UUID()

    var productName: String = ""
    var storeName: String = ""
    var purchaseDate: Date = Date()
    var priceCents: Int = 0

    // Legacy file paths — kept for migration from pre-CloudKit versions
    var receiptImagePath: String = ""
    var itemImagePath: String?

    // CloudKit-synced image data (external storage → CKAsset)
    @Attribute(.externalStorage) var receiptImageData: Data?
    @Attribute(.externalStorage) var itemImageData: Data?

    var returnWindowEndDate: Date?
    var warrantyEndDate: Date?

    var returnPolicyDescription: String = ""
    var returnRequirements: [String] = []

    var isGift: Bool = false
    var isReturned: Bool = false
    var isWarrantyClaimed: Bool = false
    var isArchived: Bool = false

    var storeAddress: String?
    var notes: String = ""
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        productName: String,
        storeName: String,
        purchaseDate: Date,
        priceCents: Int,
        receiptImagePath: String = "",
        receiptImageData: Data? = nil,
        itemImagePath: String? = nil,
        itemImageData: Data? = nil,
        returnWindowEndDate: Date? = nil,
        warrantyEndDate: Date? = nil,
        returnPolicyDescription: String = "",
        returnRequirements: [String] = [],
        isGift: Bool = false,
        isReturned: Bool = false,
        isWarrantyClaimed: Bool = false,
        isArchived: Bool = false,
        storeAddress: String? = nil,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.productName = productName
        self.storeName = storeName
        self.purchaseDate = purchaseDate
        self.priceCents = priceCents
        self.receiptImagePath = receiptImagePath
        self.receiptImageData = receiptImageData
        self.itemImagePath = itemImagePath
        self.itemImageData = itemImageData
        self.returnWindowEndDate = returnWindowEndDate
        self.warrantyEndDate = warrantyEndDate
        self.returnPolicyDescription = returnPolicyDescription
        self.returnRequirements = returnRequirements
        self.isGift = isGift
        self.isReturned = isReturned
        self.isWarrantyClaimed = isWarrantyClaimed
        self.isArchived = isArchived
        self.storeAddress = storeAddress
        self.notes = notes
        self.createdAt = createdAt
    }

    // MARK: - Computed Properties

    var formattedPrice: String {
        let dollars = Double(priceCents) / 100.0
        return dollars.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }

    /// Days remaining in the return window. Returns `nil` if no window, returned, or window has expired.
    var returnDaysRemaining: Int? {
        guard let endDate = returnWindowEndDate, !isReturned else { return nil }
        return Self.calendarDays(from: .now, to: endDate)
    }

    /// Days remaining on warranty. Returns `nil` if no warranty, claimed, or expired.
    var warrantyDaysRemaining: Int? {
        guard let endDate = warrantyEndDate, !isWarrantyClaimed else { return nil }
        return Self.calendarDays(from: .now, to: endDate)
    }

    /// Full calendar days between two moments, counted by calendar-day boundaries
    /// (midnight-to-midnight) rather than raw 24-hour windows. Prevents off-by-one
    /// where `dateComponents([.day])` drops to 0 mid-afternoon on the deadline day.
    /// Returns nil when the end date is strictly before today.
    private static func calendarDays(from start: Date, to end: Date) -> Int? {
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: start)
        let endDay = cal.startOfDay(for: end)
        let days = cal.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        guard days >= 0 else { return nil }
        return days
    }

    /// Return window is open when days remaining is 0 (last day) or more.
    var isReturnWindowOpen: Bool {
        returnDaysRemaining != nil
    }

    /// Warranty is active when days remaining is 0 (last day) or more.
    var isWarrantyActive: Bool {
        warrantyDaysRemaining != nil
    }

    var urgencyLevel: UrgencyLevel {
        UrgencyLevel.calculate(returnDaysRemaining: returnDaysRemaining, warrantyDaysRemaining: warrantyDaysRemaining)
    }

    var returnWindowProgress: Double {
        guard let endDate = returnWindowEndDate else { return 0 }
        guard purchaseDate <= .now else { return 0 }  // future purchase → no progress yet
        let total = endDate.timeIntervalSince(purchaseDate)
        let elapsed = Date.now.timeIntervalSince(purchaseDate)
        guard total > 0 else { return 1 }
        return min(1, max(0, elapsed / total))
    }

    var warrantyProgress: Double {
        guard let endDate = warrantyEndDate else { return 0 }
        guard purchaseDate <= .now else { return 0 }
        let total = endDate.timeIntervalSince(purchaseDate)
        let elapsed = Date.now.timeIntervalSince(purchaseDate)
        guard total > 0 else { return 1 }
        return min(1, max(0, elapsed / total))
    }

    /// Whether this item has a receipt image available (either in model data or legacy file)
    var hasReceiptImage: Bool {
        receiptImageData != nil || !receiptImagePath.isEmpty
    }

    /// Whether this item has an item photo available
    var hasItemImage: Bool {
        itemImageData != nil || (itemImagePath != nil && !itemImagePath!.isEmpty)
    }

    // MARK: - Validation

    enum ValidationError: LocalizedError {
        case emptyProductName
        case emptyStoreName
        case negativePrice
        case futurePurchaseDate

        var errorDescription: String? {
            switch self {
            case .emptyProductName: "Product name is required."
            case .emptyStoreName: "Store name is required."
            case .negativePrice: "Price cannot be negative."
            case .futurePurchaseDate: "Purchase date cannot be in the future."
            }
        }
    }

    static func validate(
        productName: String,
        storeName: String,
        priceCents: Int,
        purchaseDate: Date
    ) -> [ValidationError] {
        var errors: [ValidationError] = []
        if productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyProductName)
        }
        if storeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyStoreName)
        }
        if priceCents < 0 {
            errors.append(.negativePrice)
        }
        if purchaseDate > Date.now {
            errors.append(.futurePurchaseDate)
        }
        return errors
    }
}
