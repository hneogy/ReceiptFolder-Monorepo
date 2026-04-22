import SwiftUI

/// Store Directory — rendered as a printed directory: alphabetical letter
/// headers in serif, each retailer a ledger line with dot-leaders to the
/// return window.
struct StorePolicyListView: View {
    @State private var searchText = ""
    @State private var showingAddStore = false
    @State private var policyToDelete: StorePolicy?

    private var policies: [StorePolicy] {
        StorePolicyService.shared.allPolicies()
    }

    private var filteredPolicies: [StorePolicy] {
        if searchText.isEmpty { return policies }
        let query = searchText.lowercased()
        return policies.filter {
            $0.name.lowercased().contains(query) ||
            $0.aliases.contains(where: { $0.lowercased().contains(query) })
        }
    }

    private var groupedPolicies: [(letter: String, policies: [StorePolicy])] {
        let grouped = Dictionary(grouping: filteredPolicies) { policy in
            String(policy.name.prefix(1)).uppercased()
        }
        return grouped
            .map { (letter: $0.key, policies: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.letter < $1.letter }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                directoryHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)

                if filteredPolicies.isEmpty {
                    emptyState
                        .padding(.top, 40)
                } else {
                    ForEach(groupedPolicies, id: \.letter) { group in
                        letterSection(letter: group.letter, policies: group.policies)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                    }
                }

                Spacer().frame(height: 60)
            }
        }
        .background(RFColors.paper)
        .navigationTitle("Directory")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search the directory")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddStore = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(RFColors.ink)
                }
                .accessibilityLabel("Add custom store")
            }
        }
        .sheet(isPresented: $showingAddStore) {
            AddStorePolicyView()
        }
        .alert("Delete Store Policy?", isPresented: .init(
            get: { policyToDelete != nil },
            set: { if !$0 { policyToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let policy = policyToDelete {
                    withAnimation {
                        StorePolicyService.shared.removeCustomPolicy(id: policy.id)
                    }
                    policyToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { policyToDelete = nil }
        } message: {
            if let policy = policyToDelete {
                Text("Remove \"\(policy.name)\" from your custom store policies?")
            }
        }
    }

    // MARK: - Directory Header

    private var directoryHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Text("STORE DIRECTORY")
                    .font(RFFont.mono(10))
                    .tracking(1.8)
                    .foregroundStyle(RFColors.mute)
                Spacer()
                Text("\(policies.count) RETAILERS ON FILE")
                    .font(RFFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.mute)
            }

            Rectangle().fill(RFColors.ink).frame(height: 2)

            HStack(alignment: .firstTextBaseline) {
                Text("The")
                    .font(RFFont.hero(44))
                    .foregroundStyle(RFColors.ink)
                Text("Directory")
                    .font(.system(size: 44, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.signal)
                Spacer()
            }

            HStack {
                Text("Return policies, warranty terms, and house rules for each retailer.")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
                Spacer()
            }

            RFHairline()
        }
    }

    // MARK: - Letter Section

    private func letterSection(letter: String, policies: [StorePolicy]) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(letter)
                    .font(.system(size: 42, weight: .regular, design: .serif))
                    .foregroundStyle(RFColors.signal)
                    .frame(width: 40, alignment: .leading)
                Rectangle().fill(RFColors.ink).frame(height: 1)
            }
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)

            ForEach(Array(policies.enumerated()), id: \.element.id) { index, policy in
                policyRowWithActions(policy)

                if index < policies.count - 1 {
                    RFHairline()
                }
            }
        }
    }

    @ViewBuilder
    private func policyRowWithActions(_ policy: StorePolicy) -> some View {
        NavigationLink {
            StorePolicyDetailView(policy: policy)
        } label: {
            policyRow(policy, isCustom: policy.isCustom)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if policy.isCustom {
                Button(role: .destructive) {
                    policyToDelete = policy
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Row

    private func policyRow(_ policy: StorePolicy, isCustom: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(policy.name)
                .font(RFFont.serifBody(16))
                .foregroundStyle(RFColors.ink)

            if isCustom {
                Text("CUSTOM")
                    .font(RFFont.mono(9))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.paper)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(RFColors.ink)
            }

            LeaderDots()

            returnBadge(policy)
        }
        .padding(.vertical, 12)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(policyAccessibilityLabel(policy))
        .accessibilityHint(isCustom ? "Double tap to view details. Long press to delete." : "Double tap to view full policy details")
    }

    @ViewBuilder
    private func returnBadge(_ policy: StorePolicy) -> some View {
        if policy.isUnlimitedReturn {
            Text("ANYTIME")
                .font(RFFont.monoBold(10))
                .tracking(1.2)
                .foregroundStyle(RFColors.ink)
        } else if policy.isNonReturnable {
            Text("NO RETURNS")
                .font(RFFont.monoBold(10))
                .tracking(1.2)
                .foregroundStyle(RFColors.signal)
        } else {
            Text("\(policy.defaultReturnDays) DAYS")
                .font(RFFont.monoBold(10))
                .tracking(1.2)
                .foregroundStyle(RFColors.ink)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("No matching retailer.")
                .font(RFFont.title(24))
                .foregroundStyle(RFColors.ink)

            Text("Try a different search term or add a custom policy.")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.mute)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 32)
    }

    private func policyAccessibilityLabel(_ policy: StorePolicy) -> String {
        var parts = [policy.name]
        if policy.isUnlimitedReturn {
            parts.append("returns accepted anytime")
        } else if policy.isNonReturnable {
            parts.append("non-returnable")
        } else {
            parts.append("\(policy.defaultReturnDays) day return window")
        }
        if policy.defaultWarrantyYears > 0 {
            parts.append("\(policy.defaultWarrantyYears) year warranty")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Store Policy Detail View
//
// Rendered as an encyclopaedia entry: serif title, tabular policy rows,
// block-quoted conditions, bullet-marked requirements, alias chips.

struct StorePolicyDetailView: View {
    let policy: StorePolicy

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                policyTable
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                RFPerforation().padding(.horizontal, 20).padding(.bottom, 24)

                if !policy.categoryOverrides.isEmpty {
                    categoryOverridesSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    RFPerforation().padding(.horizontal, 20).padding(.bottom, 24)
                }

                if !policy.returnConditions.isEmpty {
                    conditionsSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    RFPerforation().padding(.horizontal, 20).padding(.bottom, 24)
                }

                if !policy.returnRequirements.isEmpty {
                    requirementsSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    RFPerforation().padding(.horizontal, 20).padding(.bottom, 24)
                }

                if !policy.aliases.isEmpty {
                    aliasesSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 60)
                }
            }
        }
        .background(RFColors.paper)
        .navigationTitle(policy.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            StoreAvatar(name: policy.name, size: 64)
                .padding(.top, 8)

            Text(policy.name)
                .font(RFFont.title(32))
                .foregroundStyle(RFColors.ink)
                .multilineTextAlignment(.center)

            Text("An entry in the retailer directory.")
                .font(.system(size: 13, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.mute)

            RFHairline().padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Policy table

    private var policyTable: some View {
        VStack(spacing: 10) {
            tableRow(label: "Return window", value: returnText, color: returnColor)
            if policy.defaultWarrantyYears > 0 {
                tableRow(label: "Warranty", value: "\(policy.defaultWarrantyYears) year\(policy.defaultWarrantyYears == 1 ? "" : "s")", color: RFColors.ink)
            }
        }
    }

    private func tableRow(label: String, value: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label.uppercased())
                .font(RFFont.mono(10))
                .tracking(1.4)
                .foregroundStyle(RFColors.mute)
                .frame(width: 110, alignment: .leading)

            LeaderDots()

            Text(value)
                .font(RFFont.monoBold(13))
                .foregroundStyle(color)
        }
    }

    // MARK: - Category Overrides

    private var categoryOverridesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            RFEyebrow(text: "Category exceptions")

            VStack(spacing: 0) {
                ForEach(Array(policy.categoryOverrides.enumerated()), id: \.element.category) { index, override in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(override.category)
                            .font(RFFont.serifBody(15))
                            .foregroundStyle(RFColors.ink)

                        LeaderDots()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(override.returnDays) DAYS")
                                .font(RFFont.monoBold(11))
                                .tracking(1.2)
                                .foregroundStyle(override.returnDays == 0 ? RFColors.signal : RFColors.ink)
                            if let exchangeOnly = override.exchangeOnly, exchangeOnly {
                                Text("EXCHANGE ONLY")
                                    .font(RFFont.mono(9))
                                    .tracking(1.2)
                                    .foregroundStyle(RFColors.ember)
                            }
                            if let note = override.note, !note.isEmpty {
                                Text(note)
                                    .font(.system(size: 11, weight: .regular, design: .serif))
                                    .italic()
                                    .foregroundStyle(RFColors.mute)
                            }
                        }
                    }
                    .padding(.vertical, 10)

                    if index < policy.categoryOverrides.count - 1 {
                        RFHairline()
                    }
                }
            }
        }
    }

    // MARK: - Conditions

    private var conditionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            RFEyebrow(text: "Return conditions")

            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(RFColors.ink)
                    .frame(width: 2)

                Text(policy.returnConditions)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Requirements

    private var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            RFEyebrow(text: "To return, bring")

            VStack(alignment: .leading, spacing: 10) {
                ForEach(policy.returnRequirements, id: \.self) { requirement in
                    HStack(alignment: .top, spacing: 10) {
                        Text("•")
                            .font(RFFont.mono(12))
                            .foregroundStyle(RFColors.ink)
                        Text(requirement)
                            .font(RFFont.serifBody(15))
                            .foregroundStyle(RFColors.ink)
                    }
                }
            }
        }
    }

    // MARK: - Aliases

    private var aliasesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            RFEyebrow(text: "Also known as")

            FlowLayout(spacing: 8) {
                ForEach(policy.aliases, id: \.self) { alias in
                    Text(alias)
                        .font(RFFont.mono(11))
                        .tracking(0.6)
                        .foregroundStyle(RFColors.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .overlay(Rectangle().stroke(RFColors.ink, lineWidth: 0.75))
                }
            }
        }
    }

    // MARK: - Helpers

    private var returnText: String {
        if policy.isUnlimitedReturn { return "Anytime" }
        if policy.isNonReturnable { return "No returns" }
        return "\(policy.defaultReturnDays) days"
    }

    private var returnColor: Color {
        if policy.isUnlimitedReturn { return RFColors.ink }
        if policy.isNonReturnable { return RFColors.signal }
        return RFColors.ink
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
