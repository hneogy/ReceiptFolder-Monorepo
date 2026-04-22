import SwiftUI

/// Store picker — rendered like an index page with alphabetical letters
/// and ledger-style rows.
struct StorePickerSheet: View {
    var onSelect: (StorePolicy) -> Void
    var onCancel: () -> Void

    @State private var searchText = ""

    private var allPolicies: [StorePolicy] {
        StorePolicyService.shared.allPolicies()
    }

    private var filteredPolicies: [StorePolicy] {
        guard !searchText.isEmpty else { return allPolicies }
        let query = searchText.lowercased()
        return allPolicies.filter {
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
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 20)

                    if filteredPolicies.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .padding(.vertical, 60)
                    } else {
                        ForEach(groupedPolicies, id: \.letter) { group in
                            letterBlock(letter: group.letter, policies: group.policies)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                        }
                    }

                    Spacer().frame(height: 60)
                }
            }
            .background(RFColors.paper)
            .navigationTitle("Choose a Store")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search the directory")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .foregroundStyle(RFColors.ink)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Text("DIRECTORY")
                    .font(RFFont.mono(10))
                    .tracking(1.8)
                    .foregroundStyle(RFColors.mute)
                Spacer()
                Text("\(allPolicies.count) LISTED")
                    .font(RFFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.mute)
            }

            Rectangle().fill(RFColors.ink).frame(height: 2)

            Text("Select a retailer to apply its return policy.")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.mute)
                .frame(maxWidth: .infinity, alignment: .leading)

            RFHairline()
        }
    }

    private func letterBlock(letter: String, policies: [StorePolicy]) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(letter)
                    .font(.system(size: 36, weight: .regular, design: .serif))
                    .foregroundStyle(RFColors.signal)
                    .frame(width: 36, alignment: .leading)
                Rectangle().fill(RFColors.ink).frame(height: 1)
            }

            ForEach(Array(policies.enumerated()), id: \.element.id) { index, policy in
                Button {
                    onSelect(policy)
                } label: {
                    pickerRow(policy)
                }
                .buttonStyle(.plain)

                if index < policies.count - 1 {
                    RFHairline()
                }
            }
        }
    }

    private func pickerRow(_ policy: StorePolicy) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(policy.name)
                .font(RFFont.serifBody(16))
                .foregroundStyle(RFColors.ink)

            LeaderDots()

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
        .padding(.vertical, 12)
        .contentShape(.rect)
    }
}
