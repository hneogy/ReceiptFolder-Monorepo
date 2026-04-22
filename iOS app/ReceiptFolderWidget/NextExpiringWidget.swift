import WidgetKit
import SwiftUI
import AppIntents

struct NextExpiringEntry: TimelineEntry {
    let date: Date
    let item: WidgetReceiptItem?
}

struct NextExpiringProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextExpiringEntry {
        NextExpiringEntry(date: .now, item: WidgetReceiptItem(
            id: "placeholder",
            productName: "Sony Headphones",
            storeName: "Best Buy",
            daysUntilReturnExpiry: 4,
            daysUntilWarrantyExpiry: 362,
            urgencyLevel: "warning",
            isGift: false
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (NextExpiringEntry) -> Void) {
        let item = WidgetDataProvider.loadNextExpiring()
        completion(NextExpiringEntry(date: .now, item: item))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextExpiringEntry>) -> Void) {
        let item = WidgetDataProvider.loadNextExpiring()
        let entry = NextExpiringEntry(date: .now, item: item)
        // Refresh every 6 hours
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct NextExpiringWidgetView: View {
    let entry: NextExpiringEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let item = entry.item {
            switch family {
            case .accessoryRectangular:
                rectangularView(item: item)
            case .accessoryCircular:
                circularView(item: item)
            case .systemSmall:
                smallView(item: item)
            default:
                smallView(item: item)
            }
        } else {
            emptyView
        }
    }

    private func rectangularView(item: WidgetReceiptItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: urgencyIcon(item))
                Text(daysText(item))
                    .fontWeight(.semibold)
            }
            .font(.caption)

            Text(item.productName)
                .font(.caption2)
                .lineLimit(1)

            Text(item.storeName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func circularView(item: WidgetReceiptItem) -> some View {
        VStack(spacing: 2) {
            Image(systemName: urgencyIcon(item))
                .font(.caption)
            if let days = item.daysUntilReturnExpiry {
                Text("\(days)")
                    .font(.title3.weight(.bold))
                Text("days")
                    .font(.system(size: 8))
            } else if let days = item.daysUntilWarrantyExpiry {
                Text("\(days)")
                    .font(.title3.weight(.bold))
                Text("wrty")
                    .font(.system(size: 8))
            }
        }
    }

    private func smallView(item: WidgetReceiptItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "receipt")
                    .foregroundStyle(urgencyColor(item))
                Spacer()
                Text(daysText(item))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(urgencyColor(item))
            }

            Spacer()

            Text(item.productName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            Text(item.storeName)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Interactive: tap to mark this item returned. Runs MarkReturnedIntent
            // in the widget extension process — no app launch required.
            if let uuid = UUID(uuidString: item.id) {
                Button(intent: MarkReturnedIntent(itemID: uuid)) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.semibold))
                        Text("Mark returned")
                            .font(.caption2.weight(.semibold))
                    }
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(WidgetPalette.ink)
                    .foregroundStyle(WidgetPalette.paper)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    private var emptyView: some View {
        VStack {
            Image(systemName: "checkmark")
                .font(.title3)
                .foregroundStyle(WidgetPalette.ink)
            Text("All clear")
                .font(.caption)
                .foregroundStyle(WidgetPalette.mute)
        }
    }

    private func daysText(_ item: WidgetReceiptItem) -> String {
        if let days = item.daysUntilReturnExpiry {
            return days == 0 ? "Today!" : "\(days)d return"
        }
        if let days = item.daysUntilWarrantyExpiry {
            return "\(days)d warranty"
        }
        return "Active"
    }

    private func urgencyIcon(_ item: WidgetReceiptItem) -> String {
        switch item.urgencyLevel {
        case "critical": "exclamationmark.triangle.fill"
        case "warning": "clock.badge.exclamationmark.fill"
        case "warrantyExpiring": "wrench.and.screwdriver"
        default: "checkmark.circle"
        }
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

struct NextExpiringWidget: Widget {
    let kind = "NextExpiringWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextExpiringProvider()) { entry in
            NextExpiringWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Expiring")
        .description("Shows your most urgent return or warranty deadline.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular])
    }
}
