import SwiftUI
import SwiftData

enum VaultSortOption: String, CaseIterable {
    case newest = "Newest First"
    case oldest = "Oldest First"
    case urgency = "Most Urgent"
    case priceHigh = "Price: High to Low"
    case priceLow = "Price: Low to High"
    case storeName = "Store Name"
}

enum VaultFilterType: String, CaseIterable {
    case openReturns = "Open Returns"
    case expiringSoon = "Expiring Soon"
    case returned = "Returned"
    case hasWarranty = "Has Warranty"
}

struct VaultListView: View {
    @Query(
        filter: #Predicate<ReceiptItem> { !$0.isArchived },
        sort: \ReceiptItem.createdAt,
        order: .reverse
    )
    private var items: [ReceiptItem]

    @Environment(\.modelContext) private var modelContext
    @Binding var showingAddItem: Bool
    @State private var searchText = ""
    @State private var sortOption: VaultSortOption = .newest
    @State private var activeFilters: Set<VaultFilterType> = []
    @State private var isEditing = false
    @State private var selectedItems: Set<UUID> = []
    @State private var path = NavigationPath()

    private let navigationState = NavigationState.shared

    // MARK: - Filtered Items

    private var filteredItems: [ReceiptItem] {
        let base: [ReceiptItem]
        if searchText.isEmpty {
            base = items
        } else {
            let query = searchText.lowercased()
            base = items.filter {
                $0.productName.lowercased().contains(query) ||
                $0.storeName.lowercased().contains(query) ||
                $0.notes.lowercased().contains(query) ||
                $0.formattedPrice.lowercased().contains(query)
            }
        }

        let filtered: [ReceiptItem]
        if activeFilters.isEmpty {
            filtered = base
        } else {
            filtered = base.filter { item in
                for filter in activeFilters {
                    switch filter {
                    case .openReturns:
                        if item.isReturnWindowOpen && !item.isReturned { return true }
                    case .expiringSoon:
                        if item.urgencyLevel == .critical || item.urgencyLevel == .warning { return true }
                    case .returned:
                        if item.isReturned { return true }
                    case .hasWarranty:
                        if item.isWarrantyActive { return true }
                    }
                }
                return false
            }
        }

        return filtered.sorted { lhs, rhs in
            switch sortOption {
            case .newest: return lhs.createdAt > rhs.createdAt
            case .oldest: return lhs.createdAt < rhs.createdAt
            case .urgency: return lhs.urgencyLevel < rhs.urgencyLevel
            case .priceHigh: return lhs.priceCents > rhs.priceCents
            case .priceLow: return lhs.priceCents < rhs.priceCents
            case .storeName: return lhs.storeName.localizedCompare(rhs.storeName) == .orderedAscending
            }
        }
    }

    // MARK: - Stats

    private var activeReturnCount: Int {
        items.filter { $0.isReturnWindowOpen }.count
    }

    private var criticalItems: [ReceiptItem] {
        items.filter { $0.urgencyLevel == .critical }
    }

    private var moneySaved: Int {
        items.filter { $0.isReturned }.reduce(0) { $0 + $1.priceCents }
    }

