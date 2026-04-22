import SwiftUI
import SwiftData
import TipKit
import CoreTransferable

struct ReceiptDraft: Codable {
    var productName: String
    var storeName: String
    var purchaseDate: Date
    var priceString: String
    var warrantyYears: Int
    var isGift: Bool
    var hasDraft: Bool { !productName.isEmpty || !storeName.isEmpty || !priceString.isEmpty }
}

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: AddStep = .capture
    @State private var capturedImage: UIImage?
    @State private var isProcessingOCR = false
    @State private var storeAddress: String?

    // Form fields
    @AppStorage("defaultWarrantyYears") private var defaultWarrantyYears = 1
    @State private var productName = ""
    @State private var storeName = ""
    @State private var purchaseDate = Date.now
    @State private var priceString = ""
    @State private var warrantyYears = 1
    @State private var isGift = false
    @State private var selectedCategory: String?
    @State private var matchedPolicy: StorePolicy?
    @State private var returnDaysManual = 30
    @State private var showingStorePicker = false

    // Item photo
    @State private var itemImage: UIImage?

    // Image source
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false

    // Draft restore
    @State private var showingDraftRestore = false
    @State private var showingCancelConfirmation = false
    private static let draftKey = "receiptDraft"

    // Validation / save error feedback
    @State private var saveErrorMessage: String?
    @State private var isSaving = false

    // Processing animation
    @State private var pulseScale: CGFloat = 1.0
    @State private var dotCount = 0
    @State private var dotTimer: Timer?

    // In-flight async work — cancelled on view disappear so we never write
    // state to a view that's tearing down.
    @State private var ocrTask: Task<Void, Never>?
    @State private var saveTask: Task<Void, Never>?
    @State private var draftSaveTask: Task<Void, Never>?

    /// Set whenever we've intentionally cleared the draft (successful save,
    /// explicit discard). Prevents `.onDisappear` from re-writing the form
    /// state back into UserDefaults as a ghost draft.
    @State private var suppressDraftFlush = false

    private let scanTip = ScanReceiptTip()

    enum AddStep {
        case capture
        case processing
        case review
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .capture:
                    captureView
                case .processing:
                    processingView
                case .review:
                    reviewView
                }
            }
            .navigationTitle("Add Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        let hasDraftContent = !productName.isEmpty || !storeName.isEmpty || !priceString.isEmpty
                        if hasDraftContent && step == .review {
                            showingCancelConfirmation = true
                        } else {
                            Self.clearDraft()
                            suppressDraftFlush = true
                            dismiss()
                        }
                    }
                    .disabled(isSaving)
                }

                if step == .review {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveItem() }
                            .fontWeight(.semibold)
                            .disabled(productName.isEmpty || storeName.isEmpty || isSaving)
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                ReceiptCameraView(
                    sourceType: .camera,
                    onImageCaptured: { image in
                        showingCamera = false
                        handleCapturedImage(image)
                    },
                    onCancel: { showingCamera = false }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showingPhotoLibrary) {
                ReceiptCameraView(
                    sourceType: .photoLibrary,
                    onImageCaptured: { image in
                        showingPhotoLibrary = false
                        handleCapturedImage(image)
                    },
                    onCancel: { showingPhotoLibrary = false }
                )
            }
            .sheet(isPresented: $showingStorePicker) {
                storePickerSheet
            }
            .onChange(of: productName) { _, _ in scheduleDraftSave() }
            .onChange(of: storeName) { _, _ in scheduleDraftSave() }
            .onChange(of: priceString) { _, _ in scheduleDraftSave() }
            .onChange(of: isGift) { _, _ in scheduleDraftSave() }
            .onDisappear {
                // Cancel any in-flight async work so it can't mutate @State
                // after the sheet has been dismissed.
                ocrTask?.cancel()
                saveTask?.cancel()
                draftSaveTask?.cancel()
                stopDotAnimation()
                // Flush any pending draft — but only when we *haven't* already
                // cleared it intentionally (after save or explicit discard).
                // Otherwise we'd resurrect a ghost draft of a saved receipt.
                if !suppressDraftFlush {
                    saveDraft()
                }
            }
            .alert("Continue where you left off?", isPresented: $showingDraftRestore) {
                Button("Restore Draft") {
                    if let draft = loadDraft() {
                        restoreDraft(draft)
                    }
                }
                Button("Start Fresh", role: .destructive) {
                    Self.clearDraft()
                }
            }
            .confirmationDialog("Discard changes?", isPresented: $showingCancelConfirmation, titleVisibility: .visible) {
                Button("Save as Draft") {
                    saveDraft()
                    // Keep the flush allowed — we want the draft persisted.
                    dismiss()
                }
                Button("Discard", role: .destructive) {
                    Self.clearDraft()
                    suppressDraftFlush = true
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Couldn't save receipt", isPresented: .init(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "")
            }
        }
    }

    // MARK: - Capture Step
    //
    // Editorial submission desk: masthead, framed illustration, printed tip,
    // and three entry options as plain buttons.

    private var captureView: some View {
        ScrollView {
            VStack(spacing: 0) {
                captureMasthead
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 24)

                receiptFrame
                    .padding(.bottom, 28)

                tipCallout
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                RFPerforation()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                captureButtons
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
        .background(RFColors.paper)
        .onAppear {
            if matchedPolicy == nil {
                warrantyYears = defaultWarrantyYears
            }
            if loadDraft() != nil {
                showingDraftRestore = true
            }
        }
    }

    private var captureMasthead: some View {
        VStack(spacing: 10) {
            HStack {
                Text("SUBMISSION DESK")
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
                Text("New")
                    .font(RFFont.hero(44))
                    .foregroundStyle(RFColors.ink)
                Text("Entry")
                    .font(.system(size: 44, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.signal)
                Spacer()
            }

            HStack {
                Text("Submit a receipt for filing.")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
                Spacer()
            }

            RFHairline()
                .padding(.top, 2)
        }
    }

    private var receiptFrame: some View {
        ZStack {
            Rectangle()
                .stroke(RFColors.ink, lineWidth: 0.75)
                .frame(width: 200, height: 240)

            Rectangle()
                .stroke(RFColors.ink, lineWidth: 1.5)
                .frame(width: 168, height: 208)

            VStack(spacing: 10) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(RFColors.ink)
                Text("RECEIPT")
                    .font(RFFont.mono(10))
                    .tracking(2.0)
                    .foregroundStyle(RFColors.mute)
            }
        }
    }

    private var tipCallout: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(RFColors.ember)
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("A NOTE ON LIGHTING")
                    .font(RFFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.ember)
                Text("Clear, even light yields a cleaner scan. Ensure the store name, date, and total are visible in the frame.")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var captureButtons: some View {
        VStack(spacing: 12) {
            Button {
                showingCamera = true
            } label: {
                Text("Begin scan")
            }
            .buttonStyle(RFPrimaryButtonStyle())

            Button {
                showingPhotoLibrary = true
            } label: {
                Text("Choose from library")
            }
            .buttonStyle(RFSecondaryButtonStyle())

            Button {
                step = .review
            } label: {
                Text("Enter by hand")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .underline()
                    .foregroundStyle(RFColors.ink)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            .accessibilityLabel("Enter by hand")
            .accessibilityIdentifier("button.enterByHand")
        }
        .dropDestination(for: TransferableReceiptImage.self) { items, _ in
            guard let first = items.first else { return false }
            handleCapturedImage(first.image)
            return true
        }
        .accessibilityLabel("Receipt capture options")
        .accessibilityHint("Choose how to add your receipt photo, or drag and drop an image")
    }

    // MARK: - Processing Step
    //
    // Editorial "going to press" screen. A stamped frame with tick marks and
    // a mono running label. No gradients, no pulsing circles.

    private var processingView: some View {
        ZStack {
            RFColors.paper.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Text("READING")
                    .font(RFFont.mono(11))
                    .tracking(3.0)
                    .foregroundStyle(RFColors.mute)

                ZStack {
                    Rectangle()
                        .stroke(RFColors.ink, lineWidth: 1)
                        .frame(width: 180, height: 180)

                    Rectangle()
                        .stroke(RFColors.ink, lineWidth: 2.5)
                        .frame(width: reduceMotion ? 140 : 100 + (pulseScale * 40), height: reduceMotion ? 140 : 100 + (pulseScale * 40))
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulseScale)

                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48, weight: .regular))
                        .foregroundStyle(RFColors.ink)
                }
                .onAppear {
                    if !reduceMotion { pulseScale = 1 }
                }

                VStack(spacing: 6) {
                    Text("Transcribing receipt\(String(repeating: ".", count: dotCount))")
                        .font(RFFont.hero(28))
                        .foregroundStyle(RFColors.ink)
                        .contentTransition(.numericText())
                        .onAppear {
                            if !reduceMotion { startDotAnimation() }
                        }

                    Text("Extracting store, date, and total.")
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(RFColors.mute)
                }

                Spacer()

                RFPerforation().padding(.horizontal, 60)
                Spacer().frame(height: 20)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Processing receipt, please wait")
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Review Step

    private var reviewView: some View {
        OCRResultReviewView(
            productName: $productName,
            storeName: $storeName,
            purchaseDate: $purchaseDate,
            priceString: $priceString,
            warrantyYears: $warrantyYears,
            isGift: $isGift,
            selectedCategory: $selectedCategory,
            itemImage: $itemImage,
            returnDaysManual: $returnDaysManual,
            matchedPolicy: matchedPolicy,
            capturedImage: capturedImage,
            onSelectStore: { showingStorePicker = true }
        )
        .onChange(of: storeName) {
            let newPolicy = StorePolicyService.shared.findPolicy(storeName: storeName)
            if newPolicy?.name != matchedPolicy?.name {
                matchedPolicy = newPolicy
                if let policy = newPolicy {
                    warrantyYears = policy.defaultWarrantyYears
                }
            }
        }
    }

    // MARK: - Store Picker

    private var storePickerSheet: some View {
        StorePickerSheet { policy in
            storeName = policy.name
            matchedPolicy = policy
            warrantyYears = policy.defaultWarrantyYears
            showingStorePicker = false
        } onCancel: {
            showingStorePicker = false
        }
    }

    // MARK: - Helpers

    private func saveDraft() {
        let draft = ReceiptDraft(
            productName: productName,
            storeName: storeName,
            purchaseDate: purchaseDate,
            priceString: priceString,
            warrantyYears: warrantyYears,
            isGift: isGift
        )
        guard draft.hasDraft else { return }
        if let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: Self.draftKey)
        }
    }

    /// Coalesce per-keystroke drafts into one write per ~500ms of idle typing.
    /// `onDisappear` flushes whatever's pending, so we never lose data.
    private func scheduleDraftSave() {
        draftSaveTask?.cancel()
        draftSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            saveDraft()
        }
    }

    private func loadDraft() -> ReceiptDraft? {
        guard let data = UserDefaults.standard.data(forKey: Self.draftKey),
              let draft = try? JSONDecoder().decode(ReceiptDraft.self, from: data),
              draft.hasDraft else { return nil }
        return draft
    }

    private func restoreDraft(_ draft: ReceiptDraft) {
        productName = draft.productName
        storeName = draft.storeName
        purchaseDate = draft.purchaseDate
        priceString = draft.priceString
        warrantyYears = draft.warrantyYears
        isGift = draft.isGift
        if !storeName.isEmpty {
            matchedPolicy = StorePolicyService.shared.findPolicy(storeName: storeName)
        }
        step = .review
    }

    private static func clearDraft() {
        UserDefaults.standard.removeObject(forKey: draftKey)
    }

    /// Parses user-entered price to cents, honouring the current locale's
    /// decimal and grouping separators. Falls back to a US-style parse if the
    /// locale-aware parse fails (e.g., user typed "$19.99" in a DE locale).
    static func parsePriceToCents(_ input: String) -> Int {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return 0 }

        let decimal = Locale.current.decimalSeparator ?? "."
        let grouping = Locale.current.groupingSeparator ?? ","

        // Strip everything except digits and the two separators.
        let allowed = Set("0123456789\(decimal)\(grouping)")
        let filtered = String(trimmed.filter { allowed.contains($0) })

        // Remove grouping, then normalize decimal to ".".
        let normalized = filtered
            .replacingOccurrences(of: grouping, with: "")
            .replacingOccurrences(of: decimal, with: ".")

        if let dollars = Double(normalized) {
            return Int((dollars * 100).rounded())
        }

        // Fallback: US format parse ("1,234.56").
        let usFallback = trimmed
            .replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        if let dollars = Double(usFallback) {
            return Int((dollars * 100).rounded())
        }
        return 0
    }

    private func startDotAnimation() {
        stopDotAnimation()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            Task { @MainActor in
                if step != .processing {
                    timer.invalidate()
                    return
                }
                withAnimation(.easeInOut(duration: 0.2)) {
                    dotCount = (dotCount % 3) + 1
                }
            }
        }
        dotTimer = timer
    }

    private func stopDotAnimation() {
        dotTimer?.invalidate()
        dotTimer = nil
    }

    // MARK: - Actions

    private func handleCapturedImage(_ image: UIImage) {
        // Reset per-scan state so a previous scan's data doesn't bleed through
        // into the next receipt (store address, matched policy, selected category).
        storeAddress = nil
        matchedPolicy = nil
        selectedCategory = nil
        capturedImage = image
        step = .processing
        scanTip.invalidate(reason: .actionPerformed)

        ocrTask?.cancel()
        ocrTask = Task {
            do {
                let result = try await OCRService.extractText(from: image)
                if Task.isCancelled { return }

                storeAddress = result.storeAddress

                if let store = result.storeName {
                    storeName = store
                    matchedPolicy = StorePolicyService.shared.findPolicyFromOCRText(result.rawText)
                    if let policy = matchedPolicy {
                        storeName = policy.name
                        warrantyYears = policy.defaultWarrantyYears
                    }
                }

                if let date = result.purchaseDate {
                    purchaseDate = date
                }

                if let total = result.totalAmount {
                    let dollars = Double(total) / 100.0
                    priceString = String(format: "%.2f", dollars)
                }

                if Task.isCancelled { return }
                step = .review
                stopDotAnimation()
                UIAccessibility.post(notification: .announcement, argument: "Receipt scanned successfully. Review the details.")
            } catch {
                if Task.isCancelled { return }
                HapticsService.shared.playError()
                step = .review
                stopDotAnimation()
                UIAccessibility.post(notification: .announcement, argument: "Could not read receipt. Please enter details manually.")
            }
        }
    }

    private func saveItem() {
        guard !isSaving else { return }

        let priceCents = Self.parsePriceToCents(priceString)

        let trimmedName = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStore = storeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let errors = ReceiptItem.validate(productName: trimmedName, storeName: trimmedStore, priceCents: priceCents, purchaseDate: purchaseDate)
        guard errors.isEmpty else {
            HapticsService.shared.playError()
            saveErrorMessage = errors.compactMap(\.errorDescription).joined(separator: "\n")
            return
        }

        isSaving = true

        // Snapshot images for background compression. UIImage is not Sendable but
        // compression only reads pixel data, so detached task with a local copy is safe.
        let receiptSnapshot = capturedImage
        let itemSnapshot = itemImage

        saveTask?.cancel()
        saveTask = Task { @MainActor in
            // Compress off the main actor so large photos don't hitch the UI.
            let receiptData: Data? = await Task.detached(priority: .userInitiated) {
                guard let img = receiptSnapshot else { return nil }
                return ImageCompressionService.adaptiveCompress(image: img)
            }.value

            // If the user cancelled / the view was dismissed during compression,
            // bail before touching the model context.
            if Task.isCancelled { isSaving = false; return }

            let itemData: Data? = await Task.detached(priority: .userInitiated) {
                guard let img = itemSnapshot else { return nil }
                return ImageCompressionService.adaptiveCompress(image: img)
            }.value

            if Task.isCancelled { isSaving = false; return }

            let dates: ReturnWindowCalculator.Result
            if let policy = matchedPolicy {
                dates = ReturnWindowCalculator.calculate(
                    purchaseDate: purchaseDate,
                    policy: policy,
                    categoryOverride: selectedCategory,
                    warrantyYears: warrantyYears
                )
            } else {
                dates = ReturnWindowCalculator.calculateManual(
                    purchaseDate: purchaseDate,
                    returnDays: returnDaysManual,
                    warrantyYears: warrantyYears
                )
            }

            let item = ReceiptItem(
                productName: trimmedName,
                storeName: trimmedStore,
                purchaseDate: purchaseDate,
                priceCents: priceCents,
                receiptImageData: receiptData,
                itemImageData: itemData,
                returnWindowEndDate: dates.returnEndDate,
                warrantyEndDate: dates.warrantyEndDate,
                returnPolicyDescription: dates.policyDescription,
                returnRequirements: dates.returnRequirements,
                isGift: isGift,
                storeAddress: storeAddress
            )

            modelContext.insert(item)
            do {
                try modelContext.save()
            } catch {
                HapticsService.shared.playError()
                modelContext.delete(item)
                saveErrorMessage = "Save failed: \(error.localizedDescription)"
                RFLogger.storage.error("Receipt save failed: \(error)")
                isSaving = false
                return
            }

            NotificationScheduler.shared.scheduleNotifications(for: item)
            SpotlightIndexer.shared.indexItem(item)
            LiveActivityManager.shared.startLiveActivity(for: item)
            WidgetSyncService.sync(modelContext: modelContext)
            WidgetTip.hasAddedItem = true
            HapticsService.shared.playSuccess()

            Self.clearDraft()
            // Reset flags BEFORE dismiss so we never mutate @State on a view
            // that's already tearing down, and so onDisappear doesn't flush
            // the just-saved form back as a ghost draft.
            suppressDraftFlush = true
            isSaving = false
            dismiss()
        }
    }
}
