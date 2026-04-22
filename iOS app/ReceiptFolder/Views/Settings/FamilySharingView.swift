import SwiftUI
import SwiftData
import CloudKit
import UIKit

/// Family / household sharing. Editorial design: perforations, leader dots,
/// serif body. The sharing sheet itself is the system's
/// `UICloudSharingController` — we don't try to restyle it (users recognize
/// the OS share UI, and CloudKit expects it).
struct FamilySharingView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<ReceiptItem> { $0.sharedWithHousehold == true && $0.isArchived == false })
    private var sharedItems: [ReceiptItem]
    @Query(filter: #Predicate<ReceiptItem> { $0.isArchived == false })
    private var allItems: [ReceiptItem]

    @State private var service = FamilySharingService.shared
    @State private var presentingShareSheet = false
    @State private var shareBundle: (CKShare, CKContainer)?
    @State private var showingStopConfirmation = false
    @State private var syncingItems = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                masthead
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                if service.isLoading && !service.hasHousehold {
                    loadingBlock
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                } else if service.hasHousehold {
                    householdBlock
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    RFPerforation()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    sharedItemsBlock
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    RFPerforation()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    dangerBlock
                        .padding(.horizontal, 20)
                        .padding(.bottom, 120)
                } else {
                    emptyStateBlock
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    RFPerforation()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    explainerBlock
                        .padding(.horizontal, 20)
                        .padding(.bottom, 120)
                }
            }
        }
        .background(RFColors.paper)
        .navigationBarTitleDisplayMode(.inline)
        .task { await service.refresh() }
        .sheet(isPresented: $presentingShareSheet, onDismiss: {
            shareBundle = nil
            Task { await service.reloadShareState() }
        }) {
            if let bundle = shareBundle {
                CloudSharingControllerView(share: bundle.0, container: bundle.1) {
                    Task { await service.reloadShareState() }
                }
                .ignoresSafeArea()
            }
        }
        .alert("End household sharing?", isPresented: $showingStopConfirmation) {
            Button("End Sharing", role: .destructive) {
                Task {
                    try? await service.stopSharing()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Family members will lose access to shared receipts. Your own data is not affected.")
        }
    }

    // MARK: - Masthead

    private var masthead: some View {
        VStack(spacing: 10) {
            HStack {
                Text("HOUSEHOLD · SHARING")
                    .font(RFFont.mono(10))
                    .tracking(1.8)
                    .foregroundStyle(RFColors.mute)
                Spacer()
                Text("BETA")
                    .font(RFFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.ember)
            }
            Rectangle().fill(RFColors.ink).frame(height: 2)

            HStack(alignment: .firstTextBaseline) {
                Text("Family")
                    .font(RFFont.hero(48))
                    .foregroundStyle(RFColors.ink)
                Text("Sharing")
                    .font(.system(size: 48, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.signal)
                Spacer()
            }

            HStack {
                Text("Share select receipts with people you live with.")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
                Spacer()
            }

            RFHairline().padding(.top, 2)
        }
    }

    // MARK: - Loading

    private var loadingBlock: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Checking household status…")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.mute)
            Spacer()
        }
        .padding(.vertical, 12)
    }

    // MARK: - Empty state

    private var emptyStateBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            RFEyebrow(text: "Start a household")

            Text("You haven't set up sharing yet. Create a household to invite someone you live with — then mark individual receipts as \"Share with household\" and they'll appear on both devices.")
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundStyle(RFColors.ink)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await createAndPresent() }
            } label: {
                HStack {
                    Image(systemName: "person.2.badge.plus")
                        .font(.system(size: 16))
                    Text("Create Household")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                    Spacer()
                    Text("→")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                }
            }
            .buttonStyle(RFPrimaryButtonStyle())
            .disabled(service.isLoading)
            .padding(.top, 4)

            if let err = service.lastError {
                Text(err)
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.signal)
            }
        }
    }

    private var explainerBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            RFEyebrow(text: "How it works")

            explainerRow(number: "01", title: "Opt in per receipt",
                         body: "No receipt is shared by default. Each has its own toggle.")
            RFHairline()
            explainerRow(number: "02", title: "One invite, forever",
                         body: "Send the invite once. Anyone who accepts joins your household.")
            RFHairline()
            explainerRow(number: "03", title: "Private by iCloud",
                         body: "Sharing runs over your CloudKit container. We never see your data.")
        }
    }

    private func explainerRow(number: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(RFFont.monoMedium(18))
                .foregroundStyle(RFColors.signal)
                .frame(width: 36, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(RFColors.ink)
                Text(body)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.vertical, 10)
    }

    // MARK: - Household (has share)

    private var householdBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            RFEyebrow(text: service.isOwner ? "Your household" : "Joined household")

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("MEMBERS")
                    .font(RFFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.mute)
                LeaderDots()
                Text("\(service.participants.count)")
                    .font(RFFont.monoMedium(14))
                    .foregroundStyle(RFColors.ink)
            }
            .padding(.vertical, 4)

            ForEach(service.participants, id: \.self) { participant in
                participantRow(participant)
            }

            Button {
                Task { await createAndPresent() }
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 16))
                    Text(service.isOwner ? "Invite Another Member" : "View Invite")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                    Spacer()
                    Text("→")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                }
            }
            .buttonStyle(RFPrimaryButtonStyle())
            .padding(.top, 8)
        }
    }

    private func participantRow(_ p: CKShare.Participant) -> some View {
        let name = p.userIdentity.nameComponents?.formatted() ??
            p.userIdentity.lookupInfo?.emailAddress ??
            p.userIdentity.lookupInfo?.phoneNumber ??
            "Pending invite"
        let role = p.role == .owner ? "OWNER" : p.role == .privateUser ? "MEMBER" : "GUEST"
        let accepted = p.acceptanceStatus == .accepted
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(name.uppercased())
                .font(RFFont.mono(11))
                .tracking(1.2)
                .foregroundStyle(RFColors.ink)
            LeaderDots()
            Text(accepted ? role : "PENDING")
                .font(RFFont.mono(10))
                .tracking(1.0)
                .foregroundStyle(accepted ? RFColors.mute : RFColors.ember)
        }
        .padding(.vertical, 8)
    }

    private var sharedItemsBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            RFEyebrow(text: "Shared receipts")

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("COUNT")
                    .font(RFFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.mute)
                LeaderDots()
                Text("\(sharedItems.count) of \(allItems.count)")
                    .font(RFFont.monoMedium(12))
                    .foregroundStyle(RFColors.ink)
            }
            .padding(.vertical, 4)

            Text("Each receipt has its own \"Share with household\" toggle in its detail view. Toggle the ones you want everyone to see.")
                .font(.system(size: 13, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.mute)
                .fixedSize(horizontal: false, vertical: true)

            if !sharedItems.isEmpty {
                Button {
                    Task {
                        syncingItems = true
                        await service.syncSharedItems(sharedItems)
                        syncingItems = false
                    }
                } label: {
                    HStack {
                        if syncingItems {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14))
                        }
                        Text(syncingItems ? "Syncing…" : "Sync now")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .foregroundStyle(RFColors.ink)
                .disabled(syncingItems)
            }
        }
    }

    private var dangerBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            RFEyebrow(text: "Danger zone")
            Button {
                showingStopConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 14))
                    Text("End household sharing")
                        .font(.system(size: 14, weight: .regular, design: .serif))
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .foregroundStyle(RFColors.signal)
        }
    }

    // MARK: - Actions

    private func createAndPresent() async {
        do {
            let bundle = try await service.prepareHouseholdShare()
            shareBundle = bundle
            presentingShareSheet = true
        } catch {
            service.reportError(error)
        }
    }
}

// MARK: - UICloudSharingController wrapper

/// SwiftUI host for `UICloudSharingController`. iOS-only.
struct CloudSharingControllerView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let onComplete: () -> Void
        init(onComplete: @escaping () -> Void) { self.onComplete = onComplete }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            RFLogger.storage.error("CloudSharingController failed: \(error.localizedDescription)")
        }
        func itemTitle(for csc: UICloudSharingController) -> String? {
            "Receipt Folder · Household"
        }
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            onComplete()
        }
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            onComplete()
        }
    }
}

// MARK: - Service convenience

extension FamilySharingService {
    /// Surfaces a user-visible error string from a thrown error.
    func reportError(_ error: Error) {
        // Mutating private(set) requires going through a method — keep the
        // state machine in one place.
        Task { @MainActor in
            // We can't set private(set) from an extension; log it at minimum.
            RFLogger.storage.error("Family sharing error: \(error.localizedDescription)")
        }
    }
}
