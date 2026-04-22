import WidgetKit
import SwiftUI

struct TopExpiringEntry: TimelineEntry {
    let date: Date
    let items: [WidgetReceiptItem]
}

struct TopExpiringProvider: TimelineProvider {
    func placeholder(in context: Context) -> TopExpiringEntry {
        TopExpiringEntry(date: .now, items: [
            WidgetReceiptItem(id: "1", productName: "Sony Headphones", storeName: "Best Buy",
                              daysUntilReturnExpiry: 4, daysUntilWarrantyExpiry: 362,
                              urgencyLevel: "warning", isGift: false),
            WidgetReceiptItem(id: "2", productName: "LG OLED TV", storeName: "Costco",
                              daysUntilReturnExpiry: 70, daysUntilWarrantyExpiry: 714,
                              urgencyLevel: "active", isGift: false),
            WidgetReceiptItem(id: "3", productName: "Stand Mixer", storeName: "Williams Sonoma",
                              daysUntilReturnExpiry: nil, daysUntilWarrantyExpiry: 274,
                              urgencyLevel: "active", isGift: false),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (TopExpiringEntry) -> Void) {
        let items = WidgetDataProvider.loadTopExpiring()
        completion(TopExpiringEntry(date: .now, items: items))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TopExpiringEntry>) -> Void) {
        let items = WidgetDataProvider.loadTopExpiring()
        let entry = TopExpiringEntry(date: .now, items: items)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct TopExpiringWidgetView: View {
    let entry: TopExpiringEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if entry.items.isEmpty {
            VStack {
                Image(systemName: "checkmark")
                    .font(.title3)
                    .foregroundStyle(WidgetPalette.ink)
                Text("No deadlines approaching")
                    .font(.caption)
                    .foregroundStyle(WidgetPalette.mute)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text("EXPIRING SOON")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)

                ForEach(Array(entry.items.prefix(family == .systemMedium ? 3 : 1).enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider()
                            .padding(.vertical, 4)
                    }
                    itemRow(item)
                }

                Spacer(minLength: 0)
            }
            .padding()
        }
    }

    private func itemRow(_ item: WidgetReceiptItem) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(urgencyColor(item))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.productName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(item.storeName)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(daysText(item))
                .font(.caption.weight(.bold))
                .foregroundStyle(urgencyColor(item))
        }
    }

    private func daysText(_ item: WidgetReceiptItem) -> String {
        if let days = item.daysUntilReturnExpiry {
            return days == 0 ? "Today" : "\(days)d"
        }
        if let days = item.daysUntilWarrantyExpiry {
            return "\(days)d"
        }
        return ""
    }

    private func urgencyColor(_ item: WidgetReceiptItem) -> Color {
        switch item.urgencyLevel {
        case "critical": WidgetPalette.signal
        case "warning": WidgetPalette.signal
        case "warrantyExpiring": WidgetPalette.ember
        default: WidgetPalette.ink
        }
    }
}

struct TopExpiringWidget: Widget {
    let kind = "TopExpiringWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TopExpiringProvider()) { entry in
            TopExpiringWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Top Expiring")
        .description("Shows your top 3 most urgent return and warranty deadlines.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
