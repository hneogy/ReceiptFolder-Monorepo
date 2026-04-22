import Foundation

/// Parses digital-receipt emails from major retailers into a structured
/// `ParsedReceipt` ready to hand to the UI. Runs entirely on-device — the
/// input string is the email body the Share Extension received from Mail.
///
/// Coverage (as of ship):
///   - Amazon (order confirmation, shipment notification)
///   - Apple (Apple Store / App Store receipt)
///   - Best Buy (order confirmation)
///
/// Parsers are pure functions. Each retailer has a signature predicate
/// (does this email belong to us?) and an extraction routine. Add a new
/// retailer by appending to `parsers` — no other change needed.
enum EmailReceiptParser {

    // MARK: - Public API

    struct ParsedReceipt: Equatable {
        var storeName: String
        var productName: String
        var purchaseDate: Date?
        var priceCents: Int?
        var confidence: Confidence
        var rawTextUsed: String
    }

    enum Confidence: Equatable {
        case high     // store + date + price + product all extracted
        case medium   // store + price, missing one of date or product
        case low      // store only — everything else is guessed or missing

        static func from(store: String?, date: Date?, price: Int?, product: String?) -> Confidence {
            let fields = [store != nil, date != nil, price != nil, product != nil]
            let count = fields.filter { $0 }.count
            if count == 4 { return .high }
            if count == 3 { return .medium }
            return .low
        }
    }

    /// Tries each registered retailer parser against the email content.
    /// Returns `nil` if no parser recognises the email. Synchronous,
    /// template-only — used in tests and fast paths.
    static func parse(subject: String, body: String) -> ParsedReceipt? {
        let context = EmailContext(subject: subject, body: body)
        for parser in parsers {
            if parser.matches(context) {
                return parser.extract(context)
            }
        }
        return nil
    }

    /// Async entry point used by the Share Extension. First tries the
    /// templated retailer parsers (fast, deterministic). If no template
    /// matches and the device supports Apple Intelligence (iOS 26+), falls
    /// through to `FoundationModelsReceiptParser` for an on-device LLM
    /// extraction. Returns `nil` only when both paths fail — in which case
    /// the UI should prompt the user to enter fields by hand.
    static func parseWithAIFallback(subject: String, body: String) async -> ParsedReceipt? {
        if let templated = parse(subject: subject, body: body) {
            return templated
        }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return await FoundationModelsReceiptParser.tryParse(subject: subject, body: body)
        }
        #endif
        return nil
    }

    // MARK: - Registered parsers

    private static let parsers: [RetailerParser] = [
        AmazonParser(),
        AppleParser(),
        BestBuyParser()
    ]
}

// MARK: - Parser protocol

private struct EmailContext {
    let subject: String
    let body: String
    var combined: String { subject + "\n" + body }
    var lowercased: String { combined.lowercased() }
}

private protocol RetailerParser {
    var storeName: String { get }
    func matches(_ context: EmailContext) -> Bool
    func extract(_ context: EmailContext) -> EmailReceiptParser.ParsedReceipt
}

// MARK: - Shared extraction helpers

private enum Extract {
    /// Money amount matchers — US-format `$XX.XX` with optional grouping.
    /// Returns cents.
    static func firstDollarAmount(in text: String, afterKeyword keyword: String? = nil) -> Int? {
        let target: String
        if let keyword,
           let range = text.range(of: keyword, options: [.caseInsensitive]) {
            target = String(text[range.upperBound...])
        } else {
            target = text
        }
        let pattern = #"\$\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})|\d+\.\d{2})"#
        guard let match = target.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        let raw = String(target[match])
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let dollars = Double(raw) else { return nil }
        return Int((dollars * 100).rounded())
    }

    /// Finds the highest-confidence date in the email body, preferring dates
    /// that appear near "order date", "purchased", "shipped", or similar.
    static func firstDate(in text: String) -> Date? {
        let types = NSTextCheckingResult.CheckingType.date.rawValue
        guard let detector = try? NSDataDetector(types: types) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, options: [], range: range)
        let now = Date.now
        // Prefer the most recent past date — emails sometimes contain expiry
        // or future-delivery dates we don't want.
        return matches
            .compactMap { $0.date }
            .filter { $0 <= now }
            .sorted { abs($0.timeIntervalSinceNow) < abs($1.timeIntervalSinceNow) }
            .first
    }

    /// Strips HTML tags, collapses whitespace, and HTML-unescapes the output.
    static func plainText(from html: String) -> String {
        let stripped = html.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: " ",
            options: .regularExpression
        )
        let unescaped = stripped
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
        return unescaped
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Amazon

private struct AmazonParser: RetailerParser {
    let storeName = "Amazon"

    func matches(_ context: EmailContext) -> Bool {
        // Amazon order confirmations reliably contain either "amazon.com"
        // in the body/header or one of these subject patterns.
        let s = context.lowercased
        return s.contains("amazon.com")
            || s.contains("your amazon order")
            || s.contains("your order of")
            || s.contains("amazon.com order")
    }

