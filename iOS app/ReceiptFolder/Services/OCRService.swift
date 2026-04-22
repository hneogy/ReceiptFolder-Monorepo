import Foundation
import Vision
import UIKit

struct OCRResult {
    var storeName: String?
    var purchaseDate: Date?
    var totalAmount: Int?  // cents
    var rawText: String
    var storeAddress: String?
}

enum OCRService {
    static func extractText(from image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        // Enhance image with CoreImage before OCR for better accuracy
        let enhanced = ReceiptImageEnhancer.enhance(image)
        let ocrImage = enhanced.cgImage ?? cgImage

        // Respect the original orientation so sideways/upside-down camera
        // captures are read right-side up by Vision.
        let orientation = Self.cgOrientation(from: image.imageOrientation)

        // Haptic feedback — scanning started
        await MainActor.run { HapticsService.shared.playScanning() }

        let rawText = try await recognizeText(in: ocrImage, orientation: orientation)

        // Use DataDetection for smarter date/address extraction
        let detectedData = DataDetectionService.extractStructuredData(from: rawText)

        let storeName = extractStoreName(from: rawText)
        let purchaseDate = detectedData.bestDate ?? extractDate(from: rawText)
        let totalAmount = extractTotal(from: rawText)
        let storeAddress = detectedData.bestAddress

        // Haptic feedback — scan complete
        await MainActor.run { HapticsService.shared.playSuccess() }

        return OCRResult(
            storeName: storeName,
            purchaseDate: purchaseDate,
            totalAmount: totalAmount,
            rawText: rawText,
            storeAddress: storeAddress
        )
    }

    private static func recognizeText(in image: CGImage, orientation: CGImagePropertyOrientation) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false

            let request = VNRecognizeTextRequest { request, error in
                guard !hasResumed else { return }
                hasResumed = true

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            // Support multiple languages for foreign receipts
            request.recognitionLanguages = ["en-US", "es", "fr", "de", "it", "pt", "ja", "zh-Hans", "ko"]

            let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
            do {
                try handler.perform([request])
            } catch {
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(throwing: error)
            }
        }
    }

    private static func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch uiOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    private static func extractStoreName(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines.prefix(3) {
            if line.range(of: #"^\d{3}[-.]?\d{3}[-.]?\d{4}$"#, options: .regularExpression) != nil { continue }
            if line.range(of: #"^\d+\s+\w+\s+(St|Ave|Blvd|Dr|Rd|Ln)"#, options: .regularExpression) != nil { continue }
            if line.count >= 2 {
                return line
            }
        }

        return lines.first
    }

    private static func extractDate(from text: String) -> Date? {
        let datePatterns: [(pattern: String, format: String)] = [
            (#"\b(\d{1,2}/\d{1,2}/\d{4})\b"#, "MM/dd/yyyy"),
            (#"\b(\d{1,2}/\d{1,2}/\d{2})\b"#, "MM/dd/yy"),
            (#"\b(\d{1,2}-\d{1,2}-\d{4})\b"#, "MM-dd-yyyy"),
            (#"\b(\d{1,2}-\d{1,2}-\d{2})\b"#, "MM-dd-yy"),
        ]

        for (pattern, format) in datePatterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let dateString = String(text[match])
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: "en_US_POSIX")
                if let date = formatter.date(from: dateString) {
                    guard date <= Date.now else { return nil }
                    return date
                }
            }
        }

        return nil
    }

    private static func extractTotal(from text: String) -> Int? {
        let lines = text.components(separatedBy: .newlines)

        for line in lines.reversed() {
            let lower = line.lowercased()
            if lower.contains("total") && !lower.contains("subtotal") && !lower.contains("sub total") {
                if let amount = extractDollarAmount(from: line) {
                    return amount
                }
            }
        }

        for line in lines.reversed() {
            if let amount = extractDollarAmount(from: line) {
                return amount
            }
        }

        return nil
    }

    private static func extractDollarAmount(from text: String) -> Int? {
        // Accept common currency symbols (USD/EUR/GBP/JPY/INR/etc), optional
        // grouping separators, up to 10 digits before the decimal. Handles
        // both US "1,234.56" and EU "1.234,56" by stripping all separators
        // and treating the last one as the decimal point.
        let pattern = #"[$€£¥₹₩฿]?\s*(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})|\d{1,10}[.,]\d{2})"#
        guard let match = text.range(of: pattern, options: .regularExpression) else { return nil }
        let raw = String(text[match])
            .replacingOccurrences(of: #"[$€£¥₹₩฿\s]"#, with: "", options: .regularExpression)

        guard let lastSeparator = raw.lastIndex(where: { $0 == "." || $0 == "," }) else {
            return nil
        }
        let integerPart = raw[..<lastSeparator]
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
        let fractionalPart = raw[raw.index(after: lastSeparator)...]

        guard let dollars = Double("\(integerPart).\(fractionalPart)") else { return nil }
        return Int((dollars * 100).rounded())
    }
}

enum OCRError: Error, LocalizedError {
    case invalidImage
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: "Could not process the image."
        case .recognitionFailed: "Text recognition failed."
        }
    }
}
