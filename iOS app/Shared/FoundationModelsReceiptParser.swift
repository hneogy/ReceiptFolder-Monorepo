import Foundation

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Foundation Models fallback (iOS 26+)
//
// When `EmailReceiptParser` doesn't recognise the sender (retailer outside
// our templated set), this parser hands the subject + body to Apple's
// on-device language model and asks it to extract structured receipt
// fields. Runs entirely on-device; no prompt or response leaves the phone.
//
// Gated behind `#if canImport(FoundationModels)` so the shared target
// still builds for iOS 17 / macOS 14. Runtime-gated behind
// `#available(iOS 26.0, *)` so the framework is only loaded where the
// system has it.

@available(iOS 26.0, macOS 26.0, *)
enum FoundationModelsReceiptParser {

    /// Structured output the LLM is asked to generate. `@Generable` tells
    /// Foundation Models the shape of the JSON it should emit; `@Guide`
    /// annotations are injected into the prompt as extraction hints.
    @Generable
    struct LLMOutput {
        @Guide(description: "The retailer, store, or merchant name. Empty string if unclear.")
        let storeName: String

        @Guide(description: "The single most prominent product name. If the email lists several items, pick the first or most expensive. Empty string if unclear.")
        let productName: String

        @Guide(description: "The purchase or order date in ISO 8601 format (e.g. 2026-04-12). Empty string if unclear.")
        let purchaseDateISO: String

        @Guide(description: "The total price in cents as an integer. $349.99 becomes 34999. Zero if unclear.")
        let priceCents: Int
    }

    /// Attempts to extract receipt fields from an arbitrary email via the
    /// on-device language model. Returns `nil` when the model is
    /// unavailable (no Apple Intelligence, device unsupported, user
    /// disabled the feature, network-required prompts, etc.), or when
    /// extraction fails validation.
    static func tryParse(subject: String, body: String) async -> EmailReceiptParser.ParsedReceipt? {
        // Short-circuit if the system model isn't ready. Availability can
        // be: .available, .unavailable(.deviceNotEligible | .appleIntelligenceNotEnabled | .modelNotReady).
        guard case .available = SystemLanguageModel.default.availability else {
            return nil
        }

        // Cap the prompt size. Email HTML can be huge (headers, styles,
        // boilerplate footers). A 4 KB body is more than enough signal for
        // receipt extraction and keeps inference fast.
        let trimmedBody = String(body.prefix(4000))
        let prompt = """
            You are extracting receipt data from a single email. Return only
            the structured output described by the schema. If a field is
            unclear or missing, leave the string empty or the number zero —
            do not guess.

            SUBJECT:
            \(subject)

            BODY:
            \(trimmedBody)
            """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt, generating: LLMOutput.self)
            return adapt(output: response.content, subject: subject, body: body)
        } catch {
            // Any model failure — falls back to nil so the UI can prompt
            // the user to enter fields by hand.
            return nil
        }
    }

    /// Converts the LLM's raw output into the existing `ParsedReceipt`
    /// shape, applying light validation: blank store = reject, price of
    /// zero = treat as missing, unparseable date = treat as missing. The
    /// confidence stamp reflects how many fields survived.
    private static func adapt(
        output: LLMOutput,
        subject: String,
        body: String
    ) -> EmailReceiptParser.ParsedReceipt? {
        let store = output.storeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !store.isEmpty else { return nil }

        let product = output.productName.trimmingCharacters(in: .whitespacesAndNewlines)
        let productOrNil = product.isEmpty ? nil : product

        let date = ISO8601DateFormatter.receipt.date(from: output.purchaseDateISO)
        let price = output.priceCents > 0 ? output.priceCents : nil

        let confidence = EmailReceiptParser.Confidence.from(
            store: store, date: date, price: price, product: productOrNil
        )

        return EmailReceiptParser.ParsedReceipt(
            storeName: store,
            productName: product,
            purchaseDate: date,
            priceCents: price,
            // AI-sourced parses always cap at medium — we don't want to
            // surface "high confidence" from a model that guessed.
            confidence: confidence == .high ? .medium : confidence,
            rawTextUsed: subject + "\n" + body
        )
    }
}

private extension ISO8601DateFormatter {
    /// Date-only ISO 8601 formatter. The LLM is prompted to emit
    /// `2026-04-12`-style dates, not full datetimes.
    static let receipt: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return f
    }()
}

#endif
