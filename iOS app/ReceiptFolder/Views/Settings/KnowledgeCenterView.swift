import SwiftUI

// MARK: - Searchable Data Model

private struct KnowledgeEntry: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let section: KnowledgeSection
}

private enum KnowledgeSection: String, CaseIterable, Identifiable {
    case features = "Features"
    case privacy = "Privacy"
    case accessibility = "Accessibility"
    case terms = "Terms & Conditions"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .features: "sparkles"
        case .privacy: "hand.raised.fill"
        case .accessibility: "accessibility"
        case .terms: "doc.plaintext.fill"
        }
    }

    var color: Color {
        // Editorial palette — only ink / signal / ember. Keeps semantic
        // distinction (terms are "caution" ember, others are neutral ink)
        // without reintroducing the old rainbow.
        switch self {
        case .features: RFColors.ink
        case .privacy: RFColors.ink
        case .accessibility: RFColors.ink
        case .terms: RFColors.ember
        }
    }
}

struct KnowledgeCenterView: View {
    @State private var searchText = ""
    @State private var expandedSections: Set<KnowledgeSection> = Set(KnowledgeSection.allCases)

    private let entries: [KnowledgeEntry] = Self.buildEntries()

    private var filteredEntries: [KnowledgeEntry] {
        guard !searchText.isEmpty else { return entries }
        let query = searchText.lowercased()
        return entries.filter {
            $0.title.lowercased().contains(query) ||
            $0.description.lowercased().contains(query)
        }
    }

