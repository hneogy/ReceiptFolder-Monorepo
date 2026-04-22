import SwiftUI

/// Add a custom store policy — rendered as a printed form: typewriter-style
/// underline inputs, mono labels, printed checklist of requirements.
struct AddStorePolicyView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var storeName = ""
    @State private var returnType: ReturnType = .standard
    @State private var returnDays = 30
    @State private var warrantyYears = 0
    @State private var returnConditions = ""
    @State private var requirementText = ""
    @State private var requirements: [String] = []

    enum ReturnType: String, CaseIterable {
        case standard = "Standard"
        case unlimited = "Unlimited"
        case nonReturnable = "Non-Returnable"
    }

    private var isValid: Bool {
        !storeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    formHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 24)

                    storeNameSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    RFPerforation().padding(.horizontal, 20).padding(.bottom, 20)

                    returnWindowSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    RFPerforation().padding(.horizontal, 20).padding(.bottom, 20)

                    warrantySection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    RFPerforation().padding(.horizontal, 20).padding(.bottom, 20)

                    conditionsSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    RFPerforation().padding(.horizontal, 20).padding(.bottom, 20)

                    requirementsSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 60)
                }
            }
            .background(RFColors.paper)
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .foregroundStyle(RFColors.ink)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { savePolicy() }
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .foregroundStyle(isValid ? RFColors.signal : RFColors.mute)
                        .disabled(!isValid)
                }
            }
        }
    }

    // MARK: - Header

    private var formHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Text("NEW DIRECTORY ENTRY")
                    .font(RFFont.mono(10))
                    .tracking(1.8)
                    .foregroundStyle(RFColors.mute)
                Spacer()
                Text("FORM · RP-001")
                    .font(RFFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.mute)
            }
            Rectangle().fill(RFColors.ink).frame(height: 2)

            Text("Enter a custom store policy to be filed in your directory.")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.mute)
                .frame(maxWidth: .infinity, alignment: .leading)

            RFHairline()
        }
    }

    // MARK: - Store Name

    private var storeNameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            RFEyebrow(text: "Store name")

            TextField("e.g. My Local Store", text: $storeName)
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundStyle(RFColors.ink)
                .autocorrectionDisabled()
                .padding(.vertical, 6)
                .overlay(
                    VStack {
                        Spacer()
                        Rectangle().fill(RFColors.ink).frame(height: 0.75)
                    }
                )
        }
    }

    // MARK: - Return Window

    private var returnWindowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            RFEyebrow(text: "Return window")

            HStack(spacing: 0) {
                ForEach(ReturnType.allCases, id: \.self) { type in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            returnType = type
                        }
                    } label: {
                        Text(type.rawValue.uppercased())
                            .font(RFFont.mono(10))
                            .tracking(1.2)
                            .foregroundStyle(returnType == type ? RFColors.paper : RFColors.ink)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(returnType == type ? RFColors.ink : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay(Rectangle().stroke(RFColors.ink, lineWidth: 0.75))

            if returnType == .standard {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("DAYS")
                        .font(RFFont.mono(10))
                        .tracking(1.4)
                        .foregroundStyle(RFColors.mute)

                    LeaderDots()

                    Text("\(returnDays)")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundStyle(RFColors.ink)

                    Stepper("", value: $returnDays, in: 1...365)
                        .labelsHidden()
                }
            } else if returnType == .unlimited {
                Text("Returns accepted at any time.")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
            } else {
                Text("This store does not accept returns.")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.signal)
            }
        }
    }

    // MARK: - Warranty

    private var warrantySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            RFEyebrow(text: "Default warranty")

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("COVERAGE")
                    .font(RFFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.mute)

                LeaderDots()

                Text("\(warrantyYears) year\(warrantyYears == 1 ? "" : "s")")
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(RFColors.ink)

                Stepper("", value: $warrantyYears, in: 0...10)
                    .labelsHidden()
            }
        }
    }

    // MARK: - Conditions

    private var conditionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            RFEyebrow(text: "Return conditions")

            TextField("e.g. Item must be unopened, with original receipt.", text: $returnConditions, axis: .vertical)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.ink)
                .lineLimit(3...6)
                .padding(.vertical, 8)
                .overlay(
                    VStack {
                        Spacer()
                        Rectangle().fill(RFColors.ink).frame(height: 0.75)
                    }
                )
        }
    }

    // MARK: - Requirements

    private var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            RFEyebrow(text: "To return, bring")

            ForEach(0..<requirements.count, id: \.self) { index in
                HStack(alignment: .top, spacing: 10) {
                    Text("•")
                        .font(RFFont.mono(12))
                        .foregroundStyle(RFColors.ink)

                    Text(requirements[index])
                        .font(RFFont.serifBody(15))
                        .foregroundStyle(RFColors.ink)

                    Spacer()

                    Button {
                        withAnimation {
                            _ = requirements.remove(at: index)
                        }
                    } label: {
                        Text("REMOVE")
                            .font(RFFont.mono(9))
                            .tracking(1.4)
                            .foregroundStyle(RFColors.mute)
                            .underline()
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                TextField("e.g. Original receipt", text: $requirementText)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(RFColors.ink)
                    .onSubmit { addRequirement() }
                    .padding(.vertical, 6)
                    .overlay(
                        VStack {
                            Spacer()
                            Rectangle().fill(RFColors.ink).frame(height: 0.75)
                        }
                    )

                Button {
                    addRequirement()
                } label: {
                    Text("ADD")
                        .font(RFFont.mono(10))
                        .tracking(1.4)
                        .foregroundStyle(RFColors.paper)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RFColors.ink)
                }
                .buttonStyle(.plain)
                .disabled(requirementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(requirementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
            }
        }
    }

    // MARK: - Actions

    private func addRequirement() {
        let trimmed = requirementText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation {
            requirements.append(trimmed)
            requirementText = ""
        }
    }

    private func savePolicy() {
        let trimmedName = storeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let days: Int
        switch returnType {
        case .standard: days = returnDays
        case .unlimited: days = -1
        case .nonReturnable: days = 0
        }

        let policy = StorePolicy(
            id: "custom_\(UUID().uuidString)",
            name: trimmedName,
            aliases: [],
            defaultReturnDays: days,
            categoryOverrides: [],
            defaultWarrantyYears: warrantyYears,
            returnConditions: returnConditions.trimmingCharacters(in: .whitespacesAndNewlines),
            returnRequirements: requirements
        )

        StorePolicyService.shared.addCustomPolicy(policy)
        HapticsService.shared.playSuccess()
        dismiss()
    }
}
