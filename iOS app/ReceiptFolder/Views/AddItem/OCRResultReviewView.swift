import SwiftUI

/// Review screen — rendered as a "galley proof" of the receipt about to be
/// filed. Fields appear as underline-input lines with mono labels above,
/// separated by hairlines, the way a printed form would read.
struct OCRResultReviewView: View {
    @Binding var productName: String
    @Binding var storeName: String
    @Binding var purchaseDate: Date
    @Binding var priceString: String
    @Binding var warrantyYears: Int
    @Binding var isGift: Bool
    @Binding var selectedCategory: String?
    @Binding var itemImage: UIImage?
    @Binding var returnDaysManual: Int

    let matchedPolicy: StorePolicy?
    var capturedImage: UIImage? = nil
    let onSelectStore: () -> Void

    @State private var showingItemCamera = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                galleyProofBanner
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                if let image = capturedImage {
                    receiptThumbnail(image: image)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    RFPerforation().padding(.horizontal, 20).padding(.bottom, 20)
                }

                productSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                RFPerforation().padding(.horizontal, 20).padding(.bottom, 20)

                storeSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                RFPerforation().padding(.horizontal, 20).padding(.bottom, 20)

                dateSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                RFPerforation().padding(.horizontal, 20).padding(.bottom, 20)

                warrantySection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                RFPerforation().padding(.horizontal, 20).padding(.bottom, 20)

                giftSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                RFPerforation().padding(.horizontal, 20).padding(.bottom, 20)

                itemPhotoSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
        .background(RFColors.paper)
        .sheet(isPresented: $showingItemCamera) {
            ReceiptCameraView(
                sourceType: .photoLibrary,
                onImageCaptured: { image in
                    showingItemCamera = false
                    itemImage = image
                },
                onCancel: { showingItemCamera = false }
            )
        }
    }

    // MARK: - Galley Proof Banner

    private var galleyProofBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(RFColors.ink)
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("GALLEY PROOF")
                    .font(RFFont.mono(10))
                    .tracking(1.8)
                    .foregroundStyle(RFColors.ink)
                Text("Review the transcribed details below. Correct anything that reads wrong before filing.")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Receipt Thumbnail

    private func receiptThumbnail(image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RFEyebrow(text: "Original receipt")

            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()
                .overlay(Rectangle().stroke(RFColors.ink, lineWidth: 0.75))
        }
    }

    // MARK: - Product

    private var productSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            RFEyebrow(text: "Item")

            galleyField(label: "Name", placeholder: "Product name", text: $productName, capitalization: .words)
            galleyField(label: "Price", placeholder: "0.00", text: $priceString, keyboardType: .decimalPad)
        }
    }

    // MARK: - Store

    private var storeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                RFEyebrow(text: "Merchant")
                Spacer()
                if matchedPolicy != nil {
                    Text("POLICY MATCHED")
                        .font(RFFont.mono(9))
                        .tracking(1.4)
                        .foregroundStyle(RFColors.ink)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .overlay(Rectangle().stroke(RFColors.ink, lineWidth: 0.75))
                }
            }

            HStack(spacing: 12) {
                if !storeName.isEmpty {
                    StoreAvatar(name: storeName, size: 36)
                }
                galleyField(label: "Store", placeholder: "Store name", text: $storeName, capitalization: .words)
            }

            if let policy = matchedPolicy {
                storePolicyRow(policy: policy)

                if !policy.categoryOverrides.isEmpty {
                    categoryPicker(policy: policy)
                }
            } else {
                manualReturnWindowRow

                Button(action: onSelectStore) {
                    HStack {
                        Text("Browse store directory")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .italic()
                            .underline()
                            .foregroundStyle(RFColors.ink)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(RFColors.ink)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // When no policy is matched, let the user set the return window length
    // manually so the app doesn't silently default to 30 days.
    private var manualReturnWindowRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("RETURN WINDOW")
                .font(RFFont.mono(10))
                .tracking(1.4)
                .foregroundStyle(RFColors.mute)

            LeaderDots()

            Text("\(returnDaysManual) day\(returnDaysManual == 1 ? "" : "s")")
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundStyle(RFColors.ink)

            // Fixed step of 1 — a dynamic step size made values between 26 and
            // 29 unreachable once the user had crossed above 30.
            Stepper("", value: $returnDaysManual, in: 0...365, step: 1)
                .labelsHidden()
        }
    }

    private func storePolicyRow(policy: StorePolicy) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("RETURN WINDOW")
                .font(RFFont.mono(10))
                .tracking(1.4)
                .foregroundStyle(RFColors.mute)

            LeaderDots()

            Group {
                if policy.isUnlimitedReturn {
                    Text("Anytime")
                        .foregroundStyle(RFColors.ink)
                } else if policy.isNonReturnable {
                    Text("Non-returnable")
                        .foregroundStyle(RFColors.signal)
                } else {
                    Text("\(policy.defaultReturnDays) days")
                        .foregroundStyle(RFColors.ink)
                }
            }
            .font(.system(size: 15, weight: .regular, design: .serif))
        }
    }

    private func categoryPicker(policy: StorePolicy) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("CATEGORY")
                .font(RFFont.mono(10))
                .tracking(1.4)
                .foregroundStyle(RFColors.mute)

            LeaderDots()

            Picker("Item category", selection: $selectedCategory) {
                Text("General (\(policy.defaultReturnDays)d)")
                    .tag(nil as String?)
                ForEach(policy.categoryOverrides, id: \.category) { override in
                    Text("\(override.category) (\(override.returnDays)d)")
                        .tag(override.category as String?)
                }
            }
            .pickerStyle(.menu)
            .tint(RFColors.ink)
        }
    }

    // MARK: - Date

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            RFEyebrow(text: "Purchase Date")

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("DATE")
                    .font(RFFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.mute)

                LeaderDots()

                DatePicker("", selection: $purchaseDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(RFColors.ink)
            }
        }
    }

    // MARK: - Warranty

    private var warrantySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            RFEyebrow(text: "Warranty")

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("COVERAGE")
                    .font(RFFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.mute)

                LeaderDots()

                Text("\(warrantyYears) year\(warrantyYears == 1 ? "" : "s")")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(RFColors.ink)

                Stepper("", value: $warrantyYears, in: 0...10)
                    .labelsHidden()
            }
        }
    }

    // MARK: - Gift

    private var giftSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("MARKED AS GIFT")
                    .font(RFFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.mute)

                LeaderDots()

                Toggle("", isOn: $isGift)
                    .labelsHidden()
                    .tint(RFColors.ink)
            }

            if isGift {
                Text("Alerts will read “exchange” in place of “return for refund.”")
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
            }
        }
    }

    // MARK: - Item Photo

    private var itemPhotoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            RFEyebrow(text: "Item photograph · optional")

            if let photo = itemImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipped()
                        .overlay(Rectangle().stroke(RFColors.ink, lineWidth: 0.75))

                    Button {
                        itemImage = nil
                    } label: {
                        Text("REMOVE")
                            .font(RFFont.mono(10))
                            .tracking(1.4)
                            .foregroundStyle(RFColors.paper)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RFColors.ink)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .accessibilityLabel("Remove item photo")
                }
            } else {
                Button {
                    showingItemCamera = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "camera")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(RFColors.ink)
                        Text("Add a photo of the item")
                            .font(.system(size: 13, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(RFColors.mute)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .overlay(
                        Rectangle()
                            .strokeBorder(style: StrokeStyle(lineWidth: 0.75, dash: [5, 4]))
                            .foregroundStyle(RFColors.ink.opacity(0.6))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Galley field
    //
    // An underline-input row: mono label on a line above, serif text below,
    // a hairline rule under the input. Feels like a typewriter form.

    private func galleyField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        capitalization: TextInputAutocapitalization? = nil,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(RFFont.mono(10))
                .tracking(1.4)
                .foregroundStyle(RFColors.mute)

            TextField(placeholder, text: text)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .foregroundStyle(RFColors.ink)
                .textInputAutocapitalization(capitalization ?? .never)
                .keyboardType(keyboardType)
                .padding(.vertical, 6)
                .overlay(
                    VStack {
                        Spacer()
                        Rectangle().fill(RFColors.ink).frame(height: 0.75)
                    }
                )
                // Stable identifier for UI tests — label text changes with
                // locale/uppercase rendering, identifiers don't.
                .accessibilityIdentifier("field.\(label.lowercased().replacingOccurrences(of: " ", with: ""))")
        }
    }
}
