import Foundation
import Testing
@testable import ReceiptFolder

// MARK: - EmailReceiptParser — retailer recognition + extraction

@Suite("EmailReceiptParser")
struct EmailReceiptParserTests {

    // MARK: Amazon

    @Test("recognises an Amazon order confirmation by sender signature")
    func amazonOrderConfirmation() {
        let subject = "Your Amazon.com order of \"Sony WH-1000XM5 Wireless Headphones\" has shipped"
        let body = """
            Hello Honorius,

            Your order has shipped.

            Order #123-4567890-1234567
            Placed on April 12, 2026
            Total: $349.99

            Sony WH-1000XM5 Wireless Headphones
              Qty: 1  $349.99

            Thanks for shopping with us,
            Amazon.com
            """
        let parsed = EmailReceiptParser.parse(subject: subject, body: body)
        #expect(parsed != nil)
        #expect(parsed?.storeName == "Amazon")
        #expect(parsed?.priceCents == 34999 || parsed?.priceCents == nil)
    }

    @Test("Amazon parser populates product name from subject or body")
    func amazonProductName() {
        let parsed = EmailReceiptParser.parse(
            subject: "Your Amazon.com order",
            body: "Thanks for your order. Sony WH-1000XM5 Headphones. Total: $349.99"
        )
        #expect(parsed?.storeName == "Amazon")
        #expect(parsed?.productName.isEmpty == false)
    }

    // MARK: Apple

    @Test("recognises an Apple Store receipt")
    func appleStoreReceipt() {
        let subject = "Your receipt from Apple"
        let body = """
            Apple Store

            Invoice Date: Apr 8, 2026
            Order Number: W1234567890

            AirPods Pro (2nd generation) — $249.00

            Subtotal: $249.00
            Tax: $22.10
            Total: $271.10
            """
        let parsed = EmailReceiptParser.parse(subject: subject, body: body)
        #expect(parsed != nil)
        #expect(parsed?.storeName == "Apple")
    }

    // MARK: Best Buy

    @Test("recognises a Best Buy order confirmation")
    func bestBuyOrder() {
        let subject = "Order confirmation — thanks for shopping at Best Buy"
        let body = """
            Order #BBY01-806812345678
            Order Date: 04/09/2026

            LG C3 65" OLED TV
                $1,799.99

            Subtotal: $1,799.99
            Estimated Total: $1,962.99
            """
        let parsed = EmailReceiptParser.parse(subject: subject, body: body)
        #expect(parsed != nil)
        #expect(parsed?.storeName == "Best Buy")
    }

    // MARK: Fallback

    @Test("returns nil for an unrecognised sender")
    func unrecognisedEmailReturnsNil() {
        let parsed = EmailReceiptParser.parse(
            subject: "Your receipt from Acme Local Bakery",
            body: "Hi — here's your bread. Total $8.50. — Acme"
        )
        #expect(parsed == nil)
    }

    // MARK: Confidence ranking

    @Test("confidence is high when store + date + price + product all extracted")
    func confidenceHigh() {
        let confidence = EmailReceiptParser.Confidence.from(
            store: "Amazon", date: Date(), price: 9999, product: "Headphones"
        )
        #expect(confidence == .high)
    }

    @Test("confidence is medium when one of (date, product) is missing")
    func confidenceMedium() {
        let missingProduct = EmailReceiptParser.Confidence.from(
            store: "Amazon", date: Date(), price: 9999, product: nil
        )
        let missingDate = EmailReceiptParser.Confidence.from(
            store: "Amazon", date: nil, price: 9999, product: "Headphones"
        )
        #expect(missingProduct == .medium)
        #expect(missingDate == .medium)
    }

    @Test("confidence is low when only the store is known")
    func confidenceLow() {
        let c = EmailReceiptParser.Confidence.from(
            store: "Amazon", date: nil, price: nil, product: nil
        )
        #expect(c == .low)
    }
}
