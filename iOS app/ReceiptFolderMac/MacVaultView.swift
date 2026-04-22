import SwiftUI
import SwiftData

/// The Vault on macOS — editorial masthead, search, and a scrolling list of
/// receipts. Uses the same Shared/ReceiptItem model the iOS app uses, so
/// a receipt added on iPhone appears here within a sync cycle.
struct MacVaultView: View {
    @Query(
        filter: #Predicate<ReceiptItem> { !$0.isArchived },
        sort: \ReceiptItem.createdAt,
        order: .reverse
    )
    private var items: [ReceiptItem]

    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme
    @State private var searchText = ""
    @State private var selected: ReceiptItem?
    @State private var selectedHousehold: HouseholdReceipt?
    @State private var householdStore = HouseholdStore.shared
    @FocusState private var searchFocused: Bool
    @State private var showingAdd = false

    private var filteredHouseholdRecords: [HouseholdReceipt] {
        let base = householdStore.records
        guard !searchText.isEmpty else { return base }
        let q = searchText.lowercased()
        return base.filter {
            $0.productName.lowercased().contains(q) ||
            $0.storeName.lowercased().contains(q) ||
            $0.ownerDisplayName.lowercased().contains(q)
        }
    }

    var body: some View {
        HSplitView {
            listColumn
                .frame(minWidth: 380, idealWidth: 440)
            detailColumn
                .frame(minWidth: 360)
        }
        .task { await householdStore.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .macFocusSearch)) { _ in
            searchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .macAddReceipt)) { _ in
            showingAdd = true
        }
        .sheet(isPresented: $showingAdd) {
            MacAddReceiptView(onDismiss: { showingAdd = false })
                .frame(minWidth: 520, minHeight: 560)
        }
    }

    // MARK: - List column

    private var listColumn: some View {
        VStack(spacing: 0) {
            masthead
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)

            Divider()

            if filtered.isEmpty && filteredHouseholdRecords.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectionTag) {
                    Section {
                        ForEach(filtered) { item in
                            MacVaultRow(item: item)
                                .tag(SelectedEntry.owned(item))
                        }
                    } header: {
                        if !filtered.isEmpty {
                            sectionHeader("Your vault", count: filtered.count)
                        }
                    }

                    if !filteredHouseholdRecords.isEmpty {
                        Section {
                            ForEach(filteredHouseholdRecords) { rec in
                                MacHouseholdRow(record: rec)
                                    .tag(SelectedEntry.household(rec))
                            }
                        } header: {
                            sectionHeader("Household", count: filteredHouseholdRecords.count)
                        }
                    }
                }
                .listStyle(.inset)
                .onChange(of: selectionTag) { _, newValue in
                    switch newValue {
                    case .owned(let item)?:
                        selected = item
                        selectedHousehold = nil
                    case .household(let rec)?:
                        selectedHousehold = rec
                        selected = nil
                    case nil:
                        selected = nil
                        selectedHousehold = nil
                    }
                }
            }
        }
        .background(MacColors.paperDim(scheme))
    }

    /// Tri-state selection that distinguishes private items from household
    /// records. Needed because List's `selection:` binding wants one value
    /// type but the rows render two different model types.
    private enum SelectedEntry: Hashable {
        case owned(ReceiptItem)
        case household(HouseholdReceipt)
    }

    @State private var selectionTag: SelectedEntry?

    private func sectionHeader(_ title: String, count: Int?) -> some View {
        HStack {
            Text(title.uppercased())
                .font(MacFont.mono(10))
                .tracking(1.4)
                .foregroundStyle(MacColors.mute(scheme))
            if let count {
                Spacer()
                Text("\(count)")
                    .font(MacFont.mono(10))
                    .foregroundStyle(MacColors.mute(scheme))
            }
        }
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("THE VAULT")
                    .font(MacFont.mono(10))
                    .tracking(1.8)
                    .foregroundStyle(MacColors.mute(scheme))
                Spacer()
                Text("\(items.count) \(items.count == 1 ? "ITEM" : "ITEMS")")
                    .font(MacFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(MacColors.mute(scheme))
            }

            Rectangle().fill(MacColors.ink(scheme)).frame(height: 2)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Receipt")
                    .font(MacFont.hero(44))
                    .foregroundStyle(MacColors.ink(scheme))
                Text("Folder")
                    .font(.system(size: 44, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(MacColors.signal)
                Spacer()
            }

            TextField("Search receipts", text: $searchText)
                .textFieldStyle(.plain)
                .font(MacFont.serifBody(14))
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(MacColors.paper(scheme))
                .overlay(
                    Rectangle().stroke(MacColors.rule(scheme), lineWidth: 0.75)
                )
                .focused($searchFocused)

            Button { showingAdd = true } label: {
                Label("Add receipt", systemImage: "plus")
            }
            .controlSize(.small)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(MacColors.ink(scheme).opacity(0.35))
            Text("An empty ledger.")
                .font(MacFont.title(22))
            Text("Add a receipt — or wait for iCloud to sync from your iPhone.")
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundStyle(MacColors.mute(scheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Add receipt") { showingAdd = true }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Detail column

    @ViewBuilder
    private var detailColumn: some View {
        if let item = selected {
            MacReceiptDetail(item: item)
        } else if let rec = selectedHousehold {
            MacHouseholdDetail(record: rec)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 26))
                    .foregroundStyle(MacColors.mute(scheme))
                Text("Select a receipt from the list")
                    .font(.system(size: 15, design: .serif))
                    .italic()
                    .foregroundStyle(MacColors.mute(scheme))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MacColors.paper(scheme))
        }
    }

    // MARK: - Filter

    private var filtered: [ReceiptItem] {
        if searchText.isEmpty { return items }
        let q = searchText.lowercased()
        return items.filter {
            $0.productName.lowercased().contains(q) ||
            $0.storeName.lowercased().contains(q) ||
            $0.notes.lowercased().contains(q)
        }
    }
}

