import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

@MainActor
final class SpotlightIndexer {
    static let shared = SpotlightIndexer()

    private let index = CSSearchableIndex.default()

    private init() {}

    func indexItem(_ item: ReceiptItem) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .item)
        attributeSet.title = item.productName
        attributeSet.contentDescription = "\(item.storeName) · \(item.purchaseDate.formatted(date: .abbreviated, time: .omitted)) · \(item.formattedPrice)"
        attributeSet.keywords = [item.productName, item.storeName, "receipt", "return", "warranty"]

        if let days = item.returnDaysRemaining, days > 0 {
            attributeSet.contentDescription! += " · Return: \(days) days left"
        }
        if let days = item.warrantyDaysRemaining, days > 0 {
            attributeSet.contentDescription! += " · Warranty: \(days) days left"
        }

        // Store thumbnail from model data if available
        if let imageData = item.receiptImageData {
            attributeSet.thumbnailData = imageData
        } else if !item.receiptImagePath.isEmpty {
            // Legacy fallback: thumbnail from file path
            let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let imagePath = docsDir.appendingPathComponent(item.receiptImagePath)
            if FileManager.default.fileExists(atPath: imagePath.path) {
                attributeSet.thumbnailURL = imagePath
            }
        }

        let searchableItem = CSSearchableItem(
            uniqueIdentifier: item.id.uuidString,
            domainIdentifier: "com.receiptfolder.items",
            attributeSet: attributeSet
        )
        // Keep indexed for 1 year
        searchableItem.expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: .now)

        index.indexSearchableItems([searchableItem])
    }

    func removeItem(_ itemID: UUID) {
        index.deleteSearchableItems(withIdentifiers: [itemID.uuidString])
    }

    func reindexAll(items: [ReceiptItem]) async {
        do {
            try await index.deleteSearchableItems(withDomainIdentifiers: ["com.receiptfolder.items"])
        } catch {
            RFLogger.spotlight.error("Failed to delete searchable items before reindex: \(error)")
        }
        for item in items where !item.isArchived {
            indexItem(item)
        }
    }
}
