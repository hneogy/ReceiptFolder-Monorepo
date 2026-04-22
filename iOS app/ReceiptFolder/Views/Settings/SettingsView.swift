import SwiftUI
import SwiftData
import TipKit

// MARK: - Appearance Mode

enum AppearanceMode: Int, CaseIterable, Identifiable {
    case system = 0
    case light = 1
    case dark = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Settings — rendered as the "colophon" of the receipt folder. Sections are
/// separated by perforations, rows use mono labels and serif values. The
/// notification time row reads like a schedule line in a printed timetable.
struct SettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode: Int = AppearanceMode.system.rawValue
    @AppStorage("returnNotificationsEnabled") private var returnNotifications = true
    @AppStorage("warrantyNotificationsEnabled") private var warrantyNotifications = true
    @AppStorage("defaultWarrantyYears") private var defaultWarrantyYears = 1
    @AppStorage("notificationHour") private var notificationHour = 8
    @AppStorage("notificationMinute") private var notificationMinute = 0

    @State private var showingExportOptions = false
    @State private var exportFileURL: URL?
    @State private var showingShareSheet = false
    @State private var showingTimePicker = false
    @State private var rescheduleTask: Task<Void, Never>?
    @State private var exportError: String?
    @Query private var allItems: [ReceiptItem]

