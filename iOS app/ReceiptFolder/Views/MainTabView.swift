import CoreSpotlight
import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: RFTab = .vault
    @State private var showingAddItem = false

    private let navigationState = NavigationState.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .vault:
                    VaultListView(showingAddItem: $showingAddItem)
                case .expiring:
                    ExpiringDashboardView()
                case .insights:
                    InsightsView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            RFTabBar(selectedTab: $selectedTab) {
                showingAddItem = true
            }
        }
        .background(RFColors.paper)
        .sheet(isPresented: $showingAddItem) {
            AddItemView()
        }
        .onChange(of: navigationState.selectedTab) { _, newTab in
            if let tab = newTab {
                selectedTab = tab
                navigationState.selectedTab = nil
            }
        }
        .onChange(of: navigationState.showAddItem) { _, show in
            if show {
                showingAddItem = true
                navigationState.showAddItem = false
            }
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard let idString = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                  let itemID = UUID(uuidString: idString) else { return }
            selectedTab = .vault
            navigationState.pendingItemID = itemID
        }
    }
}
