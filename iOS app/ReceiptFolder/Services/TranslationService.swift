import Foundation
import Translation

@available(iOS 18.0, *)
@MainActor
final class TranslationService {
    static let shared = TranslationService()

    private init() {}

    /// Detects if text is in a non-English language and provides a translation configuration.
    /// Returns nil if the text is already English or translation isn't available.
    func translationConfiguration(for text: String) -> TranslationSession.Configuration? {
        // Simple heuristic: check if text contains non-ASCII characters commonly found in
        // non-English receipts (CJK, Cyrillic, Arabic, accented characters beyond basic Latin)
        let nonEnglishRatio = nonEnglishCharacterRatio(text)

        guard nonEnglishRatio > 0.15 else { return nil }

        // Request translation to English
        return TranslationSession.Configuration(target: .init(identifier: "en"))
    }

    private func nonEnglishCharacterRatio(_ text: String) -> Double {
        let total = text.unicodeScalars.count
        guard total > 0 else { return 0 }

        let nonBasicLatin = text.unicodeScalars.filter { scalar in
            // Basic Latin + Latin-1 Supplement (common in English)
            !(scalar.value >= 0x0020 && scalar.value <= 0x007E) &&
            !(scalar.value >= 0x00C0 && scalar.value <= 0x00FF) &&
            !scalar.properties.isWhitespace &&
            scalar.value != 0x000A // newline
        }.count

        return Double(nonBasicLatin) / Double(total)
    }
}
