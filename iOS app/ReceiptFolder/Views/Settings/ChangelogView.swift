import SwiftUI

/// "Dispatches" — the editorial changelog. Each release is rendered as a
/// front-page-style dispatch with a version masthead, date dateline, and a
/// body of itemized changes. Entries are authored inline so designers can
/// tweak language without round-tripping through a data file.
struct ChangelogView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                masthead
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 28)

                ForEach(Self.releases) { release in
                    dispatchCard(release)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)

                    if release.id != Self.releases.last?.id {
                        RFPerforation()
                            .padding(.horizontal, 20)
                            .padding(.bottom, 28)
                    }
                }

                colophon
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 120)
            }
        }
        .background(RFColors.paper)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Masthead

    private var masthead: some View {
        VStack(spacing: 12) {
            HStack {
                Text("RECEIPT · FOLDER")
                    .font(RFFont.mono(10))
                    .tracking(1.8)
                    .foregroundStyle(RFColors.mute)
                Spacer()
                Text("DISPATCHES")
                    .font(RFFont.mono(10))
                    .tracking(1.8)
                    .foregroundStyle(RFColors.mute)
            }

            Rectangle().fill(RFColors.ink).frame(height: 2)

            HStack(alignment: .firstTextBaseline) {
                Text("Release")
                    .font(RFFont.hero(48))
                    .foregroundStyle(RFColors.ink)
                Text("Notes")
                    .font(.system(size: 48, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.signal)
                Spacer()
            }

            HStack {
                Text("Editorial dispatches on what's changed, and why.")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
                Spacer()
            }

            RFHairline().padding(.top, 2)
        }
    }

    // MARK: - Dispatch card

    private func dispatchCard(_ release: Release) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("VOL. \(release.volume)")
                    .font(RFFont.mono(10))
                    .tracking(1.6)
                    .foregroundStyle(RFColors.mute)
                Spacer()
                Text(release.dateline.uppercased())
                    .font(RFFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.mute)
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("v\(release.version)")
                    .font(RFFont.hero(32))
                    .foregroundStyle(RFColors.ink)
                Text(release.codename)
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.signal)
                Spacer()
            }

            Text(release.lede)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundStyle(RFColors.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(release.items) { entry in
                    entryRow(entry)
                }
            }
            .padding(.top, 8)
        }
    }

    private func entryRow(_ entry: ReleaseItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(entry.tag.label)
                .font(RFFont.mono(9))
                .tracking(1.2)
                .foregroundStyle(RFColors.paper)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(entry.tag.color)
                .frame(width: 64, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(RFColors.ink)
                if let detail = entry.detail {
                    Text(detail)
                        .font(.system(size: 13, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(RFColors.mute)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var colophon: some View {
        VStack(spacing: 8) {
            Rectangle().fill(RFColors.ink).frame(height: 2)
            Text("END · OF · DISPATCHES")
                .font(RFFont.mono(11))
                .tracking(2.4)
                .foregroundStyle(RFColors.mute)
                .padding(.top, 10)
            Text("⬦")
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(RFColors.mute)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Data

private struct Release: Identifiable {
    let id: String
    let version: String
    let codename: String
    let volume: String
    let dateline: String
    let lede: String
    let items: [ReleaseItem]
}

private struct ReleaseItem: Identifiable {
    let id = UUID()
    let tag: Tag
    let title: String
    let detail: String?

    enum Tag {
        case new, fixed, improved, polish

        var label: String {
            switch self {
            case .new: "NEW"
            case .fixed: "FIXED"
            case .improved: "BETTER"
            case .polish: "POLISH"
            }
        }

        var color: Color {
            switch self {
            case .new: RFColors.signal
            case .fixed: RFColors.ember
            case .improved: RFColors.ink
            case .polish: RFColors.mute
            }
        }
    }
}

private extension ChangelogView {
    static let releases: [Release] = [
        Release(
            id: "1.4.1",
            version: "1.4.1",
            codename: "Smarter inbox, leaner sync.",
            volume: "I, No. 7",
            dateline: "May 2026",
            lede: "Two quality passes behind the scenes. Email import now works for every retailer, not just the three we templated — thanks to Apple Intelligence. Household sync drops to deltas so even a thousand-receipt household is cheap to refresh.",
            items: [
                ReleaseItem(tag: .new, title: "Apple Intelligence email fallback", detail: "Any retailer we don't yet template goes through Apple's on-device language model. Store, product, date, price — extracted directly from the email. iOS 26+."),
                ReleaseItem(tag: .improved, title: "Change-token delta sync for households", detail: "A silent push used to trigger a full re-download of every shared receipt; now we only pull what actually changed. Huge bandwidth win for large households."),
                ReleaseItem(tag: .improved, title: "Per-zone token persistence", detail: "Cold launches no longer re-download the world — CloudKit tokens persist across app restarts."),
                ReleaseItem(tag: .polish, title: "16 new unit tests + 2-account TestFlight plan", detail: "Regression coverage for the household + email-import code paths, plus a documented manual test plan for release candidates."),
            ]
        ),
        Release(
            id: "1.4.0",
            version: "1.4.0",
            codename: "Household, out of beta.",
            volume: "I, No. 6",
            dateline: "May 2026",
            lede: "A two-week sprint took household sharing from a scaffolded invite flow to a real, live-syncing second vault. Shared items now appear in both devices' vaults, changes mirror within seconds, and photos travel with them.",
            items: [
                ReleaseItem(tag: .new, title: "Shared items in the vault", detail: "A \"Household\" section at the bottom of the vault shows receipts your co-owner has shared with you. Same on iPhone, iPad, and Mac."),
                ReleaseItem(tag: .new, title: "Live sync via CloudKit push", detail: "Silent pushes from both the private and shared CloudKit databases mean a change on one device lands on the other within seconds — no refresh button needed."),
                ReleaseItem(tag: .improved, title: "Photos mirror too", detail: "Receipt and item images now travel with shared records as CKAssets. Your co-owner sees what you see."),
                ReleaseItem(tag: .improved, title: "Automatic sync on every edit", detail: "Toggle \"Share with household\" or edit a shared item; the mirror updates on save. No more manual Sync button."),
                ReleaseItem(tag: .improved, title: "Cascade delete", detail: "Archive, un-share, or delete a receipt and its mirrored copy disappears from the household zone too."),
                ReleaseItem(tag: .polish, title: "Beta label retired", detail: "Family sharing is now a first-class feature."),
            ]
        ),
        Release(
            id: "1.3.0",
            version: "1.3.0",
            codename: "The quarter's work.",
            volume: "I, No. 5",
            dateline: "April 2026",
            lede: "Three months of hard, careful work. A native Mac app, email receipt import, an interactive lock-screen widget, proof-of-return capture, and a household-sharing beta — all the P0 and P1 items on the 5-star roadmap, shipped.",
            items: [
                ReleaseItem(tag: .new, title: "Native macOS companion", detail: "A proper Mac app — not a Catalyst port. NavigationSplitView sidebar, menu-bar commands (⌘N, ⌘F, ⌘E), and iCloud sync with iPhone & iPad."),
                ReleaseItem(tag: .new, title: "Email receipt import", detail: "Share any digital receipt from Mail (Amazon, Apple, Best Buy). Parsed on-device, never uploaded."),
                ReleaseItem(tag: .new, title: "Tap-to-return widget", detail: "Lock-screen widgets are interactive. Mark an item returned without opening the app."),
                ReleaseItem(tag: .new, title: "Proof-of-return capture", detail: "When you mark an item returned, snap a photo of the return-counter receipt. Your paper trail for disputes."),
                ReleaseItem(tag: .new, title: "Household sharing · Beta", detail: "Opt-in, per-receipt. A co-owner sees only what you choose to share — through your iCloud, never through us."),
                ReleaseItem(tag: .improved, title: "One-screen onboarding", detail: "Three screens collapsed to one. Try it with a pre-built sample receipt in under thirty seconds."),
                ReleaseItem(tag: .polish, title: "Review prompt, respectfully", detail: "We only ask after you've used the app for a week and marked something returned."),
            ]
        ),
        Release(
            id: "1.2.0",
            version: "1.2.0",
            codename: "The calendar & the map.",
            volume: "I, No. 4",
            dateline: "February 2026",
            lede: "Connecting Receipt Folder to the systems you already live in — your calendar, your home screen, your Siri shortcuts.",
            items: [
                ReleaseItem(tag: .new, title: "Calendar integration", detail: "Add return deadlines and warranty expiries to your calendar with one tap."),
                ReleaseItem(tag: .new, title: "Siri shortcuts", detail: "\"Hey Siri, show expiring items.\" \"Check return window.\""),
                ReleaseItem(tag: .new, title: "Spotlight search", detail: "Find receipts from the system search — same as Messages, Mail, or Notes."),
                ReleaseItem(tag: .improved, title: "Faster OCR on dark receipts", detail: "Receipt photos now go through CoreImage enhancement before Vision."),
            ]
        ),
        Release(
            id: "1.1.0",
            version: "1.1.0",
            codename: "Urgency, made visible.",
            volume: "I, No. 3",
            dateline: "December 2025",
            lede: "The days-remaining countdown is the heart of the app. This release made it unignorable.",
            items: [
                ReleaseItem(tag: .new, title: "Live Activities", detail: "When a return window drops to three days, a countdown appears on your lock screen."),
                ReleaseItem(tag: .new, title: "Return Mode", detail: "A fullscreen, in-store view — your receipt, the barcode, the policy, all at once."),
                ReleaseItem(tag: .improved, title: "Urgency color system", detail: "Red for ≤3 days. Amber for 4–14. Green beyond. Semantic through and through."),
                ReleaseItem(tag: .polish, title: "Countdown typography", detail: "Large serif numerals, printed-almanac feel."),
            ]
        ),
        Release(
            id: "1.0.0",
            version: "1.0.0",
            codename: "The first issue.",
            volume: "I, No. 1",
            dateline: "October 2025",
            lede: "Receipt Folder's first public release. Scan a receipt, track the return window, honor the warranty. On your device. No account. Free, forever.",
            items: [
                ReleaseItem(tag: .new, title: "Receipt scanning", detail: "On-device OCR via Apple Vision. 9 languages."),
                ReleaseItem(tag: .new, title: "50 retailer policies", detail: "Bundled offline — Target, Best Buy, Apple, and 47 more."),
                ReleaseItem(tag: .new, title: "Warranty tracking", detail: "Set a warranty term; get alerts at 90, 30, and 7 days."),
                ReleaseItem(tag: .new, title: "Full export", detail: "CSV or JSON. No paywall. Your data is yours."),
            ]
        ),
    ]
}
