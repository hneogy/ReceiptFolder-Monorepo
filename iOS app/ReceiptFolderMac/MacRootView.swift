import SwiftUI
import SwiftData

/// Sidebar-detail layout using `NavigationSplitView` — the macOS-native
/// pattern. The sidebar holds the four conceptual tabs from iOS; the
/// detail side shows whatever view the selected tab renders.
struct MacRootView: View {
    enum SidebarItem: Hashable { case vault, expiring, insights, settings }

    @State private var selection: SidebarItem? = .vault
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(MacColors.paper(scheme))
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            Section {
                sidebarRow(.vault,    label: "Vault",    icon: "tray.full")
                sidebarRow(.expiring, label: "Expiring", icon: "clock")
                sidebarRow(.insights, label: "Insights", icon: "chart.bar")
                sidebarRow(.settings, label: "Settings", icon: "gearshape")
            } header: {
                Text("RECEIPT · FOLDER")
                    .font(MacFont.mono(10))
                    .tracking(1.6)
                    .foregroundStyle(MacColors.mute(scheme))
                    .padding(.top, 8)
            }
        }
        .listStyle(.sidebar)
    }

    private func sidebarRow(_ section: SidebarItem, label: String, icon: String) -> some View {
        Label {
            Text(label).font(MacFont.serifBody(15))
        } icon: {
            Image(systemName: icon)
        }
        .tag(section)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .vault, .none:
            MacVaultView()
        case .expiring:
            MacExpiringView()
        case .insights:
            MacPlaceholderView(
                title: "Insights",
                caption: "Spending analytics and return stats. Coming to macOS soon."
            )
        case .settings:
            MacSettingsView()
        }
    }
}