    private var moneySavedFormatted: String {
        let dollars = Double(moneySaved) / 100.0
        return dollars.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottom) {
                Group {
                    if items.isEmpty {
                        emptyState
                    } else {
                        scrollContent
                    }
                }
                .background(RFColors.paper)

                batchActionBar
            }
            .navigationDestination(for: ReceiptItem.self) { item in
                ItemDetailView(item: item)
            }
            .onChange(of: isEditing) { _, newValue in
                if !newValue { selectedItems.removeAll() }
            }
            .onChange(of: navigationState.pendingItemID) { _, newID in
                consumePendingItemID(newID)
            }
            .onAppear {
                consumePendingItemID(navigationState.pendingItemID)
            }
        }
    }

    private func consumePendingItemID(_ id: UUID?) {
        guard let id, let target = items.first(where: { $0.id == id }) else { return }
        // Single assignment avoids the brief empty-path state that SwiftUI
        // can pick up between `path = NavigationPath()` and `path.append(...)`.
        var newPath = NavigationPath()
        newPath.append(target)
        path = newPath
        navigationState.pendingItemID = nil
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                masthead
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                ledgerRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                RFPerforation()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                if !criticalItems.isEmpty {
                    criticalBanner
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }

                filterStrip
                    .padding(.bottom, 16)

                receiptsList

                Spacer().frame(height: 120)
            }
        }
        .searchable(text: $searchText, prompt: "Search receipts")
    }

    // MARK: - Masthead
    //
    // Newspaper-style header: issue/date line, thick rule, large serif title,
    // italic subtitle, thin rule.

    private var masthead: some View {
        VStack(spacing: 10) {
            HStack {
                Text("THE VAULT")
                    .font(RFFont.mono(10))
                    .tracking(1.8)
                    .foregroundStyle(RFColors.mute)
                Spacer()
                Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()).uppercased())
                    .font(RFFont.mono(10))
                    .tracking(1.2)
                    .foregroundStyle(RFColors.mute)

                Menu {
                    ForEach(VaultSortOption.allCases, id: \.self) { option in
                        Button {
                            sortOption = option
                        } label: {
                            if sortOption == option {
                                Label(option.rawValue, systemImage: "checkmark")
                            } else {
                                Text(option.rawValue)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(RFColors.ink)
                        .padding(.leading, 12)
                }
                .accessibilityLabel("Sort receipts")

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isEditing.toggle() }
                } label: {
                    Text(isEditing ? "DONE" : "EDIT")
                        .font(RFFont.mono(10))
                        .tracking(1.2)
                        .foregroundStyle(RFColors.ink)
                        .underline(isEditing)
                        .padding(.leading, 12)
                }
            }

            Rectangle()
                .fill(RFColors.ink)
                .frame(height: 2)

            HStack(alignment: .firstTextBaseline) {
                Text("Receipt")
                    .font(RFFont.hero(52))
                    .foregroundStyle(RFColors.ink)
                Text("Folder")
                    .font(.system(size: 52, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.signal)
                Spacer()
            }

            HStack {
                Text("No. \(String(format: "%04d", items.count)) — \(itemWord) on file")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
                Spacer()
            }

            RFHairline()
                .padding(.top, 2)
        }
    }

    private var itemWord: String {
        items.count == 1 ? "item" : "items"
    }

    // MARK: - Ledger Row
    //
    // Three tabular columns: Total, Active, Saved. Big serif numbers,
    // eyebrow labels. Replaces the bubbly "summary card".

    private var ledgerRow: some View {
        HStack(alignment: .top, spacing: 0) {
            ledgerColumn(
                label: "On File",
                value: "\(items.count)",
                accent: false
            )

            RFHairline()
                .frame(width: 0.5, height: 56)
                .overlay(Rectangle().fill(RFColors.rule).frame(width: 0.5))

            ledgerColumn(
                label: "Active",
                value: "\(activeReturnCount)",
                accent: activeReturnCount > 0
            )

            RFHairline()
                .frame(width: 0.5, height: 56)
                .overlay(Rectangle().fill(RFColors.rule).frame(width: 0.5))

            ledgerColumn(
                label: "Returned",
                value: moneySavedFormatted,
                accent: false,
                isMoney: true
            )
        }
    }

    private func ledgerColumn(label: String, value: String, accent: Bool, isMoney: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(RFFont.mono(10))
                .tracking(1.2)
                .foregroundStyle(RFColors.mute)

            Text(value)
                .font(isMoney
                      ? .system(size: 22, weight: .regular, design: .serif)
                      : .system(size: 34, weight: .regular, design: .serif))
                .foregroundStyle(accent ? RFColors.signal : RFColors.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }

    // MARK: - Critical Banner
    //
    // Editorial alert box: signal-red left rule, serif headline, mono meta.

    private var criticalBanner: some View {
        Button {
            NavigationState.shared.selectedTab = .expiring
        } label: {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(RFColors.signal)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 4) {
                    Text("URGENT — RETURN DEADLINES")
                        .font(RFFont.mono(10))
                        .tracking(1.4)
                        .foregroundStyle(RFColors.signal)

                    Text("\(criticalItems.count) \(criticalItems.count == 1 ? "item" : "items") closing within 3 days")
                        .font(.system(size: 18, weight: .regular, design: .serif))
                        .foregroundStyle(RFColors.ink)
                        .multilineTextAlignment(.leading)

                    Text("Review expiring list →")
                        .font(.system(size: 12, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(RFColors.mute)
                        .padding(.top, 2)
                }
                .padding(.leading, 14)
                .padding(.vertical, 14)
                .padding(.trailing, 14)

                Spacer()
            }
            .background(RFColors.paperDim)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(criticalItems.count) items expiring soon.")
        .accessibilityHint("Tap to view expiring items")
    }

    // MARK: - Filter Strip

    @ViewBuilder
    private var filterStrip: some View {
        if !items.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(VaultFilterType.allCases, id: \.self) { filter in
                        let active = activeFilters.contains(filter)
                        Button {
                            if active { activeFilters.remove(filter) }
                            else { activeFilters.insert(filter) }
                        } label: {
                            Text(filter.rawValue.uppercased())
                                .font(RFFont.mono(10))
                                .tracking(1.2)
                                .foregroundStyle(active ? RFColors.paper : RFColors.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(active ? RFColors.ink : .clear)
                                .overlay(
                                    Rectangle()
                                        .stroke(RFColors.ink, lineWidth: 0.75)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 8)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Receipts List

    private var receiptsList: some View {
        LazyVStack(spacing: 0) {
            HStack {
                RFSectionHeader(title: "Latest Entries")
                Spacer()
                Text("\(filteredItems.count)")
                    .font(RFFont.mono(11))
                    .foregroundStyle(RFColors.mute)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            if filteredItems.isEmpty && !items.isEmpty {
                if !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .padding(.vertical, 40)
                } else {
                    VStack(spacing: 12) {
                        Text("No matching receipts")
                            .font(.system(size: 16, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(RFColors.mute)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                }
            }

            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                VStack(spacing: 0) {
                    if index == 0 {
                        RFHairline().padding(.horizontal, 20)
                    }

                    if isEditing {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if selectedItems.contains(item.id) { selectedItems.remove(item.id) }
                                else { selectedItems.insert(item.id) }
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: selectedItems.contains(item.id) ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundStyle(selectedItems.contains(item.id) ? RFColors.ink : RFColors.mute)
                                VaultRowView(item: item)
                            }
                            .padding(.horizontal, 20)
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink(value: item) {
                            VaultRowView(item: item)
                                .padding(.horizontal, 20)
                        }
                        .buttonStyle(.plain)
                    }

                    RFHairline().padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Batch Action Bar

    @ViewBuilder
    private var batchActionBar: some View {
        if isEditing && !selectedItems.isEmpty {
            HStack(spacing: 20) {
                batchActionButton(label: "Return", icon: "arrow.uturn.left", action: batchMarkReturned)
                batchActionButton(label: "Archive", icon: "archivebox", action: batchArchive)
                Spacer()
                batchActionButton(label: "Delete", icon: "trash", action: batchDelete, destructive: true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(RFColors.paperDim)
            .overlay(Rectangle().stroke(RFColors.ink, lineWidth: 0.75))
            .padding(.horizontal, 16)
            .padding(.bottom, 96)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func batchActionButton(label: String, icon: String, action: @escaping () -> Void, destructive: Bool = false) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .regular))
                Text(label.uppercased())
                    .font(RFFont.mono(10))
                    .tracking(1.2)
            }
            .foregroundStyle(destructive ? RFColors.signal : RFColors.ink)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Batch Actions

    private func batchMarkReturned() {
        for item in items where selectedItems.contains(item.id) {
            item.isReturned = true
            NotificationScheduler.shared.cancelNotifications(for: item.id)
            LiveActivityManager.shared.endLiveActivity(for: item.id)
        }
        WidgetSyncService.sync(modelContext: modelContext)
        selectedItems.removeAll()
        isEditing = false
        HapticsService.shared.playSuccess()
    }

    private func batchArchive() {
        for item in items where selectedItems.contains(item.id) {
            item.isArchived = true
            NotificationScheduler.shared.cancelNotifications(for: item.id)
            LiveActivityManager.shared.endLiveActivity(for: item.id)
        }
        WidgetSyncService.sync(modelContext: modelContext)
        selectedItems.removeAll()
        isEditing = false
        HapticsService.shared.playSuccess()
    }

    private func batchDelete() {
        for item in items where selectedItems.contains(item.id) {
            NotificationScheduler.shared.cancelNotifications(for: item.id)
            LiveActivityManager.shared.endLiveActivity(for: item.id)
            SpotlightIndexer.shared.removeItem(item.id)
            ImageStorageService.shared.deleteImage(relativePath: item.receiptImagePath)
            if let itemPath = item.itemImagePath {
                ImageStorageService.shared.deleteImage(relativePath: itemPath)
            }
            modelContext.delete(item)
        }
        WidgetSyncService.sync(modelContext: modelContext)
        selectedItems.removeAll()
        isEditing = false
        HapticsService.shared.playSuccess()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            masthead
                .padding(.horizontal, 20)
                .padding(.top, 8)

            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "tray")
                    .font(.system(size: 48, weight: .regular))
                    .foregroundStyle(RFColors.ink.opacity(0.35))

                Text("An empty ledger.")
                    .font(RFFont.title(28))
                    .foregroundStyle(RFColors.ink)

                Text("Scan your first receipt to begin tracking returns and warranties.")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button("Add your first receipt") { showingAddItem = true }
                    .buttonStyle(RFPrimaryButtonStyle())
                    .padding(.horizontal, 48)
                    .padding(.top, 8)
                    .accessibilityIdentifier("button.addFirstReceipt")
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RFColors.paper)
    }
}
