import SwiftUI
import SwiftData

/// Expiring dashboard — rendered as an editorial "urgent desk" front page.
/// Sections: Imminent (red), Closing Soon (red outline), Warranty (ember).
struct ExpiringDashboardView: View {
    @Environment(\.legibilityWeight) private var legibilityWeight
    @Query(
        filter: #Predicate<ReceiptItem> { !$0.isArchived && !$0.isReturned },
        sort: \ReceiptItem.returnWindowEndDate
    )
    private var items: [ReceiptItem]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    masthead
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 24)

                    if criticalItems.isEmpty && warningItems.isEmpty && warrantyExpiringItems.isEmpty {
                        allClearState
                    } else {
                        content
                    }

                    Spacer().frame(height: 120)
                }
            }
            .background(RFColors.paper)
            .navigationBarHidden(true)
            .navigationDestination(for: ReceiptItem.self) { item in
                ItemDetailView(item: item)
            }
        }
    }

    // MARK: - Masthead

    private var masthead: some View {
        VStack(spacing: 10) {
            HStack {
                Text("URGENT DESK")
                    .font(RFFont.mono(10))
                    .tracking(1.8)
                    .foregroundStyle(RFColors.mute)
                Spacer()
                Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()).uppercased())
                    .font(RFFont.mono(10))
                    .tracking(1.2)
                    .foregroundStyle(RFColors.mute)
            }

            Rectangle().fill(RFColors.ink).frame(height: 2)

            HStack(alignment: .firstTextBaseline) {
                Text("Expiring")
                    .font(RFFont.hero(52))
                    .foregroundStyle(RFColors.ink)
                Text("Soon")
                    .font(.system(size: 52, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.signal)
                Spacer()
            }

            HStack {
                Text(subtitleText)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
                Spacer()
            }

            RFHairline()
                .padding(.top, 2)
        }
    }

    private var subtitleText: String {
        let total = criticalItems.count + warningItems.count + warrantyExpiringItems.count
        if total == 0 { return "Nothing pressing today." }
        if total == 1 { return "1 item requires your attention." }
        return "\(total) items require your attention."
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 28) {
            if !criticalItems.isEmpty {
                urgencySection(
                    eyebrow: "Deadline Imminent",
                    headline: "Return within 3 days",
                    items: criticalItems,
                    accent: RFColors.signal,
                    useLedgerStamp: true,
                    sortPriority: 3
                )
            }

            if !warningItems.isEmpty {
                urgencySection(
                    eyebrow: "Closing Soon",
                    headline: "Return within 2 weeks",
                    items: warningItems,
                    accent: RFColors.signal,
                    useLedgerStamp: false,
                    sortPriority: 2
                )
            }

            if !warrantyExpiringItems.isEmpty {
                urgencySection(
                    eyebrow: "Warranty Expiring",
                    headline: "Coverage ends soon",
                    items: warrantyExpiringItems,
                    accent: RFColors.ember,
                    useLedgerStamp: false,
                    sortPriority: 1
                )
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Section

    private func urgencySection(
        eyebrow: String,
        headline: String,
        items: [ReceiptItem],
        accent: Color,
        useLedgerStamp: Bool,
        sortPriority: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(accent)
                        .frame(width: 10, height: 10)
                    Text(eyebrow.uppercased())
                        .font(RFFont.mono(10))
                        .tracking(1.6)
                        .foregroundStyle(accent)
                    Spacer()
                    Text("\(items.count) \(items.count == 1 ? "ITEM" : "ITEMS")")
                        .font(RFFont.mono(10))
                        .tracking(1.4)
                        .foregroundStyle(RFColors.mute)
                }

                Text(headline)
                    .font(RFFont.heading(24))
                    .foregroundStyle(RFColors.ink)
            }

            RFHairline()

            VStack(spacing: 0) {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        expiringRow(item: item, accent: accent, useLedgerStamp: useLedgerStamp)
                    }
                    .buttonStyle(.plain)

                    if item.id != items.last?.id {
                        RFHairline()
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilitySortPriority(sortPriority)
    }

    // MARK: - Row

    private func expiringRow(item: ReceiptItem, accent: Color, useLedgerStamp: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            StoreAvatar(name: item.storeName, size: 36)
                .padding(.top, 2)

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

                HStack(spacing: 8) {
                    RFProgressBar(
                        progress: item.returnWindowProgress > 0 ? item.returnWindowProgress : item.warrantyProgress,
                        color: accent,
                        height: 1.5
                    )
                    .frame(width: 120)
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 8)

            daysNumeral(item: item, accent: accent, stamp: useLedgerStamp)
        }
        .padding(.vertical, 14)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel(for: item))
        .accessibilityHint("Double tap to view details")
    }

    @ViewBuilder
    private func daysNumeral(item: ReceiptItem, accent: Color, stamp: Bool) -> some View {
        let days = item.returnDaysRemaining ?? item.warrantyDaysRemaining
        if let days, days == 0 {
            Text("TODAY")
                .font(RFFont.monoBold(11))
                .tracking(1.4)
                .foregroundStyle(RFColors.paper)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(accent)
        } else if let days {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(days)")
                    .font(.system(size: stamp ? 34 : 28, weight: .regular, design: .serif))
                    .foregroundStyle(accent)
                Text("d")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(accent)
            }
        }
    }

    // MARK: - All clear state

    private var allClearState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

            Image(systemName: "checkmark")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(RFColors.ink.opacity(0.4))
                .padding(.bottom, 4)

            Text("All clear.")
                .font(RFFont.title(40))
                .foregroundStyle(RFColors.ink)

            Text("No deadlines on the horizon.")
                .font(.system(size: 15, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.mute)

            Spacer().frame(height: 60)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }

    // MARK: - Accessibility

    private func rowAccessibilityLabel(for item: ReceiptItem) -> String {
        var parts = [item.productName, item.storeName]
        if item.priceCents > 0 { parts.append(item.formattedPrice) }
        if let days = item.returnDaysRemaining, days > 0 {
            parts.append("return window: \(days) days left")
        }
        if let days = item.warrantyDaysRemaining, days > 0 {
            parts.append("warranty: \(days) days left")
        }
        parts.append(item.urgencyLevel.label)
        return parts.joined(separator: ", ")
    }

    // MARK: - Computed

    private var criticalItems: [ReceiptItem] {
        items.filter { $0.urgencyLevel == .critical }
            .sorted { ($0.returnDaysRemaining ?? .max) < ($1.returnDaysRemaining ?? .max) }
    }

    private var warningItems: [ReceiptItem] {
        items.filter { $0.urgencyLevel == .warning }
            .sorted { ($0.returnDaysRemaining ?? .max) < ($1.returnDaysRemaining ?? .max) }
    }

    private var warrantyExpiringItems: [ReceiptItem] {
        items.filter { $0.urgencyLevel == .warrantyExpiring }
            .sorted { ($0.warrantyDaysRemaining ?? .max) < ($1.warrantyDaysRemaining ?? .max) }
    }
}
