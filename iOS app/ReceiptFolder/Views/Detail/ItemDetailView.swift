import SwiftUI
import SwiftData
import MessageUI
import TipKit
import Accessibility
import StoreKit

/// The item detail view, rendered as a printed receipt document:
///   — Masthead with issue/receipt number
///   — HUGE serif countdown ("14 DAYS") as the emotional anchor
///   — Tabular metadata (DATE / STORE / PRICE / RETURN BY) in monospace
///   — Perforation dividers between sections
///   — Store policy as a quoted block
///   — Action row as plain text buttons with serif labels
struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.legibilityWeight) private var legibilityWeight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview

    @Bindable var item: ReceiptItem
    @State private var itemPhoto: UIImage?
    @State private var showingReturnMode = false
    @State private var showingDeleteAlert = false
    @State private var showingReceiptImage = false
    @State private var showingMailComposer = false
    @State private var calendarAddedReturn = false
    @State private var calendarAddedWarranty = false
    @State private var returnAdvice: ReturnDecisionEngine.ReturnAdvice?
    @State private var hasPlayedUrgencyHaptic = false
    @State private var showingReturnConfirmation = false

    private let returnModeTip = ReturnModeTip()
    private let calendarTip = CalendarTip()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                receiptMasthead
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

                if item.returnWindowEndDate != nil || item.warrantyEndDate != nil {
                    timelineSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    RFPerforation()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }

                if let advice = returnAdvice, advice.recommendation != .tooLate {
                    returnAdviceBlock(advice)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    RFPerforation()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }

                if !item.returnPolicyDescription.isEmpty {
                    policyBlock
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    RFPerforation()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }

                if let photo = itemPhoto {
                    itemPhotoSection(photo)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    RFPerforation()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }

                calendarBlock
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                RFPerforation()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                actionRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                RFPerforation()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                notesBlock
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                footerSignature
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
            }
        }
        .background(RFColors.paper)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if item.isReturnWindowOpen {
                        Button("Mark as Returned", systemImage: "arrow.uturn.left") {
                            item.isReturned = true
                            item.returnedAt = .now
                            NotificationScheduler.shared.cancelNotifications(for: item.id)
                            LiveActivityManager.shared.endLiveActivity(for: item.id)
                            WidgetSyncService.sync(modelContext: modelContext)
                            HapticsService.shared.playSuccess()
                            ReviewPromptService.recordMarkReturned()
                            // Ask for proof-of-return before the review prompt.
                            // The review prompt fires once the user dismisses
                            // the confirmation sheet (handled in onDismiss below).
                            showingReturnConfirmation = true
                        }
                    }
                    if item.isWarrantyActive {
                        Button("Mark Warranty Claimed", systemImage: "wrench.and.screwdriver") {
                            item.isWarrantyClaimed = true
                            NotificationScheduler.shared.cancelNotifications(for: item.id)
                            if !item.isReturnWindowOpen {
                                LiveActivityManager.shared.endLiveActivity(for: item.id)
                            }
                            WidgetSyncService.sync(modelContext: modelContext)
                            HapticsService.shared.playSuccess()
                        }
                    }
                    Button("Archive", systemImage: "archivebox") {
                        item.isArchived = true
                        NotificationScheduler.shared.cancelNotifications(for: item.id)
                        LiveActivityManager.shared.endLiveActivity(for: item.id)
                        WidgetSyncService.sync(modelContext: modelContext)
                        dismiss()
                    }
                    Divider()
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        showingDeleteAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(RFColors.ink)
                }
                .accessibilityLabel("More actions")
                .accessibilityIdentifier("button.itemActions")
            }
        }
        .alert("Delete Receipt?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) { deleteItem() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove this receipt and all associated data.")
        }
        .fullScreenCover(isPresented: $showingReturnMode) {
            ReturnModeView(item: item)
        }
        .sheet(isPresented: $showingReceiptImage) {
            receiptImageSheet
        }
        .sheet(isPresented: $showingMailComposer) {
            MailComposerView(item: item)
        }
        .sheet(
            isPresented: $showingReturnConfirmation,
            onDismiss: {
                // Review prompt fires AFTER the proof-of-return flow so the
                // confirmation sheet isn't interrupted by a system modal.
                try? modelContext.save()
                if ReviewPromptService.shouldAsk() {
                    requestReview()
                    ReviewPromptService.markPromptShown()
                }
            }
        ) {
            ReturnConfirmationView(item: item)
        }
        .onAppear {
            ReturnModeTip.hasViewedItem = true
            if item.urgencyLevel == .critical && !hasPlayedUrgencyHaptic {
                LiveActivityManager.shared.startLiveActivity(for: item)
                HapticsService.shared.playUrgency()
                hasPlayedUrgencyHaptic = true
            }
        }
        .task {
            itemPhoto = await ImageStorageService.shared.loadItemImage(for: item)
            let policy = StorePolicyService.shared.findPolicy(storeName: item.storeName)
            returnAdvice = ReturnDecisionEngine.analyze(item: item, policy: policy)
        }
        .draggable(TransferableReceiptSummary(
            productName: item.productName,
            storeName: item.storeName,
            purchaseDate: item.purchaseDate,
            priceCents: item.priceCents,
            returnDaysRemaining: item.returnDaysRemaining,
            warrantyDaysRemaining: item.warrantyDaysRemaining
        ))
        .accessibilityAction(.magicTap) {
            if item.isReturnWindowOpen {
                showingReturnMode = true
            }
        }
    }

    // MARK: - Receipt Masthead
    //
    // Top strip: RECEIPT FOLDER mono eyebrow + a receipt-style number derived
    // from the UUID. Thick rule. Big serif product name. Italic store+date.

    private var receiptMasthead: some View {
        VStack(spacing: 12) {
            HStack {
                Text("RECEIPT · FOLDER")
                    .font(RFFont.mono(10))
                    .tracking(1.8)
                    .foregroundStyle(RFColors.mute)
                Spacer()
                Text("NO. \(receiptNumber)")
                    .font(RFFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.mute)
            }

            Rectangle().fill(RFColors.ink).frame(height: 2)

            Text(item.productName)
                .font(RFFont.hero(36))
                .foregroundStyle(RFColors.ink)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                Text("from ")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
                Text(item.storeName)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(RFColors.ink)
                Text(" · ")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(RFColors.mute)
                Text(item.purchaseDate.formatted(date: .long, time: .omitted))
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
                Spacer()
            }

            if item.isGift {
                HStack(spacing: 6) {
                    Text("—")
                        .foregroundStyle(RFColors.mute)
                    Text("A GIFT")
                        .font(RFFont.mono(10))
                        .tracking(1.8)
                        .foregroundStyle(RFColors.ember)
                    Spacer()
                }
            }

            RFHairline()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(headerAccessibilityLabel)
    }

    private var receiptNumber: String {
        // Human-readable receipt number from item UUID + purchase date
        let uuid = item.id.uuidString.prefix(8).uppercased()
        let year = Calendar.current.component(.year, from: item.purchaseDate)
        return "\(year)-\(uuid)"
    }

    // MARK: - Hero Countdown
    //
    // The emotional anchor. Huge serif numeral for days remaining.
    // This is THE signature of the app.

    @ViewBuilder
    private var heroCountdown: some View {
        if item.isReturned {
            returnedStamp
        } else if let days = item.returnDaysRemaining, days >= 0 {
            countdownDisplay(
                number: days,
                label: days == 1 ? "DAY" : "DAYS",
                caption: days == 0 ? "Final day to return" : "until return window closes",
                color: item.urgencyLevel == .critical ? RFColors.signal : RFColors.ink
            )
        } else if let days = item.warrantyDaysRemaining, days >= 0 {
            countdownDisplay(
                number: days,
                label: days == 1 ? "DAY" : "DAYS",
                caption: "of warranty coverage",
                color: RFColors.ember
            )
        } else {
            EmptyView()
        }
    }

    private func countdownDisplay(number: Int, label: String, caption: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text("\(number)")
                    .font(.system(size: 128, weight: .regular, design: .serif))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text(label)
                    .font(.system(size: 24, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(color)
            }

            Text(caption)
                .font(.system(size: 13, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.mute)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(number) \(label.lowercased()) \(caption)")
    }

    private var returnedStamp: some View {
        VStack(spacing: 14) {
            Text("RETURNED")
                .font(.system(size: 48, weight: .regular, design: .serif))
                .tracking(6)
                .foregroundStyle(RFColors.signal)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .overlay(
                    Rectangle().stroke(RFColors.signal, lineWidth: 2.5)
                )
                .rotationEffect(.degrees(-4))

            if let returnedAt = item.returnedAt {
                Text("Marked returned \(returnedAt.formatted(date: .long, time: .shortened))")
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
            } else {
                Text("This receipt has been closed.")
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
            }

            if let proofData = item.returnProofImageData,
               let proofImage = UIImage(data: proofData) {
                VStack(alignment: .leading, spacing: 10) {
                    RFEyebrow(text: "Proof of return")
                    Image(uiImage: proofImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .overlay(Rectangle().stroke(RFColors.ink, lineWidth: 0.75))
                        .accessibilityLabel("Proof of return photo")
                }
                .padding(.top, 8)
            }

            if !item.returnProofNote.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Rectangle()
                        .fill(RFColors.ink)
                        .frame(width: 2)
                    Text(item.returnProofNote)
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(RFColors.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineSpacing(3)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(returnedStampAccessibilityLabel)
        .accessibilityAddTraits(.isHeader)
    }

    private var returnedStampAccessibilityLabel: String {
        var parts = ["Returned"]
        if let returnedAt = item.returnedAt {
            parts.append("on \(returnedAt.formatted(date: .long, time: .shortened))")
        }
        if item.returnProofImageData != nil { parts.append("with photo proof") }
        if !item.returnProofNote.isEmpty { parts.append("with note: \(item.returnProofNote)") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Metadata Table
    //
    // Tabular key-value rows in monospace. Reads like a printed receipt.

    private var metadataTable: some View {
        VStack(spacing: 10) {
            metaRow(label: "Date", value: item.purchaseDate.formatted(.dateTime.month(.abbreviated).day().year()))
            metaRow(label: "Store", value: item.storeName)
            if item.priceCents > 0 {
                metaRow(label: "Price", value: item.formattedPrice, bold: true)
            }
            if let returnEnd = item.returnWindowEndDate {
                metaRow(label: "Return by", value: returnEnd.formatted(.dateTime.month(.abbreviated).day().year()),
                        color: item.urgencyLevel == .critical ? RFColors.signal : RFColors.ink)
            }
            if let warrantyEnd = item.warrantyEndDate {
                metaRow(label: "Warranty", value: warrantyEnd.formatted(.dateTime.month(.abbreviated).day().year()))
            }
        }
    }

    private func metaRow(label: String, value: String, bold: Bool = false, color: Color = RFColors.ink) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label.uppercased())
                .font(RFFont.mono(10))
                .tracking(1.4)
                .foregroundStyle(RFColors.mute)
                .frame(width: 90, alignment: .leading)

            // Dot-leader between label and value — classic ledger style
            LeaderDots()

            Text(value)
                .font(bold ? RFFont.monoBold(13) : RFFont.mono(13))
                .foregroundStyle(color)
        }
    }

    // MARK: - Timeline Section

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            RFEyebrow(text: "Time remaining")

            if item.returnWindowEndDate != nil {
                timelineBar(
                    label: "Return",
                    progress: item.returnWindowProgress,
                    daysRemaining: item.returnDaysRemaining,
                    isOpen: item.isReturnWindowOpen,
                    isClaimed: item.isReturned,
                    color: item.urgencyLevel == .critical ? RFColors.signal : RFColors.ink
                )
            }

            if item.warrantyEndDate != nil {
                timelineBar(
                    label: "Warranty",
                    progress: item.warrantyProgress,
                    daysRemaining: item.warrantyDaysRemaining,
                    isOpen: item.isWarrantyActive,
                    isClaimed: item.isWarrantyClaimed,
                    color: RFColors.ember
                )
            }
        }
    }

    private func timelineBar(label: String, progress: Double, daysRemaining: Int?, isOpen: Bool, isClaimed: Bool, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(RFColors.ink)
                Spacer()
                if isClaimed {
                    Text("CLOSED")
                        .font(RFFont.mono(10))
                        .tracking(1.4)
                        .foregroundStyle(RFColors.mute)
                } else if let days = daysRemaining, days > 0 {
                    Text("\(days) DAYS LEFT")
                        .font(RFFont.mono(10))
                        .tracking(1.2)
                        .foregroundStyle(color)
                } else if !isOpen {
                    Text("EXPIRED")
                        .font(RFFont.mono(10))
                        .tracking(1.4)
                        .foregroundStyle(RFColors.mute)
                }
            }
            RFProgressBar(progress: progress, color: color, height: 1.5)
        }
    }

    // MARK: - Return Advice Block
    //
    // Editorial pull-quote style: italic serif advice with a red initial cap.

    private func returnAdviceBlock(_ advice: ReturnDecisionEngine.ReturnAdvice) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            RFEyebrow(text: advice.recommendation.rawValue)

            Text(advice.reasoning)
                .font(.system(size: 18, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.ink)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !advice.tips.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(advice.tips.prefix(3), id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Text("—")
                                .font(.system(size: 13, weight: .regular, design: .serif))
                                .foregroundStyle(RFColors.mute)
                            Text(tip)
                                .font(.system(size: 13, weight: .regular, design: .serif))
                                .foregroundStyle(RFColors.ink)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Policy Block
    //
    // Block-quote: indented with a left rule, italic serif copy.

    private var policyBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            RFEyebrow(text: "Store return policy")

            HStack(alignment: .top, spacing: 14) {
                Rectangle()
                    .fill(RFColors.ink)
                    .frame(width: 2)

                VStack(alignment: .leading, spacing: 10) {
                    Text("\u{201C}\(item.returnPolicyDescription)\u{201D}")
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(RFColors.ink)
                        .lineSpacing(3)

                    Text("— \(item.storeName)")
                        .font(RFFont.mono(10))
                        .tracking(1.2)
                        .foregroundStyle(RFColors.mute)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !item.returnRequirements.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("To return, bring:")
                        .font(.system(size: 13, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(RFColors.mute)

                    ForEach(item.returnRequirements, id: \.self) { req in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(RFFont.mono(12))
                                .foregroundStyle(RFColors.ink)
                            Text(req)
                                .font(.system(size: 14, weight: .regular, design: .serif))
                                .foregroundStyle(RFColors.ink)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Item Photo

    private func itemPhotoSection(_ photo: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RFEyebrow(text: "Item")

            Image(uiImage: photo)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(Rectangle().stroke(RFColors.ink, lineWidth: 0.75))
                .accessibilityLabel("Photo of \(item.productName)")
        }
    }

    // MARK: - Calendar Block

    private var calendarBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            RFEyebrow(text: "Add to calendar")

            HStack(spacing: 10) {
                if item.isReturnWindowOpen && !calendarAddedReturn {
                    calendarButton(label: "Return deadline", icon: "calendar.badge.plus") {
                        Task {
                            calendarAddedReturn = await CalendarService.shared.addReturnDeadline(for: item)
                            if calendarAddedReturn { HapticsService.shared.playSuccess() }
                        }
                    }
                }

                if item.isWarrantyActive && !calendarAddedWarranty {
                    calendarButton(label: "Warranty expiry", icon: "calendar.badge.plus") {
                        Task {
                            calendarAddedWarranty = await CalendarService.shared.addWarrantyExpiry(for: item)
                            if calendarAddedWarranty { HapticsService.shared.playSuccess() }
                        }
                    }
                }
            }

            if calendarAddedReturn || calendarAddedWarranty {
                HStack(spacing: 6) {
                    Text("✓")
                        .font(RFFont.mono(12))
                        .foregroundStyle(RFColors.ink)
                    Text("Added to your calendar")
                        .font(.system(size: 13, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(RFColors.ink)
                }
            }
        }
    }

    private func calendarButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .regular))
                Text(label)
                    .font(.system(size: 13, weight: .regular, design: .serif))
            }
            .foregroundStyle(RFColors.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .overlay(Rectangle().stroke(RFColors.ink, lineWidth: 0.75))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Action Row
    //
    // Plain text actions in serif — not buttons with icon bubbles.
    // The primary action ("Return Mode") is the filled ink button.

    private var actionRow: some View {
        VStack(spacing: 14) {
            if item.isReturnWindowOpen {
                Button {
                    showingReturnMode = true
                    returnModeTip.invalidate(reason: .actionPerformed)
                } label: {
                    Text("Enter Return Mode")
                }
                .buttonStyle(RFPrimaryButtonStyle())
            }

            HStack(spacing: 20) {
                actionLink(label: "View receipt photo") { showingReceiptImage = true }

                if item.isWarrantyActive {
                    Text("·").foregroundStyle(RFColors.mute)
                    actionLink(label: "Claim warranty") {
                        item.isWarrantyClaimed = true
                        NotificationScheduler.shared.cancelNotifications(for: item.id)
                        if !item.isReturnWindowOpen {
                            LiveActivityManager.shared.endLiveActivity(for: item.id)
                        }
                        WidgetSyncService.sync(modelContext: modelContext)
                        HapticsService.shared.playSuccess()
                    }
                }

                Spacer()
            }

            HStack(spacing: 20) {
                if MFMailComposeViewController.canSendMail() {
                    actionLink(label: "Email details") { showingMailComposer = true }
                } else {
                    actionLink(label: "Share details") { shareItem() }
                }
                Spacer()
            }
        }
    }

    private func actionLink(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .italic()
                .underline()
                .foregroundStyle(RFColors.ink)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Notes

    private var notesBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            RFEyebrow(text: "Notes")

            TextField("Jot a note…", text: $item.notes, axis: .vertical)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.ink)
                .lineLimit(3...8)
                .padding(.vertical, 10)
                .overlay(
                    VStack {
                        Spacer()
                        RFHairline()
                    }
                )
        }
    }

    // MARK: - Footer Signature
    //
    // A tiny printed-at timestamp and an ornamental rule — closes the receipt.

    private var footerSignature: some View {
        VStack(spacing: 12) {
            Rectangle().fill(RFColors.ink).frame(height: 2)

            HStack {
                Text("FILED")
                    .font(RFFont.mono(9))
                    .tracking(1.6)
                    .foregroundStyle(RFColors.mute)
                Text(item.createdAt.formatted(.dateTime.month(.abbreviated).day().year().hour().minute()).uppercased())
                    .font(RFFont.mono(9))
                    .tracking(1.2)
                    .foregroundStyle(RFColors.mute)
                Spacer()
                Text("— END —")
                    .font(RFFont.mono(9))
                    .tracking(1.6)
                    .foregroundStyle(RFColors.mute)
            }
        }
    }

    // MARK: - Accessibility

    private var headerAccessibilityLabel: String {
        var label = "\(item.productName), \(item.storeName), purchased \(item.purchaseDate.formatted(date: .long, time: .omitted))"
        if item.priceCents > 0 { label += ", \(item.formattedPrice)" }
        if item.isGift { label += ", gift item" }
        return label
    }

    // MARK: - Receipt Image Sheet

    private var receiptImageSheet: some View {
        ReceiptImageSheetView(
            item: item,
            isPresented: $showingReceiptImage
        )
    }

    // MARK: - Actions

    private func deleteItem() {
        NotificationScheduler.shared.cancelNotifications(for: item.id)
        LiveActivityManager.shared.endLiveActivity(for: item.id)
        SpotlightIndexer.shared.removeItem(item.id)
        ImageStorageService.shared.deleteImage(relativePath: item.receiptImagePath)
        if let itemPath = item.itemImagePath {
            ImageStorageService.shared.deleteImage(relativePath: itemPath)
        }
        modelContext.delete(item)
        WidgetSyncService.sync(modelContext: modelContext)
        dismiss()
    }

    private func shareItem() {
        let text = """
        \(item.productName) — \(item.storeName)
        Purchased: \(item.purchaseDate.formatted(date: .long, time: .omitted))
        Price: \(item.formattedPrice)
        \(item.returnDaysRemaining.map { "Return window: \($0) days remaining" } ?? "Return window: Closed")
        \(item.warrantyDaysRemaining.map { "Warranty: \($0) days remaining" } ?? "")
        """

        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Leader Dots
//
// A row of dots that fills the remaining horizontal space between a left
// label and a right value — the classic ledger/invoice dot leader.

struct LeaderDots: View {
    var body: some View {
        GeometryReader { geo in
            let dot: CGFloat = 2
            let gap: CGFloat = 4
            let count = max(0, Int((geo.size.width + gap) / (dot + gap)))
            HStack(spacing: gap) {
                ForEach(0..<count, id: \.self) { _ in
                    Circle()
                        .fill(RFColors.rule)
                        .frame(width: dot, height: dot)
                }
            }
            .frame(height: geo.size.height, alignment: .bottom)
            .padding(.bottom, 3)
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }
}

// MARK: - Circular Score View (legacy — kept for compile compatibility)

struct CircularScoreView: View {
    let score: Int
    let color: Color

    var body: some View {
        ZStack {
            Rectangle()
                .stroke(RFColors.rule, lineWidth: 1)
            Text("\(score)")
                .font(.system(size: 12, weight: .regular, design: .serif))
                .foregroundStyle(RFColors.ink)
        }
        .frame(width: 36, height: 36)
    }
}

// MARK: - Receipt Image Sheet

struct ReceiptImageSheetView: View {
    let item: ReceiptItem
    @Binding var isPresented: Bool
    @State private var loadedImage: UIImage?

    var body: some View {
        NavigationStack {
            Group {
                if let image = loadedImage {
                    ScrollView {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding()
                            .accessibilityLabel("Receipt photo for \(item.productName)")
                    }
                    .background(RFColors.paper)
                } else {
                    ContentUnavailableView("No Receipt Image", systemImage: "photo")
                        .background(RFColors.paper)
                }
            }
            .navigationTitle("Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { isPresented = false }
                }
            }
            .task {
                loadedImage = await ImageStorageService.shared.loadReceiptImage(for: item)
            }
        }
    }
}

// MARK: - Mail Composer (MessageUI)

struct MailComposerView: UIViewControllerRepresentable {
    let item: ReceiptItem

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator

        let action = item.isGift ? "Exchange" : "Return"
        composer.setSubject("\(action) Details: \(item.productName)")

        let body = """
        <h2>\(item.productName)</h2>
        <p><strong>Store:</strong> \(item.storeName)</p>
        <p><strong>Purchased:</strong> \(item.purchaseDate.formatted(date: .long, time: .omitted))</p>
        <p><strong>Price:</strong> \(item.formattedPrice)</p>
        <hr>
        <p><strong>Return window:</strong> \(item.returnDaysRemaining.map { "\($0) days remaining" } ?? "Closed")</p>
        <p><strong>Warranty:</strong> \(item.warrantyDaysRemaining.map { "\($0) days remaining" } ?? "N/A")</p>
        \(item.returnPolicyDescription.isEmpty ? "" : "<hr><p><strong>Return Policy:</strong> \(item.returnPolicyDescription)</p>")
        \(item.returnRequirements.isEmpty ? "" : "<p><strong>What to bring:</strong></p><ul>\(item.returnRequirements.map { "<li>\($0)</li>" }.joined())</ul>")
        <br><p><em>Sent from Receipt Folder</em></p>
        """

        composer.setMessageBody(body, isHTML: true)

        if let image = ImageStorageService.shared.loadReceiptImageSync(for: item),
           let data = image.jpegData(compressionQuality: 0.7) {
            composer.addAttachmentData(data, mimeType: "image/jpeg", fileName: "receipt.jpg")
        }

        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}
