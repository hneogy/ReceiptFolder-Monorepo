import SwiftUI

/// Shared navigation state used by Siri shortcuts, Spotlight deep links,
/// and notification taps to drive tab and detail navigation.
@MainActor @Observable
final class NavigationState {
    static let shared = NavigationState()

    /// Tab to switch to. Consumed by MainTabView and cleared.
    var selectedTab: RFTab?

    /// Whether to present the add-item sheet. Consumed by MainTabView and cleared.
    var showAddItem = false

    /// Item to deep-link into. Consumed by VaultListView which pushes the detail view.
    var pendingItemID: UUID?

    private init() {}
}
