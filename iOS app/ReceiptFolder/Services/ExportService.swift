import Foundation
import SwiftUI

/// Export service — snapshot on MainActor, encode/write off the main thread.
enum ExportService {

    enum ExportFormat {
        case csv
        case json
    }

    /// Snapshot of an item's exportable fields. Sendable → safe to hand to a
    /// detached task for string building / file writing without freezing the UI.
    fileprivate struct Snapshot: Sendable {
        let productName: String
        let storeName: String
        let purchaseDate: Date
        let priceCents: Int
        let formattedPrice: String
        let returnWindowEndDate: Date?
        let returnDaysRemaining: Int?
        let warrantyEndDate: Date?
        let warrantyDaysRemaining: Int?
        let returnPolicyDescription: String
        let returnRequirements: [String]
        let isReturned: Bool
        let isArchived: Bool
        let isGift: Bool
        let isReturnWindowOpen: Bool
        let notes: String
    }

    @MainActor
    static func exportItems(_ items: [ReceiptItem], format: ExportFormat) async -> URL? {
        let snapshots = items.map { Snapshot(from: $0) }
        return await Task.detached(priority: .userInitiated) {
            switch format {
            case .csv: return exportAsCSV(snapshots)
            case .json: return exportAsJSON(snapshots)
            }
        }.value
    }

    // MARK: - Format builders (safe to run off-main given Sendable snapshots)

    private static func exportAsCSV(_ items: [Snapshot]) -> URL? {
        var csv = "Product Name,Store,Purchase Date,Price,Return End Date,Warranty End Date,Status,Notes\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short

        for item in items {
            let status: String
            if item.isReturned { status = "Returned" }
            else if item.isArchived { status = "Archived" }
            else if item.isReturnWindowOpen { status = "Return Open" }
            else { status = "Active" }

            let returnEnd = item.returnWindowEndDate.map { dateFormatter.string(from: $0) } ?? ""
            let warrantyEnd = item.warrantyEndDate.map { dateFormatter.string(from: $0) } ?? ""

            csv += "\(csvEscape(item.productName)),\(csvEscape(item.storeName)),\(csvEscape(dateFormatter.string(from: item.purchaseDate))),\(csvEscape(item.formattedPrice)),\(csvEscape(returnEnd)),\(csvEscape(warrantyEnd)),\(csvEscape(status)),\(csvEscape(item.notes))\n"
        }

        return writeToTempFile(csv, filename: "ReceiptFolder_Export.csv")
    }

    private static func exportAsJSON(_ items: [Snapshot]) -> URL? {
        // Single formatter for the whole export — allocating per-item is
        // wasteful when a user has hundreds or thousands of receipts.
        let iso = ISO8601DateFormatter()
        let exportItems = items.map { item -> [String: Any] in
            var dict: [String: Any] = [
                "productName": item.productName,
                "storeName": item.storeName,
                "purchaseDate": iso.string(from: item.purchaseDate),
                "priceCents": item.priceCents,
                "formattedPrice": item.formattedPrice,
                "isReturned": item.isReturned,
                "isArchived": item.isArchived,
                "isGift": item.isGift,
                "notes": item.notes
            ]
            if let returnEnd = item.returnWindowEndDate {
                dict["returnWindowEndDate"] = iso.string(from: returnEnd)
                if let d = item.returnDaysRemaining { dict["returnDaysRemaining"] = d }
            }
            if let warrantyEnd = item.warrantyEndDate {
                dict["warrantyEndDate"] = iso.string(from: warrantyEnd)
                if let d = item.warrantyDaysRemaining { dict["warrantyDaysRemaining"] = d }
            }
            if !item.returnPolicyDescription.isEmpty {
                dict["returnPolicy"] = item.returnPolicyDescription
            }
            if !item.returnRequirements.isEmpty {
                dict["returnRequirements"] = item.returnRequirements
            }
            return dict
        }

        let export: [String: Any] = [
            "exportDate": iso.string(from: .now),
            "appVersion": "1.0",
            "itemCount": items.count,
            "items": exportItems
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: export, options: [.prettyPrinted, .sortedKeys]) else {
            return nil
        }

        return writeToTempFile(String(data: data, encoding: .utf8) ?? "", filename: "ReceiptFolder_Export.json")
    }

    private static func csvEscape(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func writeToTempFile(_ content: String, filename: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }
}

private extension ExportService.Snapshot {
    @MainActor
    init(from item: ReceiptItem) {
        self.productName = item.productName
        self.storeName = item.storeName
        self.purchaseDate = item.purchaseDate
        self.priceCents = item.priceCents
        self.formattedPrice = item.formattedPrice
        self.returnWindowEndDate = item.returnWindowEndDate
        self.returnDaysRemaining = item.returnDaysRemaining
        self.warrantyEndDate = item.warrantyEndDate
        self.warrantyDaysRemaining = item.warrantyDaysRemaining
        self.returnPolicyDescription = item.returnPolicyDescription
        self.returnRequirements = item.returnRequirements
        self.isReturned = item.isReturned
        self.isArchived = item.isArchived
        self.isGift = item.isGift
        self.isReturnWindowOpen = item.isReturnWindowOpen
        self.notes = item.notes
    }
}