    private var groupedEntries: [(section: KnowledgeSection, entries: [KnowledgeEntry])] {
        KnowledgeSection.allCases.compactMap { section in
            let matching = filteredEntries.filter { $0.section == section }
            guard !matching.isEmpty else { return nil }
            return (section: section, entries: matching)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if searchText.isEmpty {
                    heroHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                }

                if filteredEntries.isEmpty {
                    noResultsView
                        .padding(.top, 40)
                } else {
                    ForEach(groupedEntries, id: \.section) { group in
                        sectionCard(group.section, entries: group.entries)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                        if group.section != groupedEntries.last?.section {
                            RFPerforation()
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                        }
                    }
                }

                Spacer().frame(height: 60)
            }
        }
        .background(RFColors.paper)
        .navigationTitle("The Almanac")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search the almanac")
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Text("REFERENCE")
                    .font(RFFont.mono(10))
                    .tracking(1.8)
                    .foregroundStyle(RFColors.mute)
                Spacer()
                Text("\(entries.count) ENTRIES")
                    .font(RFFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.mute)
            }

            Rectangle().fill(RFColors.ink).frame(height: 2)

            HStack(alignment: .firstTextBaseline) {
                Text("The")
                    .font(RFFont.hero(44))
                    .foregroundStyle(RFColors.ink)
                Text("Almanac")
                    .font(.system(size: 44, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.signal)
                Spacer()
            }

            HStack {
                Text("Features, privacy, accessibility, and house terms.")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
                Spacer()
            }

            RFHairline()
        }
    }

    // MARK: - No Results

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Text("No matching entry.")
                .font(RFFont.title(24))
                .foregroundStyle(RFColors.ink)

            Text("Try a different term, or browse the sections directly.")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.mute)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Section

    private func sectionCard(_ section: KnowledgeSection, entries: [KnowledgeEntry]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedSections.contains(section) {
                        expandedSections.remove(section)
                    } else {
                        expandedSections.insert(section)
                    }
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(sectionRoman(section))
                        .font(RFFont.mono(11))
                        .tracking(1.4)
                        .foregroundStyle(RFColors.signal)

                    Text(section.rawValue.uppercased())
                        .font(RFFont.mono(11))
                        .tracking(1.8)
                        .foregroundStyle(RFColors.ink)

                    LeaderDots()

                    Text("\(entries.count)")
                        .font(RFFont.monoMedium(11))
                        .foregroundStyle(RFColors.mute)

                    if searchText.isEmpty {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(RFColors.ink)
                            .rotationEffect(.degrees(isExpanded(section) ? 90 : 0))
                    }
                }
                .padding(.vertical, 10)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if isExpanded(section) {
                RFHairline()
                    .padding(.bottom, 14)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        entryRow(entry)

                        if index < entries.count - 1 {
                            RFHairline()
                        }
                    }

                    if section == .terms {
                        Text("Last revised — April 2026")
                            .font(.system(size: 11, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(RFColors.mute)
                            .padding(.top, 8)
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    private func sectionRoman(_ section: KnowledgeSection) -> String {
        switch section {
        case .features: return "I."
        case .privacy: return "II."
        case .accessibility: return "III."
        case .terms: return "IV."
        }
    }

    private func isExpanded(_ section: KnowledgeSection) -> Bool {
        !searchText.isEmpty || expandedSections.contains(section)
    }

    // MARK: - Entry Row

    private func entryRow(_ entry: KnowledgeEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.title)
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundStyle(RFColors.ink)

            Text(entry.description)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.ink.opacity(0.78))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Data

    private static func buildEntries() -> [KnowledgeEntry] {
        var items: [KnowledgeEntry] = []

        // MARK: Features
        items.append(contentsOf: [
            KnowledgeEntry(
                title: "Receipt Scanning & OCR",
                description: "Point your camera at any receipt to automatically extract the store name, purchase date, and total amount using on-device optical character recognition. The AI-powered scanner works with printed and digital receipts. For best results, ensure good lighting and hold the receipt flat. You can also import photos from your library or drag and drop images.",
                section: .features
            ),
            KnowledgeEntry(
                title: "Return Window Tracking",
                description: "Never miss a return deadline again. Receipt Folder automatically calculates return window end dates based on our database of 100+ store return policies. Each item shows a visual progress bar indicating how much time remains. Items are color-coded by urgency: red (3 days or less), amber (4-14 days), and green (plenty of time).",
                section: .features
            ),
            KnowledgeEntry(
                title: "Warranty Management",
                description: "Track product warranties alongside return windows. Set custom warranty durations from 0 to 10 years. The app monitors warranty expiration and sends reminders at 90 days, 30 days, and 7 days before expiry — giving you time to inspect your products and file claims before coverage ends.",
                section: .features
            ),
            KnowledgeEntry(
                title: "Smart Notifications",
                description: "Receive intelligently-timed reminders based on urgency. Critical items (≤3 days) trigger notifications at 72 hours, 24 hours, and the morning of the last day. Warning-level items get alerts at 14 and 7 days. Warranty expiring items are flagged at 90, 30, and 7 days. You can customize the notification time in Settings and independently toggle return and warranty reminders.",
                section: .features
            ),
            KnowledgeEntry(
                title: "Store Policy Database",
                description: "Receipt Folder includes return policies for 100+ major retailers — from Amazon to Zara. Policies are automatically matched when you scan a receipt or enter a store name. Each policy includes the default return window, category-specific exceptions (e.g., electronics vs. clothing), return conditions, and a checklist of what to bring. Browse all policies in Settings → Store Policies.",
                section: .features
            ),
            KnowledgeEntry(
                title: "Return Mode",
                description: "Heading to the store? Open Return Mode for a one-screen summary of everything you need: the countdown timer, your receipt photo, item photo, store address with map, return policy details, and a checklist of what to bring. Designed to be shown at the return counter — no scrolling or searching required.",
                section: .features
            ),
            KnowledgeEntry(
                title: "Smart Return Decision Engine",
                description: "Not sure if a return is worth the trip? The Return Decision Engine analyzes your item's value, days remaining, store policy strictness, and restocking fees to generate a recommendation score (0-100). You'll see advice like \"Strongly recommend returning\" for high-value items near their deadline, or \"Probably keep it\" for low-value items with plenty of time.",
                section: .features
            ),
            KnowledgeEntry(
                title: "Insights & Analytics",
                description: "The Insights tab provides a visual overview of your receipt data: monthly spending trends with interactive charts, a breakdown by store, return statistics, and warranty coverage rates. Actionable recommendations highlight items expiring this week, money saved from returns, your most-shopped stores, and housekeeping suggestions to keep your vault organized.",
                section: .features
            ),
            KnowledgeEntry(
                title: "Widgets",
                description: "Add widgets to your Home Screen or Lock Screen for at-a-glance tracking. The Home Screen widget shows your top 3 most urgent items with color-coded urgency indicators. The Lock Screen widget displays your single most urgent item's countdown. Widgets update automatically every 6 hours and immediately when you add, archive, or return items.",
                section: .features
            ),
            KnowledgeEntry(
                title: "Item Photos",
                description: "Attach a photo of the actual product alongside the receipt. Useful for identifying which item a receipt belongs to, especially after holiday shopping sprees. Item photos appear in the detail view and Return Mode — helpful at the return counter when staff ask \"Which item are you returning?\"",
                section: .features
            ),
            KnowledgeEntry(
                title: "Batch Operations",
                description: "Managing multiple returns? Tap \"Edit\" in the Vault to enter multi-select mode. Select items individually or in bulk, then use the action bar to mark them as returned, archive them, or delete them — all at once. Perfect for post-holiday return runs or end-of-season closet cleanups.",
                section: .features
            ),
            KnowledgeEntry(
                title: "Search & Filters",
                description: "Find any receipt instantly with full-text search across product names, store names, notes, and prices. Activate filter chips to narrow results: Open Returns, Expiring Soon, Returned, or Has Warranty. Sort your vault by date, urgency, price, or store name. Filters appear only when searching — keeping the interface clean when you don't need them.",
                section: .features
            ),
            KnowledgeEntry(
                title: "Live Activities",
                description: "When a return deadline is 3 days away or less, Receipt Folder can display a Live Activity on your Lock Screen and Dynamic Island with a real-time countdown. The activity updates automatically and ends when the item is returned or the deadline passes.",
                section: .features
            ),
            KnowledgeEntry(
                title: "Siri Shortcuts",
                description: "Use your voice to interact with Receipt Folder. Say \"Show expiring items\" to jump to the Expiring tab, \"Add receipt\" to start scanning, or \"Check return window for [product name]\" to get an instant answer about how many days you have left. Shortcuts work from the Lock Screen, Spotlight, and the Shortcuts app.",
                section: .features
            ),
            KnowledgeEntry(
                title: "Calendar Integration",
                description: "Add return deadlines and warranty expiry dates directly to your Calendar app with one tap from the item detail view. Events include the store name, item name, and a reminder. Great for people who manage their schedule primarily through their calendar.",
                section: .features
            ),
            KnowledgeEntry(
                title: "Export & Backup",
                description: "Export all your receipt data anytime from Settings. Choose CSV format for spreadsheets (great for tax time and expense reports) or JSON for a complete data backup. Exported files can be shared via email, AirDrop, or saved to Files.",
                section: .features
            ),
            KnowledgeEntry(
                title: "Draft Auto-Save",
                description: "Accidentally close the add receipt screen? No worries — your progress is automatically saved as a draft. When you reopen the add flow, you'll be prompted to restore your previous work or start fresh. You can also explicitly save as a draft when cancelling.",
                section: .features
            ),
            KnowledgeEntry(
                title: "Biometric Lock & Encryption",
                description: "Protect your financial data with Face ID or Touch ID. When enabled, the app requires authentication every time it comes to the foreground. Receipt images are encrypted at rest using AES-256-GCM with a key stored in the device's Keychain — ensuring your data stays private even if someone accesses your device's file system.",
                section: .features
            ),
        ])

        // MARK: Privacy
        items.append(contentsOf: [
            KnowledgeEntry(
                title: "100% On-Device Processing",
                description: "All data processing happens entirely on your device. Receipt scanning uses Apple's Vision framework locally — your receipt images are never uploaded to any server. There is no cloud backend, no analytics service, and no third-party SDKs that collect data.",
                section: .privacy
            ),
            KnowledgeEntry(
                title: "Your Data Stays on Your Device",
                description: "All receipt data, images, and settings are stored locally on your iPhone. We do not have access to your data, and we cannot see what you store in the app. If you delete the app, all data is permanently removed.",
                section: .privacy
            ),
            KnowledgeEntry(
                title: "No Accounts Required",
                description: "Receipt Folder does not require you to create an account, sign in, or provide any personal information. There is no email collection, no phone number verification, and no social login.",
                section: .privacy
            ),
            KnowledgeEntry(
                title: "Encrypted Storage",
                description: "Receipt images are encrypted using industry-standard AES-256-GCM encryption. The encryption key is stored in the iOS Keychain, which is protected by the Secure Enclave. Even if the device storage is accessed directly, your receipt images cannot be read without the key.",
                section: .privacy
            ),
            KnowledgeEntry(
                title: "Camera & Photo Library",
                description: "Camera access is used only when you actively choose to scan a receipt. Photo library access is used only when you choose to import a photo. These permissions can be revoked at any time in iOS Settings. The app does not access your photos in the background.",
                section: .privacy
            ),
            KnowledgeEntry(
                title: "Notifications",
                description: "Notification content is generated entirely on-device based on your receipt data. Notifications are delivered via local scheduling — no push notification server is involved. You can disable notifications at any time in the app or via iOS Settings.",
                section: .privacy
            ),
            KnowledgeEntry(
                title: "Calendar & Contacts",
                description: "Calendar access is requested only when you choose to add a deadline to your calendar. The app does not read your existing calendar events. Receipt Folder never accesses your contacts.",
                section: .privacy
            ),
            KnowledgeEntry(
                title: "Spotlight Search",
                description: "Receipt items are indexed in Spotlight for convenient searching. This data stays on-device and is managed by iOS. If you delete an item, it is immediately removed from the Spotlight index.",
                section: .privacy
            ),
        ])

        // MARK: Accessibility
        items.append(contentsOf: [
            KnowledgeEntry(
                title: "VoiceOver",
                description: "Every screen in Receipt Folder is fully labeled for VoiceOver. Receipt items include detailed descriptions of urgency level, days remaining, prices, and store names. Action buttons have descriptive labels and hints. Navigation follows a logical reading order with grouped elements to minimize swipe counts.",
                section: .accessibility
            ),
            KnowledgeEntry(
                title: "Dynamic Type",
                description: "All text in the app respects your preferred text size from iOS Settings → Display & Brightness → Text Size. Layouts automatically adapt to accommodate larger text without truncation or overlap.",
                section: .accessibility
            ),
            KnowledgeEntry(
                title: "Bold Text",
                description: "When Bold Text is enabled in iOS Settings, Receipt Folder increases font weights throughout the interface for improved legibility. Key information like store names and deadlines becomes more prominent.",
                section: .accessibility
            ),
            KnowledgeEntry(
                title: "Color-Blind Accessibility",
                description: "Urgency levels are never communicated through color alone. Every colored indicator includes a text label (e.g., \"3d left\", \"Last day\", \"Active\"). This ensures users with color vision deficiencies can fully understand the status of their items.",
                section: .accessibility
            ),
            KnowledgeEntry(
                title: "Reduce Motion",
                description: "When Reduce Motion is enabled in iOS Settings, all animations (pulsing scan indicator, transition effects) are replaced with static equivalents. No content is lost — only the animation is removed.",
                section: .accessibility
            ),
            KnowledgeEntry(
                title: "Increase Contrast",
                description: "The app responds to the Increase Contrast accessibility setting by boosting text contrast and border visibility for improved readability in all lighting conditions.",
                section: .accessibility
            ),
            KnowledgeEntry(
                title: "Magic Tap",
                description: "On the item detail screen, the VoiceOver Magic Tap gesture (two-finger double-tap) opens Return Mode — providing instant access to the most important action without navigating menus.",
                section: .accessibility
            ),
            KnowledgeEntry(
                title: "Large Content Viewer",
                description: "Key interface elements support the Large Content Viewer, which displays an enlarged version when you long-press while zoomed in. This is particularly helpful for icon-heavy areas like the tab bar and action buttons.",
                section: .accessibility
            ),
        ])

        // MARK: Terms & Conditions
        items.append(contentsOf: [
            KnowledgeEntry(
                title: "Acceptance of Terms",
                description: "By downloading, installing, or using Receipt Folder (\"the App\"), you agree to be bound by these Terms and Conditions. If you do not agree with any part of these terms, you should not use the App.",
                section: .terms
            ),
            KnowledgeEntry(
                title: "Service Description",
                description: "Receipt Folder is a personal finance utility that helps users track purchase return windows and product warranties. The App provides tools for receipt scanning, deadline tracking, and notification reminders. All processing occurs on-device.",
                section: .terms
            ),
            KnowledgeEntry(
                title: "Store Policy Data",
                description: "Return policies included in the App are compiled from publicly available information and are provided for informational purposes only. Policies may change without notice. Receipt Folder does not guarantee the accuracy, completeness, or timeliness of store policy information. Always verify return policies directly with the retailer before making return decisions.",
                section: .terms
            ),
            KnowledgeEntry(
                title: "No Financial Advice",
                description: "The Smart Return Decision Engine and Insights recommendations are for informational purposes only and do not constitute financial advice. Return decisions should be based on your own judgment and circumstances.",
                section: .terms
            ),
            KnowledgeEntry(
                title: "User Responsibility",
                description: "You are responsible for the accuracy of data you enter into the App. Receipt Folder is a tracking tool — it does not guarantee that returns will be accepted by retailers. Meeting a return deadline tracked in the App does not guarantee a retailer will process your return.",
                section: .terms
            ),
            KnowledgeEntry(
                title: "Intellectual Property",
                description: "The App, including its design, code, and content, is the intellectual property of the developer. You are granted a limited, non-exclusive, non-transferable license to use the App for personal, non-commercial purposes.",
                section: .terms
            ),
            KnowledgeEntry(
                title: "Limitation of Liability",
                description: "To the maximum extent permitted by law, Receipt Folder and its developer shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including but not limited to loss of profits, data, or missed return deadlines, arising from your use of the App.",
                section: .terms
            ),
            KnowledgeEntry(
                title: "Modifications",
                description: "We reserve the right to modify these Terms at any time. Continued use of the App after changes constitutes acceptance of the updated Terms. Significant changes will be communicated through App updates.",
                section: .terms
            ),
        ])

        return items
    }
}