// MARK: - List row

private struct MacVaultRow: View {
    let item: ReceiptItem
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.productName)
                    .font(MacFont.serifBody(15))
                    .foregroundStyle(MacColors.ink(scheme))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.storeName.uppercased())
                        .font(MacFont.mono(10))
                        .tracking(1.0)
                        .foregroundStyle(MacColors.mute(scheme))
                    if item.priceCents > 0 {
                        Text("·")
                            .font(MacFont.mono(10))
                            .foregroundStyle(MacColors.mute(scheme))
                        Text(item.formattedPrice)
                            .font(MacFont.mono(10))
                            .foregroundStyle(MacColors.mute(scheme))
                    }
                }
            }
            Spacer()
            if let days = item.returnDaysRemaining, !item.isReturned {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(days)")
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .foregroundStyle(item.urgencyLevel == .critical ? MacColors.signal : MacColors.ink(scheme))
                    Text("d")
                        .font(.system(size: 12, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(MacColors.mute(scheme))
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Expiring

struct MacExpiringView: View {
    @Query(
        filter: #Predicate<ReceiptItem> { !$0.isArchived && !$0.isReturned },
        sort: \ReceiptItem.returnWindowEndDate
    )
    private var items: [ReceiptItem]
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("URGENT DESK")
                        .font(MacFont.mono(10))
                        .tracking(1.8)
                        .foregroundStyle(MacColors.mute(scheme))
                    Rectangle().fill(MacColors.ink(scheme)).frame(height: 2)
                    HStack(alignment: .firstTextBaseline) {
                        Text("Expiring")
                            .font(MacFont.hero(44))
                        Text("Soon")
                            .font(.system(size: 44, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(MacColors.signal)
                    }
                }

                if criticalItems.isEmpty && warningItems.isEmpty {
                    VStack(spacing: 10) {
                        Text("All clear.")
                            .font(MacFont.title(24))
                        Text("No deadlines on the horizon.")
                            .font(.system(size: 14, design: .serif))
                            .italic()
                            .foregroundStyle(MacColors.mute(scheme))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    urgencySection(title: "Deadline imminent", items: criticalItems, accent: MacColors.signal)
                    urgencySection(title: "Closing soon", items: warningItems, accent: MacColors.signal.opacity(0.7))
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MacColors.paper(scheme))
    }

    private var criticalItems: [ReceiptItem] {
        items.filter { $0.urgencyLevel == .critical }
    }
    private var warningItems: [ReceiptItem] {
        items.filter { $0.urgencyLevel == .warning }
    }

    private func urgencySection(title: String, items: [ReceiptItem], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Rectangle().fill(accent).frame(width: 8, height: 8)
                Text(title.uppercased())
                    .font(MacFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(accent)
                Spacer()
                Text("\(items.count)")
                    .font(MacFont.mono(10))
                    .foregroundStyle(MacColors.mute(scheme))
            }
            ForEach(items) { item in
                MacVaultRow(item: item)
                    .padding(.vertical, 4)
                Divider()
            }
        }
    }
}

// MARK: - Settings

struct MacSettingsView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("COLOPHON")
                        .font(MacFont.mono(10))
                        .tracking(1.8)
                        .foregroundStyle(MacColors.mute(scheme))
                    Rectangle().fill(MacColors.ink(scheme)).frame(height: 2)
                    Text("Settings")
                        .font(MacFont.hero(44))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("SYNC")
                        .font(MacFont.mono(10))
                        .tracking(1.4)
                        .foregroundStyle(MacColors.mute(scheme))
                    Text("Receipts sync between this Mac and your iPhone via iCloud, provided you're signed in with the same Apple ID. Nothing is sent to any server other than Apple's.")
                        .font(.system(size: 14, design: .serif))
                        .italic()
                        .foregroundStyle(MacColors.mute(scheme))
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("EXPORT")
                        .font(MacFont.mono(10))
                        .tracking(1.4)
                        .foregroundStyle(MacColors.mute(scheme))
                    Text("Use File → Export Receipts… or ⌘E to save all receipts as CSV or JSON.")
                        .font(.system(size: 14, design: .serif))
                        .italic()
                        .foregroundStyle(MacColors.mute(scheme))
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("RECEIPT · FOLDER")
                        .font(MacFont.mono(11))
                        .tracking(2.2)
                    Text("Version 1.0 for macOS")
                        .font(MacFont.mono(10))
                        .foregroundStyle(MacColors.mute(scheme))
                    Text("Set by Honorius M. Neogy")
                        .font(.system(size: 13, design: .serif))
                        .italic()
                        .foregroundStyle(MacColors.mute(scheme))
                }
                .padding(.top, 20)
            }
            .padding(24)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(MacColors.paper(scheme))
    }
}

