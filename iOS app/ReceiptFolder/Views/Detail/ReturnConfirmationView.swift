import SwiftUI
import SwiftData
import PhotosUI

/// Presented immediately after the user marks an item returned.
///
/// The mark-returned action has already committed. This sheet is for the
/// one-and-only-chance moment where a user can capture *proof* — the store's
/// return receipt, the item being handed over, an employee badge — that they
/// can surface later if the retailer disputes the refund.
///
/// Capture is entirely optional. "Skip" is a first-class action. But even a
/// single photo + a short note makes the proof 10x stronger than a customer's
/// memory alone. No competitor in the category offers this.
struct ReturnConfirmationView: View {
    @Bindable var item: ReceiptItem
    @Environment(\.dismiss) private var dismiss

    @State private var proofImage: UIImage?
    @State private var photoSelection: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    masthead
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 24)

                    proofSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    RFPerforation()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    noteSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    Spacer().frame(height: 32)

                    primaryActions
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
            }
            .background(RFColors.paper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { saveAndDismiss(skipProof: true) }
                        .accessibilityIdentifier("button.skipProof")
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                ReceiptCameraView(
                    sourceType: .camera,
                    onImageCaptured: { image in
                        showingCamera = false
                        proofImage = image
                    },
                    onCancel: { showingCamera = false }
                )
                .ignoresSafeArea()
            }
            .onChange(of: photoSelection) { _, newValue in
                Task { await loadSelectedPhoto(newValue) }
            }
        }
    }

    // MARK: - Masthead

    private var masthead: some View {
        VStack(spacing: 10) {
            HStack {
                Text("PROOF OF RETURN")
                    .font(RFFont.mono(10))
                    .tracking(2.0)
                    .foregroundStyle(RFColors.signal)
                Spacer()
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).uppercased())
                    .font(RFFont.mono(10))
                    .tracking(1.2)
                    .foregroundStyle(RFColors.mute)
            }
            Rectangle().fill(RFColors.signal).frame(height: 2)

            HStack(alignment: .firstTextBaseline) {
                Text("Proof")
                    .font(RFFont.hero(44))
                    .foregroundStyle(RFColors.ink)
                Text("of Return")
                    .font(.system(size: 44, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.signal)
                Spacer()
            }
            .minimumScaleFactor(0.6)
            .lineLimit(1)

            Text("If the retailer later disputes the refund, a photo of the return receipt plus a short note is the strongest evidence you can hold onto.")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.mute)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineSpacing(3)

            RFHairline()
        }
    }

    // MARK: - Proof capture

    private var proofSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            RFEyebrow(text: "Capture proof — optional")

            if let proofImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: proofImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .clipped()
                        .overlay(Rectangle().stroke(RFColors.ink, lineWidth: 0.75))

                    Button {
                        self.proofImage = nil
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
                    .accessibilityLabel("Remove proof photo")
                }
            } else {
                HStack(spacing: 10) {
                    Button {
                        showingCamera = true
                    } label: {
                        captureButton(icon: "camera", label: "Camera")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("button.proofCamera")

                    PhotosPicker(selection: $photoSelection, matching: .images) {
                        captureButton(icon: "photo.on.rectangle", label: "Library")
                    }
                    .accessibilityIdentifier("button.proofLibrary")
                }
                .frame(maxWidth: .infinity)
            }

            Text("A photo of the return-counter receipt, the item being handed over, or the refund confirmation — all strong proof.")
                .font(.system(size: 12, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.mute)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func captureButton(icon: String, label: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(RFColors.ink)
            Text(label)
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

    // MARK: - Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            RFEyebrow(text: "Note — optional")
            TextField("Refund amount, employee name, card last-4…", text: $note, axis: .vertical)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.ink)
                .lineLimit(3...6)
                .padding(.vertical, 10)
                .overlay(
                    VStack {
                        Spacer()
                        RFHairline()
                    }
                )
                .accessibilityIdentifier("field.proofNote")
        }
    }

    // MARK: - Actions

    private var primaryActions: some View {
        VStack(spacing: 10) {
            Button { saveAndDismiss(skipProof: false) } label: {
                Text("Save proof")
            }
            .buttonStyle(RFPrimaryButtonStyle())
            .disabled(proofImage == nil && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("button.saveProof")

            Text("Proof is stored on your device and syncs to your other devices via iCloud if enabled.")
                .font(RFFont.mono(10))
                .tracking(1.0)
                .foregroundStyle(RFColors.mute)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
    }

    // MARK: - Side effects

    @MainActor
    private func loadSelectedPhoto(_ selection: PhotosPickerItem?) async {
        guard let selection else { return }
        if let data = try? await selection.loadTransferable(type: Data.self),
           let uiImage = UIImage(data: data) {
            proofImage = uiImage
        }
    }

    private func saveAndDismiss(skipProof: Bool) {
        if !skipProof {
            if let image = proofImage,
               let compressed = ImageCompressionService.adaptiveCompress(image: image) {
                item.returnProofImageData = compressed
            }
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedNote.isEmpty {
                item.returnProofNote = trimmedNote
            }
        }
        if item.returnedAt == nil {
            item.returnedAt = .now
        }
        HapticsService.shared.playSuccess()
        dismiss()
    }
}
