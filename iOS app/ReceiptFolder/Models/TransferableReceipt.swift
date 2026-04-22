import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

/// Makes receipt items draggable and droppable.
/// Supports dropping images into the app to create new receipts.
struct TransferableReceiptImage: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        // `.image` is the umbrella UTI — covers jpeg, png, heic, and other
        // raster image types. The previous three-rep setup duplicated work
        // and caused drag providers to offer the same representation thrice.
        DataRepresentation(importedContentType: .image) { data in
            guard let image = UIImage(data: data) else {
                throw TransferError.invalidImage
            }
            return TransferableReceiptImage(image: image)
        }
    }
}

/// Exportable receipt summary for sharing via drag.
struct TransferableReceiptSummary: Transferable, Codable {
    let productName: String
    let storeName: String
    let purchaseDate: Date
    let priceCents: Int
    let returnDaysRemaining: Int?
    let warrantyDaysRemaining: Int?

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)

        ProxyRepresentation(exporting: \.shareText)
    }

    var shareText: String {
        var text = "\(productName) — \(storeName)\n"
        text += "Purchased: \(purchaseDate.formatted(date: .long, time: .omitted))\n"
        if priceCents > 0 {
            text += "Price: \((Double(priceCents) / 100.0).formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))\n"
        }
        if let days = returnDaysRemaining {
            text += "Return window: \(days) days remaining\n"
        }
        if let days = warrantyDaysRemaining {
            text += "Warranty: \(days) days remaining\n"
        }
        return text
    }
}

enum TransferError: Error {
    case invalidImage
}