// MARK: - Detail view

struct MacReceiptDetail: View {
    @Bindable var item: ReceiptItem
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                MacPerforation()
                metadataTable
                if !item.returnPolicyDescription.isEmpty {
                    MacPerforation()
                    policyBlock
                }
                MacPerforation()
                notes
                Spacer(minLength: 40)
            }
            .padding(32)
        }
        .background(MacColors.paper(scheme))
        .toolbar {
            ToolbarItemGroup {
                if item.isReturnWindowOpen {
                    Button("Mark Returned") {
                        item.isReturned = true
                        item.returnedAt = .now
                        try? context.save()
                    }
                }
                Button("Archive") {
                    item.isArchived = true
                    try? context.save()
                }
                Button("Delete", role: .destructive) {
                    context.delete(item)
                    try? context.save()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECEIPT · NO. \(item.id.uuidString.prefix(8).uppercased())")
                .font(MacFont.mono(10))
                .tracking(1.4)
                .foregroundStyle(MacColors.mute(scheme))
            Rectangle().fill(MacColors.ink(scheme)).frame(height: 2)
            Text(item.productName)
                .font(MacFont.hero(36))
                .foregroundStyle(MacColors.ink(scheme))
            HStack(spacing: 4) {
                Text("from")
                    .italic()
                    .foregroundStyle(MacColors.mute(scheme))
                Text(item.storeName)
                Text("·")
                    .foregroundStyle(MacColors.mute(scheme))
                Text(item.purchaseDate, style: .date)
                    .italic()
                    .foregroundStyle(MacColors.mute(scheme))
            }
            .font(.system(size: 14, design: .serif))

            if let days = item.returnDaysRemaining, !item.isReturned {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(days)")
                        .font(.system(size: 80, weight: .regular, design: .serif))
                        .foregroundStyle(item.urgencyLevel == .critical ? MacColors.signal : MacColors.ink(scheme))
                    Text(days == 1 ? "DAY" : "DAYS")
                        .font(.system(size: 18, design: .serif))
                        .italic()
                        .foregroundStyle(item.urgencyLevel == .critical ? MacColors.signal : MacColors.mute(scheme))
                    Text("until return window closes")
                        .font(.system(size: 13, design: .serif))
                        .italic()
                        .foregroundStyle(MacColors.mute(scheme))
                }
                .padding(.top, 20)
            } else if item.isReturned {
                Text("RETURNED")
                    .font(.system(size: 40, weight: .regular, design: .serif))
                    .tracking(6)
                    .foregroundStyle(MacColors.signal)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .overlay(Rectangle().stroke(MacColors.signal, lineWidth: 2))
                    .rotationEffect(.degrees(-3))
                    .padding(.top, 20)
            }
        }
    }

    private var metadataTable: some View {
        VStack(spacing: 8) {
            metaRow(label: "DATE", value: item.purchaseDate.formatted(.dateTime.month(.abbreviated).day().year()))
            metaRow(label: "STORE", value: item.storeName)
            if item.priceCents > 0 {
                metaRow(label: "PRICE", value: item.formattedPrice)
            }
            if let end = item.returnWindowEndDate {
                metaRow(label: "RETURN BY", value: end.formatted(.dateTime.month(.abbreviated).day().year()))
            }
            if let end = item.warrantyEndDate {
                metaRow(label: "WARRANTY", value: end.formatted(.dateTime.month(.abbreviated).day().year()))
            }
        }
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(MacFont.mono(10))
                .tracking(1.4)
                .foregroundStyle(MacColors.mute(scheme))
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(MacFont.serifBody(14))
                .foregroundStyle(MacColors.ink(scheme))
            Spacer()
        }
    }

    private var policyBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STORE POLICY")
                .font(MacFont.mono(10))
                .tracking(1.4)
                .foregroundStyle(MacColors.mute(scheme))
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(MacColors.ink(scheme))
                    .frame(width: 2)
                Text("“\(item.returnPolicyDescription)”")
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .foregroundStyle(MacColors.ink(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES")
                .font(MacFont.mono(10))
                .tracking(1.4)
                .foregroundStyle(MacColors.mute(scheme))
            TextEditor(text: $item.notes)
                .font(.system(size: 14, design: .serif))
                .frame(minHeight: 100)
                .padding(8)
                .overlay(Rectangle().stroke(MacColors.rule(scheme), lineWidth: 0.75))
        }
    }
}

