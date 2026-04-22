import Foundation

struct WidgetReceiptItem: Codable {
    let id: String
    let productName: String
    let storeName: String
    let daysUntilReturnExpiry: Int?
    let daysUntilWarrantyExpiry: Int?
    let urgencyLevel: String  // "critical", "warning", "warrantyExpiring", "active"
    let isGift: Bool
}

enum WidgetDataProvider {
    private static var defaults: UserDefaults? {
        AppGroupConstants.sharedDefaults
    }

    static func saveTopExpiring(_ items: [WidgetReceiptItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults?.set(data, forKey: AppGroupConstants.Keys.topExpiringItems)
    }

    static func loadTopExpiring() -> [WidgetReceiptItem] {
        guard let data = defaults?.data(forKey: AppGroupConstants.Keys.topExpiringItems),
              let items = try? JSONDecoder().decode([WidgetReceiptItem].self, from: data) else {
            return []
        }
        return items
    }

    static func saveNextExpiring(_ item: WidgetReceiptItem?) {
        if let item, let data = try? JSONEncoder().encode(item) {
            defaults?.set(data, forKey: AppGroupConstants.Keys.nextExpiringItem)
        } else {
            defaults?.removeObject(forKey: AppGroupConstants.Keys.nextExpiringItem)
        }
    }

    static func loadNextExpiring() -> WidgetReceiptItem? {
        guard let data = defaults?.data(forKey: AppGroupConstants.Keys.nextExpiringItem),
              let item = try? JSONDecoder().decode(WidgetReceiptItem.self, from: data) else {
            return nil
        }
        return item
    }
}
