import SwiftUI
import SwiftData

/// The "back issues" drawer — archived and returned items, rendered as a
/// plain printed index.
struct ArchivedItemsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<ReceiptItem> { $0.isArchived },
        sort: \ReceiptItem.createdAt,
        order: .reverse
    )
    private var archivedItems: [ReceiptItem]

    @State private var searchText = ""

    private var filteredItems: [ReceiptItem] {
        if searchText.isEmpty { return archivedItems }
        let query = searchText.lowercased()
        return archivedItems.filter {
            $0.productName.lowercased().contains(query) ||
            $0.storeName.lowercased().contains(query)
        }
    }

    var body: some View {
        Group {
            if archivedItems.isEmpty {
                emptyState
            } else {
                itemsList
            }
        }
        .background(RFColors.paper)
        .navigationTitle("Back Issues")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search archive")
    }

    private var itemsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                HStack {
                    Text("ARCHIVE")
                        .font(RFFont.mono(10))
                        .tracking(1.8)
                        .foregroundStyle(RFColors.mute)
                    Spacer()
                    Text("\(filteredItems.count) \(filteredItems.count == 1 ? "ITEM" : "ITEMS")")
                        .font(RFFont.mono(10))
                        .tracking(1.4)
                        .foregroundStyle(RFColors.mute)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 12)

                RFHairline().padding(.horizontal, 20)

                ForEach(filteredItems) { item in
                    archivedRow(item: item)
                        .swipeActions(edge: .leading) {
                            Button("Unarchive") {
                                item.isArchived = false
                                NotificationScheduler.shared.scheduleNotifications(for: item)
                                SpotlightIndexer.shared.indexItem(item)
                                if item.urgencyLevel == .critical {
                                    LiveActivityManager.shared.startLiveActivity(for: item)
                                }
                                WidgetSyncService.sync(modelContext: modelContext)
                            }
                            .tint(RFColors.ink)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                SpotlightIndexer.shared.removeItem(item.id)
                                NotificationScheduler.shared.cancelNotifications(for: item.id)
                                ImageStorageService.shared.deleteImage(relativePath: item.receiptImagePath)
                                if let itemPath = item.itemImagePath {
                                    ImageStorageService.shared.deleteImage(relativePath: itemPath)
                                }
                                modelContext.delete(item)
                                WidgetSyncService.sync(modelContext: modelContext)
                            }
                        }

                    RFHairline().padding(.horizontal, 20)
                }

                Spacer().frame(height: 40)
            }
        }
    }

    private func archivedRow(item: ReceiptItem) -> some View {
        HStack(alignment: .top, spacing: 14) {
            StoreAvatar(name: item.storeName, size: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.productName)
                    .font(RFFont.serifBody(16))
                    .foregroundStyle(RFColors.ink)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(item.storeName.uppercased())
                        .font(RFFont.mono(10))
                        .tracking(1.0)
                        .foregroundStyle(RFColors.mute)
                    if item.priceCents > 0 {
                        Text("·")
                            .font(RFFont.mono(10))
                            .foregroundStyle(RFColors.mute)
                        Text(item.formattedPrice)
                            .font(RFFont.monoMedium(10))
                            .foregroundStyle(RFColors.mute)
                    }
                }

                HStack(spacing: 6) {
                    if item.isReturned {
                        Text("RETURNED")
                            .font(RFFont.mono(9))
                            .tracking(1.4)
                            .foregroundStyle(RFColors.signal)
                    }
                    if item.isWarrantyClaimed {
                        Text("WARRANTY CLAIMED")
                            .font(RFFont.mono(9))
                            .tracking(1.4)
                            .foregroundStyle(RFColors.ember)
                    }
                }
            }

            Spacer()

            Text(item.purchaseDate.formatted(.dateTime.month(.abbreviated).day().year()).uppercased())
                .font(RFFont.mono(10))
                .tracking(1.0)
                .foregroundStyle(RFColors.mute)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(.rect)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "archivebox")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(RFColors.ink.opacity(0.35))

            Text("An empty archive.")
                .font(RFFont.title(28))
                .foregroundStyle(RFColors.ink)

            Text("Archived and returned items will appear here.")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.mute)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}