// MARK: - Add sheet

struct MacAddReceiptView: View {
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context

    @State private var productName = ""
    @State private var storeName = ""
    @State private var purchaseDate = Date()
    @State private var priceString = ""
    @State private var returnDays = 30
    @State private var warrantyYears = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("NEW ENTRY")
                    .font(MacFont.mono(10))
                    .tracking(1.6)
                    .foregroundStyle(MacColors.mute(scheme))
                Spacer()
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.escape)
            }
            Rectangle().fill(MacColors.ink(scheme)).frame(height: 2)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Add a")
                    .font(MacFont.hero(36))
                Text("receipt")
                    .font(.system(size: 36, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(MacColors.signal)
            }

            Form {
                TextField("Product", text: $productName)
                TextField("Store", text: $storeName)
                DatePicker("Purchase date", selection: $purchaseDate, displayedComponents: .date)
                TextField("Price", text: $priceString)
                Stepper("Return window: \(returnDays) days", value: $returnDays, in: 0...365)
                Stepper("Warranty: \(warrantyYears) year\(warrantyYears == 1 ? "" : "s")", value: $warrantyYears, in: 0...10)
            }
            .font(MacFont.serifBody(14))

            Spacer()

            HStack {
                Spacer()
                Button("Save", action: save)
                    .keyboardShortcut(.return)
                    .disabled(productName.isEmpty || storeName.isEmpty)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .background(MacColors.paper(scheme))
    }

    private func save() {
        let cents = Int((Double(priceString) ?? 0) * 100)
        let returnEnd = returnDays > 0 ? Calendar.current.date(byAdding: .day, value: returnDays, to: purchaseDate) : nil
        let warrantyEnd = warrantyYears > 0 ? Calendar.current.date(byAdding: .year, value: warrantyYears, to: purchaseDate) : nil

        let item = ReceiptItem(
            productName: productName.trimmingCharacters(in: .whitespaces),
            storeName: storeName.trimmingCharacters(in: .whitespaces),
            purchaseDate: purchaseDate,
            priceCents: cents,
            returnWindowEndDate: returnEnd,
            warrantyEndDate: warrantyEnd
        )
        context.insert(item)
        try? context.save()
        onDismiss()
    }
}

// MARK: - Household row + detail (Mac)