    func extract(_ context: EmailContext) -> EmailReceiptParser.ParsedReceipt {
        let plain = Extract.plainText(from: context.body)

        // Product: Amazon subjects often look like "Your Amazon.com order of
        // 'Sony WH-1000XM5' has shipped." or "Your Amazon.com order #123..."
        let product = extractProduct(from: context.subject, fallback: plain)

        // Total: Amazon emails have "Order Total: $123.45" or "Total: $123.45"
        let price = Extract.firstDollarAmount(in: plain, afterKeyword: "Order Total:")
            ?? Extract.firstDollarAmount(in: plain, afterKeyword: "Grand Total:")
            ?? Extract.firstDollarAmount(in: plain, afterKeyword: "Total:")

        let date = Extract.firstDate(in: plain)

        return EmailReceiptParser.ParsedReceipt(
            storeName: storeName,
            productName: product ?? "Amazon purchase",
            purchaseDate: date,
            priceCents: price,
            confidence: EmailReceiptParser.Confidence.from(
                store: storeName, date: date, price: price, product: product
            ),
            rawTextUsed: plain
        )
    }

    private func extractProduct(from subject: String, fallback: String) -> String? {
        // "Your Amazon.com order of 'Thing' has..."
        let quotedPattern = #"(?:order of |:)\s*[""'"]([^""'""]{3,120})[""'""]"#
        if let match = subject.range(of: quotedPattern, options: .regularExpression) {
            let captured = String(subject[match])
                .replacingOccurrences(of: #"^.*?[""'""]"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"[""'""].*$"#, with: "", options: .regularExpression)
            if !captured.isEmpty { return captured.trimmingCharacters(in: .whitespaces) }
        }
        // Falls back to first non-empty short line of the plaintext body.
        for line in fallback.split(separator: "\n").map({ String($0).trimmingCharacters(in: .whitespaces) }) {
            if line.count >= 8, line.count <= 120, !line.lowercased().contains("amazon") {
                return line
            }
        }
        return nil
    }
}

// MARK: - Apple

private struct AppleParser: RetailerParser {
    let storeName = "Apple"

    func matches(_ context: EmailContext) -> Bool {
        let s = context.lowercased
        return s.contains("your receipt from apple")
            || s.contains("apple.com/receipt")
            || s.contains("apple store")
            || (s.contains("apple") && s.contains("order confirmation"))
    }

    func extract(_ context: EmailContext) -> EmailReceiptParser.ParsedReceipt {
        let plain = Extract.plainText(from: context.body)

        // Apple receipts: "Order Total $XX.XX"
        let price = Extract.firstDollarAmount(in: plain, afterKeyword: "Order Total")
            ?? Extract.firstDollarAmount(in: plain, afterKeyword: "Total")

        // Apple emails include "Invoice Date" or "Order Date"
        let date = Extract.firstDate(in: plain)

        // Product: the first non-boilerplate line after the header.
        // Apple emails lead with the user's name, then the product line.
        let product = extractFirstProductLine(plain)

        return EmailReceiptParser.ParsedReceipt(
            storeName: storeName,
            productName: product ?? "Apple purchase",
            purchaseDate: date,
            priceCents: price,
            confidence: EmailReceiptParser.Confidence.from(
                store: storeName, date: date, price: price, product: product
            ),
            rawTextUsed: plain
        )
    }

    private func extractFirstProductLine(_ text: String) -> String? {
        let skipWords: Set<String> = [
            "apple", "receipt", "invoice", "order", "total", "subtotal",
            "tax", "shipping", "billing", "address", "dear", "hello", "hi"
        ]
        for raw in text.split(separator: "\n") {
            let line = String(raw).trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.count >= 8, line.count <= 120 else { continue }
            let first = line.lowercased().split(separator: " ").first.map(String.init) ?? ""
            if !skipWords.contains(first) { return line }
        }
        return nil
    }
}

// MARK: - Best Buy

private struct BestBuyParser: RetailerParser {
    let storeName = "Best Buy"

    func matches(_ context: EmailContext) -> Bool {
        let s = context.lowercased
        return s.contains("bestbuy.com")
            || s.contains("best buy")
            || s.contains("bestbuy")
    }

    func extract(_ context: EmailContext) -> EmailReceiptParser.ParsedReceipt {
        let plain = Extract.plainText(from: context.body)

        let price = Extract.firstDollarAmount(in: plain, afterKeyword: "Order Total")
            ?? Extract.firstDollarAmount(in: plain, afterKeyword: "Total")

        let date = Extract.firstDate(in: plain)

        // Best Buy subjects: "Order confirmation: <product>" — extract after colon.
        let product: String?
        if let colonIndex = context.subject.firstIndex(of: ":") {
            let after = context.subject[context.subject.index(after: colonIndex)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            product = after.isEmpty ? nil : after
        } else {
            product = nil
        }

        return EmailReceiptParser.ParsedReceipt(
            storeName: storeName,
            productName: product ?? "Best Buy purchase",
            purchaseDate: date,
            priceCents: price,
            confidence: EmailReceiptParser.Confidence.from(
                store: storeName, date: date, price: price, product: product
            ),
            rawTextUsed: plain
        )
    }
}
