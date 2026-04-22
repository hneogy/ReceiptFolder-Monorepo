# Receipt Folder

iOS app that tracks return windows and warranties from receipt photos.

## Build

```bash
xcodegen generate
xcodebuild -scheme ReceiptFolder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -scheme ReceiptFolderWidget -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Architecture

- **SwiftUI + SwiftData** — iOS 17+ deployment target
- **MVVM** — `@MainActor @Observable` for state, services as `@MainActor` singletons with `static let shared`
- **Single flat `@Model`** — `ReceiptItem` is the only SwiftData entity (no relationships)
- **No server** — store policies bundled as JSON, OCR via Vision, everything local
- **Images on disk** — relative paths stored in model, files in `documents/receipts/` and `documents/items/`
- **Widget data** — shared via App Group UserDefaults (`group.com.receiptfolder.app`)

## Framework Integrations

| Framework | Usage |
|-----------|-------|
| **ActivityKit** | Live Activities on lock screen when return deadline ≤3 days |
| **AppIntents** | Siri shortcuts: "Show expiring items", "Add receipt", "Check return window" |
| **CoreSpotlight** | System-wide search indexing of all receipt items |
| **TipKit** | Contextual onboarding tips (scan, return mode, widget, gift mode, calendar) |
| **BackgroundTasks** | BGAppRefreshTask to update widget data every 6 hours |
| **Charts** | Insights tab: monthly spending, store breakdown (pie), return stats, warranty coverage |
| **LocalAuthentication** | Optional Face ID / Touch ID app lock |
| **EventKit** | Add return deadlines and warranty expiry to user's Calendar |
| **DataDetection** | NSDataDetector for dates, addresses, phone numbers from OCR text |
| **CoreImage** | Auto-enhance receipt photos (contrast, sharpen, grayscale, noise reduction) before OCR |
| **CoreHaptics** | Success/urgency/scanning/error haptic patterns |
| **Translation** | Foreign receipt language detection + translation (iOS 18+) |
| **FoundationModels** | On-device LLM receipt parsing (iOS 26+, `#if canImport`) |
| **MessageUI** | Email receipt details with photo attachment |
| **CoreTransferable** | Drag & drop receipt images into add flow, drag summaries out |
| **Compression** | LZFSE compression + adaptive JPEG quality for receipt images |
| **Accessibility** | VoiceOver labels, Dynamic Type, combined accessibility elements, color+text urgency |

## Key Files

- `ReceiptFolder/Models/ReceiptItem.swift` — the core SwiftData model
- `ReceiptFolder/Resources/StorePolicies.json` — 50 retailer return policies
- `ReceiptFolder/Services/StorePolicyService.swift` — loads and fuzzy-matches store policies
- `ReceiptFolder/Services/OCRService.swift` — Vision framework + CoreImage enhancement + DataDetection
- `ReceiptFolder/Services/NotificationScheduler.swift` — urgency-based local notifications
- `ReceiptFolder/Services/LiveActivityManager.swift` — ActivityKit Live Activities
- `ReceiptFolder/Services/SpotlightIndexer.swift` — CoreSpotlight indexing
- `ReceiptFolder/Services/CalendarService.swift` — EventKit calendar integration
- `ReceiptFolder/Services/BiometricAuthService.swift` — Face ID / Touch ID lock
- `ReceiptFolder/Services/ReceiptImageEnhancer.swift` — CoreImage receipt photo enhancement
- `ReceiptFolder/Services/HapticsService.swift` — CoreHaptics patterns
- `ReceiptFolder/Views/InsightsView.swift` — Charts spending analytics

## Urgency Levels

| Level | Return Window | Color | Notifications |
|-------|--------------|-------|---------------|
| Critical | ≤ 3 days | Red | 72h, 24h, morning-of + Live Activity |
| Warning | 4–14 days | Amber | 14d, 7d |
| Warranty Expiring | ≤ 90 days | Green | 90d, 30d, 7d |
| Active | > 14 days | Green | None |