private struct MacHouseholdRow: View {
    let record: HouseholdReceipt
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(MacColors.signal)
                    Text("SHARED · \(record.ownerDisplayName.uppercased())")
                        .font(MacFont.mono(9))
                        .tracking(1.2)
                        .foregroundStyle(MacColors.signal)
                }
                Text(record.productName)
                    .font(MacFont.serifBody(15))
                    .foregroundStyle(MacColors.ink(scheme))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(record.storeName.uppercased())
                        .font(MacFont.mono(10))
                        .tracking(1.0)
                        .foregroundStyle(MacColors.mute(scheme))
                    if record.priceCents > 0 {
                        Text("·").font(MacFont.mono(10)).foregroundStyle(MacColors.mute(scheme))
                        Text(record.formattedPrice)
                            .font(MacFont.mono(10))
                            .foregroundStyle(MacColors.mute(scheme))
                    }
                }
            }
            Spacer()
            if let days = record.returnDaysRemaining, !record.isReturned {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(days)")
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .foregroundStyle(record.urgencyLevel == .critical ? MacColors.signal : MacColors.ink(scheme))
                    Text("d")
                        .font(.system(size: 12, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(MacColors.mute(scheme))
                }
            } else if record.isReturned {
                Text("RETURNED")
                    .font(MacFont.mono(9))
                    .tracking(1.0)
                    .foregroundStyle(MacColors.mute(scheme))
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MacHouseholdDetail: View {
    let record: HouseholdReceipt
    @Environment(\.colorScheme) private var scheme
    @State private var store = HouseholdStore.shared
    @State private var isWorking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                MacPerforation()
                metadata
                if !record.isReturned {
                    MacPerforation()
                    actions
                }
                MacPerforation()
                provenance
                Spacer(minLength: 40)
            }
            .padding(32)
        }
        .background(MacColors.paper(scheme))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SHARED · \(record.ownerDisplayName.uppercased())")
                    .font(MacFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(MacColors.signal)
                Spacer()
                Text("NO. \(record.id.prefix(8).uppercased())")
                    .font(MacFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(MacColors.mute(scheme))
            }
            Rectangle().fill(MacColors.ink(scheme)).frame(height: 2)
            Text(record.productName)
                .font(MacFont.hero(36))
            HStack(spacing: 4) {
                Text("from").italic().foregroundStyle(MacColors.mute(scheme))
                Text(record.storeName)
                Text("·").foregroundStyle(MacColors.mute(scheme))
                Text(record.purchaseDate, style: .date).italic().foregroundStyle(MacColors.mute(scheme))
            }
            .font(.system(size: 14, design: .serif))

            if let days = record.returnDaysRemaining, !record.isReturned {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(days)")
                        .font(.system(size: 80, weight: .regular, design: .serif))
                        .foregroundStyle(record.urgencyLevel == .critical ? MacColors.signal : MacColors.ink(scheme))
                    Text(days == 1 ? "DAY" : "DAYS")
                        .font(.system(size: 18, design: .serif))
                        .italic()
                        .foregroundStyle(MacColors.mute(scheme))
                    Text("until return window closes")
                        .font(.system(size: 13, design: .serif))
                        .italic()
                        .foregroundStyle(MacColors.mute(scheme))
                }
                .padding(.top, 20)
            } else if record.isReturned {
                Text("RETURNED")
                    .font(.system(size: 40, weight: .regular, design: .serif))
                    .tracking(6)
                    .foregroundStyle(MacColors.signal)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .overlay(Rectangle().stroke(MacColors.signal, lineWidth: 2))
                    .rotationEffect(.degrees(-3))
                    .padding(.top, 20)
            }
        }
    }

    private var metadata: some View {
        VStack(spacing: 8) {
            row("DATE", record.purchaseDate.formatted(.dateTime.month(.abbreviated).day().year()))
            row("STORE", record.storeName)
            if record.priceCents > 0 { row("PRICE", record.formattedPrice) }
            if let end = record.returnWindowEndDate {
                row("RETURN BY", end.formatted(.dateTime.month(.abbreviated).day().year()))
            }
            if let end = record.warrantyEndDate {
                row("WARRANTY", end.formatted(.dateTime.month(.abbreviated).day().year()))
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(MacFont.mono(10))
                .tracking(1.4)
                .foregroundStyle(MacColors.mute(scheme))
                .frame(width: 90, alignment: .leading)
            Text(value).font(MacFont.serifBody(14)).foregroundStyle(MacColors.ink(scheme))
            Spacer()
        }
    }

    private var actions: some View {
        Button {
            Task {
                isWorking = true
                try? await store.markReturned(record.id)
                isWorking = false
            }
        } label: {
            Label(isWorking ? "Marking returned…" : "Mark as returned", systemImage: "arrow.uturn.left")
        }
        .buttonStyle(.borderedProminent)
        .disabled(isWorking)
    }

    private var provenance: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PROVENANCE")
                .font(MacFont.mono(10))
                .tracking(1.4)
                .foregroundStyle(MacColors.mute(scheme))
            Text("Managed by \(record.ownerDisplayName). Other fields can only be changed from their device.")
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundStyle(MacColors.mute(scheme))
        }
    }
}

// MARK: - Placeholder

struct MacPlaceholderView: View {
    let title: String
    let caption: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(MacFont.hero(40))
            Text(caption)
                .font(.system(size: 14, design: .serif))
                .italic()
                .foregroundStyle(MacColors.mute(scheme))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
        .background(MacColors.paper(scheme))
    }
}
