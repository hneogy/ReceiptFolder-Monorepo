import SwiftUI

/// A vault row for a `HouseholdReceipt` — receipts that live in a shared
/// CloudKit zone instead of the user's private SwiftData store. Visually
/// mirrors `VaultRowView` so the two can stack in one list without the
/// household entries feeling grafted on.
///
/// The only visible distinction is a mono "SHARED · Name" chip above the
/// product title, so a user scanning the vault can tell at a glance which
/// items came from their co-owner.
struct HouseholdRowView: View {
    let record: HouseholdReceipt

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            StoreAvatar(name: record.storeName, size: 40)
                .padding(.top, 2)

            centerColumn

            Spacer(minLength: 8)

            rightColumn
        }
        .padding(.vertical, 16)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to view shared receipt details")
        .accessibilityIdentifier("household-row.\(record.productName)")
    }

    // MARK: - Center column

    private var centerColumn: some View {
        VStack(alignment: .leading, spacing: 5) {
            sharedChip

            Text(record.productName)
                .font(RFFont.serifBody(17))
                .foregroundStyle(RFColors.ink)
                .lineLimit(1)

            metaRow

            progressRow
        }
    }

    private var sharedChip: some View {
        HStack(spacing: 0) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 8, weight: .regular))
                .foregroundStyle(RFColors.signal)
                .padding(.trailing, 4)
            Text("SHARED · \(record.ownerDisplayName.uppercased())")
                .font(RFFont.mono(9))
                .tracking(1.2)
                .foregroundStyle(RFColors.signal)
        }
    }

    private var metaRow: some View {
        HStack(spacing: 6) {
            Text(record.storeName.uppercased())
                .font(RFFont.mono(10))
                .tracking(1.0)
                .foregroundStyle(RFColors.mute)

            Text("·")
                .font(RFFont.mono(10))
                .foregroundStyle(RFColors.mute)

            Text(record.purchaseDate.formatted(.dateTime.month(.abbreviated).day()).uppercased())
                .font(RFFont.mono(10))
                .tracking(1.0)
                .foregroundStyle(RFColors.mute)
        }
    }

    @ViewBuilder
    private var progressRow: some View {
        if record.isReturned {
            Text("RETURNED")
                .font(RFFont.mono(10))
                .tracking(1.2)
                .foregroundStyle(RFColors.mute)
                .strikethrough()
        } else if let days = record.returnDaysRemaining {
            Text(days == 0 ? "LAST DAY" : "\(days) DAYS TO RETURN")
                .font(RFFont.mono(10))
                .tracking(0.8)
                .foregroundStyle(days <= 3 ? RFColors.signal : RFColors.ink)
        }
    }

    // MARK: - Right column

    private var rightColumn: some View {
        VStack(alignment: .trailing, spacing: 4) {
            daysDisplay

            if record.priceCents > 0 {
                Text(record.formattedPrice)
                    .font(RFFont.monoMedium(12))
                    .foregroundStyle(RFColors.ink)
            }
        }
    }

    @ViewBuilder
    private var daysDisplay: some View {
        if let days = record.returnDaysRemaining, days > 0, !record.isReturned {
            let tint: Color = record.urgencyLevel == .critical ? RFColors.signal : RFColors.ink
            let muted: Color = record.urgencyLevel == .critical ? RFColors.signal : RFColors.mute
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(days)")
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .foregroundStyle(tint)
                Text("d")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(muted)
            }
        } else if let days = record.returnDaysRemaining, days == 0, !record.isReturned {
            Text("TODAY")
                .font(RFFont.monoBold(11))
                .tracking(1.4)
                .foregroundStyle(RFColors.signal)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RFColors.signal.opacity(0.12))
                .overlay(Rectangle().stroke(RFColors.signal, lineWidth: 0.75))
        }
    }

    private var accessibilityLabel: String {
        var parts = ["Shared by \(record.ownerDisplayName)", record.productName, record.storeName]
        if record.priceCents > 0 { parts.append(record.formattedPrice) }
        if let days = record.returnDaysRemaining, days > 0 {
            parts.append("return window: \(days) days left")
        }
        return parts.joined(separator: ", ")
    }
}
