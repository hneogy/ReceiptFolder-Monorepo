import Foundation
import NaturalLanguage

enum DataDetectionService {
    /// Uses NLTagger and data detectors to extract structured data from OCR text.
    /// More reliable than pure regex for dates and addresses.
    static func extractStructuredData(from text: String) -> DetectedData {
        var data = DetectedData()

        // Use NSDataDetector for dates, addresses, phone numbers
        let types: NSTextCheckingResult.CheckingType = [.date, .address, .phoneNumber]
        let detector: NSDataDetector
        do {
            detector = try NSDataDetector(types: types.rawValue)
        } catch {
            RFLogger.ocr.error("NSDataDetector init failed: \(error.localizedDescription)")
            return data
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, options: [], range: range)

        for match in matches {
            if match.resultType == .date, let date = match.date {
                data.dates.append(date)
            }
            if match.resultType == .address, let components = match.addressComponents {
                let address = formatAddress(components)
                if !address.isEmpty {
                    data.addresses.append(address)
                }
            }
            if match.resultType == .phoneNumber, let phone = match.phoneNumber {
                data.phoneNumbers.append(phone)
            }
        }

        // Pick the most likely purchase date (closest to today, but not in the future)
        data.bestDate = data.dates
            .filter { $0 <= .now }
            .sorted { abs($0.timeIntervalSinceNow) < abs($1.timeIntervalSinceNow) }
            .first

        // Pick the first address (usually the store address on a receipt)
        data.bestAddress = data.addresses.first

        return data
    }

    private static func formatAddress(_ components: [NSTextCheckingKey: String]) -> String {
        var parts: [String] = []
        if let street = components[.street] { parts.append(street) }
        if let city = components[.city] { parts.append(city) }
        if let state = components[.state] { parts.append(state) }
        if let zip = components[.zip] { parts.append(zip) }
        return parts.joined(separator: ", ")
    }
}

struct DetectedData {
    var dates: [Date] = []
    var addresses: [String] = []
    var phoneNumbers: [String] = []
    var bestDate: Date?
    var bestAddress: String?
}
