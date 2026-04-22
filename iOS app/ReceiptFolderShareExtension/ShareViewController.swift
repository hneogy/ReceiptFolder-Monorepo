import UIKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Share Extension principal class. iOS hands us an `extensionContext` whose
/// input items contain whatever the host app shared — for Mail, that's the
/// plain-text or HTML body of the email. We pipe it through
/// `EmailReceiptParser`, render a SwiftUI review sheet, and on confirmation
/// save a `ReceiptItem` into the same CloudKit-backed store the main app
/// uses. Close returns to Mail.
final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.961, green: 0.945, blue: 0.910, alpha: 1) // paper
        Task { await loadAndPresent() }
    }

    // MARK: - Load shared content

    @MainActor
    private func loadAndPresent() async {
        let (subject, body) = await extractSubjectAndBody()
        // Async variant first-tries templated retailer parsers, then falls
        // back to the Foundation Models on-device LLM for unrecognised
        // senders on iOS 26+. If both fail the ReviewView handles the
        // blank-draft case by letting the user fill the fields by hand.
        let parsed = await EmailReceiptParser.parseWithAIFallback(subject: subject, body: body)

        let host = UIHostingController(rootView: ShareReviewView(
            subject: subject,
            body: body,
            initialParse: parsed,
            onConfirm: { [weak self] finalReceipt in
                self?.save(receipt: finalReceipt)
            },
            onCancel: { [weak self] in
                self?.complete(success: false)
            }
        ))
        host.modalPresentationStyle = .fullScreen
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    /// Walks the share extension's input items and returns the best subject +
    /// body pair we can get from the host. For Mail this is the selected
    /// text. For any other text source, it's whatever the user shared.
    private func extractSubjectAndBody() async -> (subject: String, body: String) {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            return ("", "")
        }

        var subject = ""
        var body = ""

        for item in extensionItems {
            if subject.isEmpty, let attributed = item.attributedContentText?.string {
                subject = attributed
            }
            for provider in (item.attachments ?? []) {
                if provider.hasItemConformingToTypeIdentifier(UTType.html.identifier) {
                    if let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.html.identifier),
                       let html = loaded as? String {
                        body = html
                        break
                    }
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier),
                       let text = loaded as? String {
                        body = text
                        break
                    }
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
                       let url = loaded as? URL {
                        body = url.absoluteString
                    }
                }
            }
        }
        return (subject, body)
    }

    // MARK: - Save + dismiss

    @MainActor
    private func save(receipt: EmailReceiptParser.ParsedReceipt) {
        do {
            let container = try Self.sharedContainer()
            let context = ModelContext(container)
            let now = Date.now

            // Use StorePolicyService-like defaults — for Month 2 we save
            // without policy-matching; the app will fill the return window
            // next time it opens via an idempotent pass. Keeps the
            // extension lightweight.
            let item = ReceiptItem(
                productName: receipt.productName,
                storeName: receipt.storeName,
                purchaseDate: receipt.purchaseDate ?? now,
                priceCents: receipt.priceCents ?? 0,
                returnWindowEndDate: nil,
                warrantyEndDate: nil,
                returnPolicyDescription: "",
                returnRequirements: []
            )
            context.insert(item)
            try context.save()
            complete(success: true)
        } catch {
            complete(success: false)
        }
    }

    private func complete(success: Bool) {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    // MARK: - Container

    private static func sharedContainer() throws -> ModelContainer {
        let schema = Schema([ReceiptItem.self])
        if let cloud = try? ModelContainer(
            for: schema,
            configurations: ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private(AppGroupConstants.cloudKitContainerID)
            )
        ) {
            return cloud
        }
        return try ModelContainer(for: schema)
    }
}

// MARK: - Review UI (SwiftUI)

private struct ShareReviewView: View {
    let subject: String
    let bodyText: String
    let initialParse: EmailReceiptParser.ParsedReceipt?
    let onConfirm: (EmailReceiptParser.ParsedReceipt) -> Void
    let onCancel: () -> Void

    @State private var storeName: String
    @State private var productName: String
    @State private var purchaseDate: Date
    @State private var priceString: String

