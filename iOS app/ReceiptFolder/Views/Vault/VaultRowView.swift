import SwiftUI

/// A single ledger entry. Reads left-to-right like a receipt row.
/// No card, no shadow, no rounded pill. Delimited by hairlines applied by the parent.
struct VaultRowView: View {
    let item: ReceiptItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            StoreAvatar(name: item.storeName, size: 40)
                .padding(.top, 2)

            centerColumn

            Spacer(minLength: 8)

            rightColumn
        }
        .padding(.vertical, 16)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to view details")
        // Stable identifier — product name is unique per test run.
        .accessibilityIdentifier("row.\(item.productName)")
        .accessibilityCustomContent("Store", item.storeName)
        .accessibilityCustomContent("Price", priceAccessibilityText)
        .accessibilityCustomContent("Purchase date", item.purchaseDate.formatted(date: .abbreviated, time: .omitted))
        .accessibilityCustomContent("Urgency", item.urgencyLevel.label, importance: .high)
        .accessibilityCustomContent("Return", returnAccessibilitySummary)
        .accessibilityCustomContent("Warranty", warrantyAccessibilitySummary)
    }

    // MARK: - Center column (product + meta + progress)

    private var centerColumn: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.productName)
                .font(RFFont.serifBody(17))
                .foregroundStyle(RFColors.ink)
                .lineLimit(1)

            metaRow

            progressRow
        }
    }

    private var metaRow: some View {
        HStack(spacing: 6) {
            Text(item.storeName.uppercased())
                .font(RFFont.mono(10))
                .tracking(1.0)
                .foregroundStyle(RFColors.mute)

            Text("·")
                .font(RFFont.mono(10))
                .foregroundStyle(RFColors.mute)

            Text(item.purchaseDate.formatted(.dateTime.month(.abbreviated).day()).uppercased())
                .font(RFFont.mono(10))
                .tracking(1.0)
                .foregroundStyle(RFColors.mute)
        }
    }

    @ViewBuilder
    private var progressRow: some View {
        if item.returnWindowEndDate != nil && !item.isReturned {
            HStack(spacing: 8) {
                RFProgressBar(progress: item.returnWindowProgress, color: returnColor, height: 1.5)
                    .frame(width: 80)

                Text(returnText)
                    .font(RFFont.mono(10))
                    .tracking(0.8)
                    .foregroundStyle(returnColor)
            }
        } else if item.isReturned {
            Text("RETURNED")
                .font(RFFont.mono(10))
                .tracking(1.2)
                .foregroundStyle(RFColors.mute)
                .strikethrough()
        }
    }

    // MARK: - Right column (days + price)

    private var rightColumn: some View {
        VStack(alignment: .trailing, spacing: 4) {
            daysDisplay

            if item.priceCents > 0 {
                Text(item.formattedPrice)
                    .font(RFFont.monoMedium(12))
                    .foregroundStyle(RFColors.ink)
            }
        }
    }

    @ViewBuilder
    private var daysDisplay: some View {
        if let days = item.returnDaysRemaining, days > 0, !item.isReturned {
            daysRemainingNumeral(days: days)
        } else if let days = item.returnDaysRemaining, days == 0, !item.isReturned {
            todayStamp
        }
    }

    private func daysRemainingNumeral(days: Int) -> some View {
        let tint: Color = item.urgencyLevel == .critical ? RFColors.signal : RFColors.ink
        let muted: Color = item.urgencyLevel == .critical ? RFColors.signal : RFColors.mute
        return HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text("\(days)")
                .font(.system(size: 28, weight: .regular, design: .serif))
                .foregroundStyle(tint)
            Text("d")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(muted)
        }
    }

    private var todayStamp: some View {
        Text("TODAY")
            .font(RFFont.monoBold(11))
            .tracking(1.4)
            .foregroundStyle(RFColors.signal)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RFColors.signal.opacity(0.12))
            .overlay(Rectangle().stroke(RFColors.signal, lineWidth: 0.75))
    }

    // MARK: - Helpers

    private var returnColor: Color {
        guard let days = item.returnDaysRemaining else { return RFColors.mute }
        if days <= 3 { return RFColors.signal }
        return RFColors.ink
    }

    private var returnText: String {
        guard let days = item.returnDaysRemaining else { return "—" }
        if days == 0 { return "LAST DAY" }
        return "\(days) DAYS TO RETURN"
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
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

    private var priceAccessibilityText: String {
        item.priceCents > 0 ? item.formattedPrice : "No price"
    }

    private var returnAccessibilitySummary: String {
        if item.isReturned { return "Returned" }
        guard let days = item.returnDaysRemaining, days > 0 else { return "Closed" }
        return "\(days) day\(days == 1 ? "" : "s") left"
    }

    private var warrantyAccessibilitySummary: String {
        if item.isWarrantyClaimed { return "Claimed" }
        guard let days = item.warrantyDaysRemaining, days > 0 else { return "None" }
        return "\(days) day\(days == 1 ? "" : "s") left"
    }
}
