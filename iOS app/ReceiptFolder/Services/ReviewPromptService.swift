import Foundation
import SwiftUI

/// Asks for an App Store rating only when the user is genuinely happy.
///
/// The problem with most review prompts is that they fire too early — before
/// the user has experienced the product's value — which skews ratings toward
/// frustrated, partially-onboarded users. This service gates the prompt on
/// two earned-value signals:
///
///   1. **Age** — the user has had the app for at least 7 days.
///   2. **Action** — the user has marked at least one receipt returned (the
///      moment that demonstrates the entire product loop: add → track → act).
///
/// iOS itself limits review prompts to ~3 per 365-day window per user, so we
/// don't have to worry about nagging — but we still record the last prompt
/// date so we don't re-trigger within a short window of the user dismissing.
@MainActor
enum ReviewPromptService {

    // MARK: - UserDefaults keys
    // Stored in the shared App Group so the widget's mark-returned intent
    // can increment the counter from its own process.
    private enum Key {
        static let firstLaunchDate = "reviewPrompt.firstLaunchDate"
        static let markReturnedCount = "reviewPrompt.markReturnedCount"
        static let lastPromptedDate = "reviewPrompt.lastPromptedDate"
    }

    private static let minimumDaysSinceFirstLaunch = 7
    private static let minimumMarkReturnedCount = 1
    private static let minimumDaysBetweenPrompts = 90

    private static var defaults: UserDefaults {
        AppGroupConstants.sharedDefaults ?? .standard
    }

    // MARK: - Event recording

    /// Record first launch exactly once. Call this early in app startup.
    static func recordFirstLaunchIfNeeded() {
        guard defaults.object(forKey: Key.firstLaunchDate) == nil else { return }
        defaults.set(Date.now, forKey: Key.firstLaunchDate)
    }

    /// Increment the mark-returned counter. Called from every "mark as
    /// returned" path: ItemDetailView menu, VaultListView batch action, and
    /// from the widget's MarkReturnedIntent.
    static func recordMarkReturned() {
        let current = defaults.integer(forKey: Key.markReturnedCount)
        defaults.set(current + 1, forKey: Key.markReturnedCount)
    }

    // MARK: - Prompt gating

    /// Record that the prompt was just shown. Views call this after invoking
    /// SwiftUI's `@Environment(\.requestReview)` action so we respect the
    /// 90-day local cooldown even when iOS's own rate limit hasn't kicked in.
    static func markPromptShown() {
        defaults.set(Date.now, forKey: Key.lastPromptedDate)
    }

    /// Pure gate logic — exposed so views can reason about "is the prompt
    /// imminent?" without firing it.
    static func shouldAsk(now: Date = .now) -> Bool {
        guard let firstLaunch = defaults.object(forKey: Key.firstLaunchDate) as? Date else {
            return false
        }
        let daysSinceFirstLaunch = Calendar.current.dateComponents(
            [.day], from: firstLaunch, to: now
        ).day ?? 0
        guard daysSinceFirstLaunch >= minimumDaysSinceFirstLaunch else { return false }

        guard defaults.integer(forKey: Key.markReturnedCount) >= minimumMarkReturnedCount else {
            return false
        }

        if let lastPrompt = defaults.object(forKey: Key.lastPromptedDate) as? Date {
            let daysSinceLastPrompt = Calendar.current.dateComponents(
                [.day], from: lastPrompt, to: now
            ).day ?? 0
            guard daysSinceLastPrompt >= minimumDaysBetweenPrompts else { return false }
        }

        return true
    }

    // MARK: - Testing hooks

    /// Used by XCUITests to reset state between scenarios.
    static func resetForTesting() {
        defaults.removeObject(forKey: Key.firstLaunchDate)
        defaults.removeObject(forKey: Key.markReturnedCount)
        defaults.removeObject(forKey: Key.lastPromptedDate)
    }
}
