import SwiftUI
import UIKit

/// Read-plus-one-write detail view for a receipt that lives in the household
/// shared zone. We render the same editorial masthead / countdown / metadata
/// as `ItemDetailView` but strip the actions that don't make sense for a
/// mirrored record (Archive, Delete, Share toggle). The only write path is
/// "Mark as Returned" — and it routes through `HouseholdStore.markReturned`
/// so the change goes back to the right CKDatabase.
struct HouseholdReceiptDetailView: View {
    let record: HouseholdReceipt
    @Environment(\.dismiss) private var dismiss
    @State private var store = HouseholdStore.shared
    @State private var isWorking = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                masthead
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                heroCountdown
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 28)

                RFPerforation()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                metadataTable
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                RFPerforation()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                if let receiptImage {
                    receiptImageSection(receiptImage)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    RFPerforation()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }

                if !record.isReturned {
                    markReturnedButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }

                footer
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
            }
        }
        .background(RFColors.paper)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Masthead

    private var masthead: some View {
        VStack(spacing: 12) {
            HStack {
                Text("RECEIPT · FOLDER")
                    .font(RFFont.mono(10))
                    .tracking(1.8)
                    .foregroundStyle(RFColors.mute)
                Spacer()
                Text("SHARED · \(record.ownerDisplayName.uppercased())")
                    .font(RFFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.signal)
            }

            Rectangle().fill(RFColors.ink).frame(height: 2)

            Text(record.productName)
                .font(RFFont.hero(36))
                .foregroundStyle(RFColors.ink)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                Text("from ")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
                Text(record.storeName)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(RFColors.ink)
                Text(" · ")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(RFColors.mute)
                Text(record.purchaseDate.formatted(date: .long, time: .omitted))
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
                Spacer()
            }

            RFHairline()
        }
    }

    // MARK: - Hero countdown

    @ViewBuilder
    private var heroCountdown: some View {
        if record.isReturned {
            returnedStamp
        } else if let days = record.returnDaysRemaining, days >= 0 {
            countdownDisplay(
                number: days,
                label: days == 1 ? "DAY" : "DAYS",
                caption: days == 0 ? "Final day to return" : "until return window closes",
                color: record.urgencyLevel == .critical ? RFColors.signal : RFColors.ink
            )
        } else if let days = record.warrantyDaysRemaining, days >= 0 {
            countdownDisplay(
                number: days,
                label: days == 1 ? "DAY" : "DAYS",
                caption: "of warranty remaining",
                color: RFColors.ink
            )
        } else {
            Text("No active deadlines")
                .font(.system(size: 16, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.mute)
                .frame(maxWidth: .infinity)
        }
    }

    private func countdownDisplay(number: Int, label: String, caption: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(number)")
                    .font(.system(size: 120, weight: .regular, design: .serif))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(color)
            }
            Text(caption)
                .font(.system(size: 13, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.mute)
        }
        .frame(maxWidth: .infinity)
    }

    private var returnedStamp: some View {
        VStack(spacing: 6) {
            Text("RETURNED")
                .font(.system(size: 44, weight: .regular, design: .serif))
                .tracking(4)
                .foregroundStyle(RFColors.signal)
                .strikethrough()
            if let at = record.returnedAt {
                Text(at.formatted(date: .long, time: .shortened))
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Metadata

    private var metadataTable: some View {
        VStack(spacing: 0) {
            metadataRow("DATE", record.purchaseDate.formatted(date: .long, time: .omitted))
            RFHairline().padding(.vertical, 6)
            metadataRow("STORE", record.storeName)
            if record.priceCents > 0 {
                RFHairline().padding(.vertical, 6)
                metadataRow("PRICE", record.formattedPrice)
            }
            if let returnDate = record.returnWindowEndDate {
                RFHairline().padding(.vertical, 6)
                metadataRow("RETURN BY", returnDate.formatted(date: .long, time: .omitted), signal: !record.isReturned)
            }
            if let warrantyDate = record.warrantyEndDate {
                RFHairline().padding(.vertical, 6)
                metadataRow("WARRANTY", warrantyDate.formatted(date: .long, time: .omitted))
            }
        }
    }

    private func metadataRow(_ label: String, _ value: String, signal: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(RFFont.mono(10))
                .tracking(1.4)
                .foregroundStyle(RFColors.mute)
            LeaderDots()
            Text(value)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundStyle(signal ? RFColors.signal : RFColors.ink)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Receipt image

    private var receiptImage: UIImage? {
        guard let data = record.receiptImageData else { return nil }
        return UIImage(data: data)
    }

    private func receiptImageSection(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECEIPT")
                .font(RFFont.mono(10))
                .tracking(1.6)
                .foregroundStyle(RFColors.mute)

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .overlay(Rectangle().stroke(RFColors.ink, lineWidth: 0.5))
        }
    }

    // MARK: - Actions

    private var markReturnedButton: some View {
        Button {
            Task {
                isWorking = true
                do {
                    try await store.markReturned(record.id)
                    HapticsService.shared.playSuccess()
                    dismiss()
                } catch {
                    RFLogger.storage.error("Household markReturned failed: \(error.localizedDescription)")
                    HapticsService.shared.playError()
                }
                isWorking = false
            }
        } label: {
            HStack {
                Image(systemName: "arrow.uturn.left")
                    .font(.system(size: 16))
                Text(isWorking ? "Marking returned…" : "Mark as Returned")
                    .font(.system(size: 16, weight: .regular, design: .serif))
                Spacer()
                if !isWorking { Text("→").font(.system(size: 16, weight: .regular, design: .serif)) }
            }
        }
        .buttonStyle(RFPrimaryButtonStyle())
        .disabled(isWorking)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Rectangle().fill(RFColors.ink).frame(height: 2)
            Text("HOUSEHOLD · SHARED VIEW")
                .font(RFFont.mono(10))
                .tracking(2.0)
                .foregroundStyle(RFColors.mute)
                .padding(.top, 8)
            Text("Managed by \(record.ownerDisplayName). Other fields can only be changed from their device.")
                .font(.system(size: 12, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.mute)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