    /// Coalesce rapid setting changes (spinning the DatePicker wheel fires both
    /// hour and minute onChange closures) into a single reschedule.
    private func scheduleRescheduleDebounced() {
        rescheduleTask?.cancel()
        rescheduleTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            NotificationScheduler.shared.rescheduleAll(items: allItems)
        }
    }

    private var notificationTime: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = notificationHour
                components.minute = notificationMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                notificationHour = components.hour ?? 8
                notificationMinute = components.minute ?? 0
            }
        )
    }

    private var notificationTimeFormatted: String {
        var components = DateComponents()
        components.hour = notificationHour
        components.minute = notificationMinute
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(.dateTime.hour().minute())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    masthead
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 28)

                    appearanceSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    RFPerforation().padding(.horizontal, 20).padding(.bottom, 24)

                    notificationsSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    RFPerforation().padding(.horizontal, 20).padding(.bottom, 24)

                    cloudSyncSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    RFPerforation().padding(.horizontal, 20).padding(.bottom, 24)

                    securitySection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    RFPerforation().padding(.horizontal, 20).padding(.bottom, 24)

                    defaultsSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    RFPerforation().padding(.horizontal, 20).padding(.bottom, 24)

                    libraryLinks
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    RFPerforation().padding(.horizontal, 20).padding(.bottom, 24)

                    colophon
                        .padding(.horizontal, 20)
                        .padding(.bottom, 120)
                }
            }
            .background(RFColors.paper)
            .navigationBarHidden(true)
            .onChange(of: notificationHour) { _, _ in scheduleRescheduleDebounced() }
            .onChange(of: notificationMinute) { _, _ in scheduleRescheduleDebounced() }
            .onChange(of: returnNotifications) { _, _ in scheduleRescheduleDebounced() }
            .onChange(of: warrantyNotifications) { _, _ in scheduleRescheduleDebounced() }
            .onDisappear { rescheduleTask?.cancel() }
            .sheet(isPresented: $showingTimePicker) {
                reminderTimePicker
            }
        }
    }

    // MARK: - Masthead

    private var masthead: some View {
        VStack(spacing: 10) {
            HStack {
                Text("COLOPHON")
                    .font(RFFont.mono(10))
                    .tracking(1.8)
                    .foregroundStyle(RFColors.mute)
                Spacer()
                Text("VERSION 1.0")
                    .font(RFFont.mono(10))
                    .tracking(1.2)
                    .foregroundStyle(RFColors.mute)
            }

            Rectangle().fill(RFColors.ink).frame(height: 2)

            HStack(alignment: .firstTextBaseline) {
                Text("Settings")
                    .font(RFFont.hero(52))
                    .foregroundStyle(RFColors.ink)
                Spacer()
            }

            HStack {
                Text("Preferences, defaults, and house matters.")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
                Spacer()
            }

            RFHairline()
                .padding(.top, 2)
        }
    }

    // MARK: - Appearance

    private var selectedAppearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceMode) ?? .system
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            RFEyebrow(text: "Appearance")

            HStack(spacing: 0) {
                ForEach(AppearanceMode.allCases) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            appearanceMode = mode.rawValue
                        }
                    } label: {
                        appearanceOption(mode: mode)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mode.label)
                    .accessibilityAddTraits(selectedAppearance == mode ? .isSelected : [])
                }
            }
            .overlay(Rectangle().stroke(RFColors.ink, lineWidth: 0.75))
        }
    }

    private func appearanceOption(mode: AppearanceMode) -> some View {
        let selected = selectedAppearance == mode
        return VStack(spacing: 8) {
            Image(systemName: mode.icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(selected ? RFColors.paper : RFColors.ink)
            Text(mode.label)
                .font(.system(size: 13, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(selected ? RFColors.paper : RFColors.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(selected ? RFColors.ink : Color.clear)
    }

    // MARK: - Notifications
    //
    // Includes the "alarm" / reminder time row. Rendered as a schedule line:
    //   REMINDER TIME ············ 8:00 AM
    // Tapping it opens a sheet with a full-page time picker.

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            RFEyebrow(text: "Reminders")

            toggleRow(
                title: "Return window reminders",
                caption: "Alerts at 14, 7, 3, and 1 days out",
                isOn: $returnNotifications
            )

            RFHairline()

            toggleRow(
                title: "Warranty expiry reminders",
                caption: "Alerts at 90, 30, and 7 days out",
                isOn: $warrantyNotifications
            )

            RFHairline()

            Button {
                showingTimePicker = true
            } label: {
                scheduleRow(
                    label: "Reminder time",
                    value: notificationTimeFormatted,
                    caption: "The hour at which daily alerts are delivered"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func toggleRow(title: String, caption: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(RFColors.ink)
                Text(caption)
                    .font(RFFont.mono(10))
                    .tracking(0.8)
                    .foregroundStyle(RFColors.mute)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(RFColors.ink)
        }
        .padding(.vertical, 12)
    }

    private func scheduleRow(label: String, value: String, caption: String) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label.uppercased())
                    .font(RFFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.mute)

                LeaderDots()

                Text(value)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundStyle(RFColors.ink)
            }

            HStack {
                Text(caption)
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
                Spacer()
            }
        }
        .padding(.vertical, 12)
        .contentShape(.rect)
    }

    // MARK: - Reminder time picker sheet
    //
    // The "alarm" page. A full-bleed time picker on cream, with a serif
    // masthead and a big mono rendering of the current time.

    private var reminderTimePicker: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    HStack {
                        Text("ALERT · SCHEDULE")
                            .font(RFFont.mono(10))
                            .tracking(1.8)
                            .foregroundStyle(RFColors.mute)
                        Spacer()
                        Text("DAILY")
                            .font(RFFont.mono(10))
                            .tracking(1.4)
                            .foregroundStyle(RFColors.mute)
                    }
                    Rectangle().fill(RFColors.ink).frame(height: 2)

                    HStack(alignment: .firstTextBaseline) {
                        Text("Reminder")
                            .font(RFFont.hero(48))
                            .foregroundStyle(RFColors.ink)
                        Text("Time")
                            .font(.system(size: 48, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(RFColors.signal)
                        Spacer()
                    }

                    HStack {
                        Text("Deadline alerts arrive each day at this time.")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(RFColors.mute)
                        Spacer()
                    }

                    RFHairline()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()

                Text(notificationTimeFormatted)
                    .font(.system(size: 96, weight: .regular, design: .serif))
                    .foregroundStyle(RFColors.ink)
                    .padding(.bottom, 12)

                Text(notificationTime.wrappedValue.formatted(.dateTime.weekday(.wide)).uppercased() + " · DELIVERED DAILY")
                    .font(RFFont.mono(11))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.mute)
                    .padding(.bottom, 24)

                RFPerforation()
                    .padding(.horizontal, 40)
                    .padding(.bottom, 16)

                DatePicker(
                    "",
                    selection: notificationTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)

                Spacer()

                Button("Done") { showingTimePicker = false }
                    .buttonStyle(RFPrimaryButtonStyle())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
            .background(RFColors.paper)
            .navigationBarHidden(true)
        }
    }

    // MARK: - iCloud Sync

    private var cloudSyncSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            RFEyebrow(text: "Sync")

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("ICLOUD")
                    .font(RFFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.mute)

                LeaderDots()

                Text(cloudStatusText)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(cloudStatusColor)
            }
            .padding(.vertical, 4)

            Text(cloudCaption)
                .font(.system(size: 13, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.mute)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            await CloudSyncService.shared.checkAccountStatus()
        }
    }

    private var cloudStatusText: String {
        switch CloudSyncService.shared.accountStatus {
        case .available: return "Syncing"
        case .noAccount: return "Signed out"
        case .restricted: return "Restricted"
        case .temporarilyUnavailable: return "Unavailable"
        default: return "Checking"
        }
    }

    private var cloudStatusColor: Color {
        switch CloudSyncService.shared.accountStatus {
        case .available: return RFColors.ink
        case .noAccount, .restricted: return RFColors.signal
        case .temporarilyUnavailable: return RFColors.ember
        default: return RFColors.mute
        }
    }

    private var cloudCaption: String {
        if CloudSyncService.shared.iCloudAvailable {
            return "Receipts, photos, and policies are synced across your devices."
        } else if CloudSyncService.shared.accountStatus == .noAccount {
            return "Sign in to iCloud in the system Settings app to enable sync."
        } else {
            return CloudSyncService.shared.statusDescription
        }
    }

    // MARK: - Security

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            RFEyebrow(text: "Security")

            toggleRow(
                title: "Lock with \(BiometricAuthService.shared.biometricName)",
                caption: "Require biometric authentication to open the app",
                isOn: Binding(
                    get: { BiometricAuthService.shared.isAppLockEnabled },
                    set: { newValue in
                        Task {
                            if newValue {
                                let success = await BiometricAuthService.shared.authenticate()
                                if success {
                                    BiometricAuthService.shared.isAppLockEnabled = true
                                }
                            } else {
                                BiometricAuthService.shared.isAppLockEnabled = false
                            }
                        }
                    }
                )
            )
        }
    }

    // MARK: - Defaults

    private var defaultsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            RFEyebrow(text: "Defaults")

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("DEFAULT WARRANTY")
                    .font(RFFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.mute)

                LeaderDots()

                Stepper(
                    value: $defaultWarrantyYears,
                    in: 0...10
                ) {
                    Text("\(defaultWarrantyYears) year\(defaultWarrantyYears == 1 ? "" : "s")")
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .foregroundStyle(RFColors.ink)
                }
                .labelsHidden()
                .overlay(
                    Text("\(defaultWarrantyYears) year\(defaultWarrantyYears == 1 ? "" : "s")")
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .foregroundStyle(RFColors.ink)
                        .padding(.trailing, 96),
                    alignment: .trailing
                )
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Library / navigation links

    private var libraryLinks: some View {
        VStack(alignment: .leading, spacing: 0) {
            RFEyebrow(text: "Library")
                .padding(.bottom, 8)

            navLink(destination: AnyView(StorePolicyListView()),
                    label: "Store policies",
                    value: "\(StorePolicyService.shared.allPolicies().count)")

            RFHairline()

            navLink(destination: AnyView(ArchivedItemsView()),
                    label: "Archived items",
                    value: nil)

            RFHairline()

            navLink(destination: AnyView(KnowledgeCenterView()),
                    label: "Knowledge center",
                    value: nil)

            RFHairline()

            navLink(destination: AnyView(FamilySharingView()),
                    label: "Family sharing",
                    value: nil)

            RFHairline()

            navLink(destination: AnyView(ChangelogView()),
                    label: "Release notes",
                    value: "v1.4")

            RFHairline()

            exportRow
        }
    }

    private func navLink(destination: AnyView, label: String, value: String?) -> some View {
        NavigationLink {
            destination
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label.uppercased())
                    .font(RFFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.mute)

                LeaderDots()

                if let value {
                    Text(value)
                        .font(RFFont.monoMedium(12))
                        .foregroundStyle(RFColors.ink)
                    Text("→")
                        .font(RFFont.mono(12))
                        .foregroundStyle(RFColors.mute)
                } else {
                    Text("→")
                        .font(RFFont.mono(12))
                        .foregroundStyle(RFColors.mute)
                }
            }
            .padding(.vertical, 14)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var exportRow: some View {
        Button {
            showingExportOptions = true
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("EXPORT DATA")
                    .font(RFFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.mute)

                LeaderDots()

                Text("\(allItems.count) items")
                    .font(RFFont.monoMedium(12))
                    .foregroundStyle(RFColors.ink)
                Text("→")
                    .font(RFFont.mono(12))
                    .foregroundStyle(RFColors.mute)
            }
            .padding(.vertical, 14)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("button.exportData")
        .confirmationDialog("Export Format", isPresented: $showingExportOptions) {
            Button("CSV (Spreadsheet)") { runExport(.csv) }
            Button("JSON (Full Data)") { runExport(.json) }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportFileURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Couldn't export", isPresented: .init(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    private func runExport(_ format: ExportService.ExportFormat) {
        Task {
            if let url = await ExportService.exportItems(allItems, format: format) {
                exportFileURL = url
                showingShareSheet = true
            } else {
                exportError = "The file could not be written. Please try again."
            }
        }
    }

    // MARK: - Colophon
    //
    // Footer in printed-book colophon style.

    private var colophon: some View {
        VStack(spacing: 12) {
            Rectangle().fill(RFColors.ink).frame(height: 2)

            Text("RECEIPT FOLDER")
                .font(RFFont.mono(11))
                .tracking(2.4)
                .foregroundStyle(RFColors.ink)
                .padding(.top, 8)

            Text("An almanac of returns & warranties.")
                .font(.system(size: 13, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.mute)

            HStack(spacing: 16) {
                colophonKV(label: "Version", value: "1.0.0")
                colophonKV(label: "Build", value: "2026.04")
                colophonKV(label: "Platform", value: "iOS 17+")
            }
            .padding(.top, 12)

            Button {
                if let url = URL(string: "https://neogy.dev/") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Set by Honorius M. Neogy")
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .italic()
                    .underline()
                    .foregroundStyle(RFColors.ink)
            }
            .buttonStyle(.plain)
            .padding(.top, 12)

            Text("⬦")
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(RFColors.mute)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private func colophonKV(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(RFFont.mono(9))
                .tracking(1.2)
                .foregroundStyle(RFColors.mute)
            Text(value)
                .font(RFFont.monoMedium(11))
                .foregroundStyle(RFColors.ink)
        }
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