    init(
        subject: String,
        body: String,
        initialParse: EmailReceiptParser.ParsedReceipt?,
        onConfirm: @escaping (EmailReceiptParser.ParsedReceipt) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.subject = subject
        self.bodyText = body
        self.initialParse = initialParse
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _storeName = State(initialValue: initialParse?.storeName ?? "")
        _productName = State(initialValue: initialParse?.productName ?? "")
        _purchaseDate = State(initialValue: initialParse?.purchaseDate ?? .now)
        let cents = initialParse?.priceCents ?? 0
        _priceString = State(initialValue: cents > 0 ? String(format: "%.2f", Double(cents) / 100.0) : "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    masthead
                    RFPerforation()
                    if initialParse == nil { unknownSenderBanner } else { matchBanner }
                    RFPerforation()
                    form
                    Spacer().frame(height: 12)
                    saveButton
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color(red: 0.961, green: 0.945, blue: 0.910).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
    }

    private var masthead: some View {
        VStack(spacing: 10) {
            HStack {
                Text("EMAIL · INTAKE")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(Color(red: 0.431, green: 0.400, blue: 0.353))
                Spacer()
                Text(Date.now.formatted(.dateTime.month(.abbreviated).day()).uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color(red: 0.431, green: 0.400, blue: 0.353))
            }
            Rectangle().fill(Color(red: 0.102, green: 0.094, blue: 0.082)).frame(height: 2)
            HStack(alignment: .firstTextBaseline) {
                Text("Save as")
                    .font(.system(size: 42, weight: .regular, design: .serif))
                Text("receipt")
                    .font(.system(size: 42, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color(red: 0.784, green: 0.224, blue: 0.169))
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var matchBanner: some View {
        if let parse = initialParse {
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(Color(red: 0.102, green: 0.094, blue: 0.082))
                    .frame(width: 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("MATCHED — \(parse.storeName.uppercased())")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(1.4)
                    Text(confidenceText(parse.confidence))
                        .font(.system(size: 14, design: .serif))
                        .italic()
                        .foregroundStyle(Color(red: 0.431, green: 0.400, blue: 0.353))
                }
            }
        }
    }

    private var unknownSenderBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(Color(red: 0.784, green: 0.224, blue: 0.169))
                .frame(width: 2)
            VStack(alignment: .leading, spacing: 4) {
                Text("UNRECOGNISED SENDER")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                Text("We couldn't auto-match this email to a retailer — fill in the fields below by hand. The receipt will still save.")
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .foregroundStyle(Color(red: 0.431, green: 0.400, blue: 0.353))
            }
        }
    }

    private func confidenceText(_ c: EmailReceiptParser.Confidence) -> String {
        switch c {
        case .high:   return "Everything extracted cleanly — check below and save."
        case .medium: return "Most fields extracted. Review the ones marked empty."
        case .low:    return "Store recognised, other fields need filling in."
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 18) {
            field(label: "Store", text: $storeName)
            field(label: "Product", text: $productName)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("DATE")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color(red: 0.431, green: 0.400, blue: 0.353))
                Spacer()
                DatePicker("", selection: $purchaseDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
            field(label: "Price", text: $priceString, keyboardType: .decimalPad, placeholder: "0.00")
        }
    }

    private func field(
        label: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        placeholder: String = ""
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color(red: 0.431, green: 0.400, blue: 0.353))
            TextField(placeholder, text: text)
                .font(.system(size: 17, design: .serif))
                .keyboardType(keyboardType)
                .padding(.vertical, 6)
                .overlay(
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(Color(red: 0.102, green: 0.094, blue: 0.082))
                            .frame(height: 0.75)
                    }
                )
        }
    }

    private var saveButton: some View {
        Button {
            let cents = Int((Double(priceString) ?? 0) * 100)
            onConfirm(EmailReceiptParser.ParsedReceipt(
                storeName: storeName.trimmingCharacters(in: .whitespaces),
                productName: productName.trimmingCharacters(in: .whitespaces),
                purchaseDate: purchaseDate,
                priceCents: cents > 0 ? cents : nil,
                confidence: .medium,
                rawTextUsed: bodyText
            ))
        } label: {
            Text("Save to Receipt Folder")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(red: 0.961, green: 0.945, blue: 0.910))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(red: 0.102, green: 0.094, blue: 0.082))
        }
        .disabled(storeName.isEmpty || productName.isEmpty)
        .opacity((storeName.isEmpty || productName.isEmpty) ? 0.4 : 1)
    }
}

// Minimal perforation shim for the extension — DesignSystem lives in the
// app target, so we inline a simple dotted-rule here.
private struct RFPerforation: View {
    var body: some View {
        GeometryReader { geo in
            let dot: CGFloat = 3
            let gap: CGFloat = 6
            let count = max(0, Int((geo.size.width + gap) / (dot + gap)))
            HStack(spacing: gap) {
                ForEach(0..<count, id: \.self) { _ in
                    Circle()
                        .fill(Color(red: 0.102, green: 0.094, blue: 0.082, opacity: 0.2))
                        .frame(width: dot, height: dot)
                }
            }
        }
        .frame(height: 3)
    }
}
