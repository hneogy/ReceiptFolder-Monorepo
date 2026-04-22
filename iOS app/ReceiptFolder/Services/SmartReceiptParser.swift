import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// Uses on-device Foundation Models (iOS 26+) for intelligent receipt parsing.
/// Falls back to regex-based OCR extraction on older OS versions.
@available(iOS 26.0, *)
enum SmartReceiptParser {
    struct ParsedReceipt: Codable {
        let storeName: String?
        let purchaseDate: String?
        let items: [ParsedItem]
        let totalAmount: String?
        let storeAddress: String?
        let paymentMethod: String?
    }

    struct ParsedItem: Codable {
        let name: String
        let price: String?
        let quantity: Int?
    }

    static func parse(ocrText: String) async throws -> ParsedReceipt {
        let session = LanguageModelSession()

        let prompt = """
        Extract structured data from this receipt text. Return JSON with these fields:
        - storeName: the store/business name
        - purchaseDate: the date in YYYY-MM-DD format
        - items: array of {name, price, quantity}
        - totalAmount: the total in format "XX.XX"
        - storeAddress: the store address if visible
        - paymentMethod: credit card type or payment method if visible

        Receipt text:
        \(ocrText)
        """

        let response = try await session.respond(to: prompt)
        let responseText = response.content

        // Try to extract JSON from the response
        if let jsonData = extractJSON(from: responseText) {
            return try JSONDecoder().decode(ParsedReceipt.self, from: jsonData)
        }

        // Fallback: return empty
        return ParsedReceipt(
            storeName: nil,
            purchaseDate: nil,
            items: [],
            totalAmount: nil,
            storeAddress: nil,
            paymentMethod: nil
        )
    }

    /// Finds the first complete, balanced JSON object in the LLM response.
    /// Tolerates explanatory prose before or after the object and nested
    /// structures — a simple first-to-last-brace strategy would include any
    /// trailing prose or cut off at the innermost brace in a nested structure.
    private static func extractJSON(from text: String) -> Data? {
        let chars = Array(text)
        guard let startIdx = chars.firstIndex(of: "{") else { return nil }

        var depth = 0
        var inString = false
        var escape = false

        for i in startIdx..<chars.count {
            let c = chars[i]
            if escape { escape = false; continue }
            if c == "\\" { escape = true; continue }
            if c == "\"" { inString.toggle(); continue }
            if inString { continue }

            if c == "{" { depth += 1 }
            else if c == "}" {
                depth -= 1
                if depth == 0 {
                    let jsonString = String(chars[startIdx...i])
                    return jsonString.data(using: .utf8)
                }
            }
        }
        return nil
    }
}
#endif
