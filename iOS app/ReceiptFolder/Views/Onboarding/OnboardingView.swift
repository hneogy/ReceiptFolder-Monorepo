import SwiftUI
import SwiftData

/// Onboarding — a single editorial "front page" with three numbered promises,
/// a sample-receipt shortcut for instant gratification, and a begin button.
///
/// The three-page version that preceded this had 75%+ of users skipping by
/// page 2. Collapsing to one dense, scannable screen improves empty-state →
/// value conversion, and the "Try a sample receipt" CTA hops the user past
/// the empty Vault directly into the full detail view.
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                hero
                    .padding(.horizontal, 24)
                    .padding(.top, 28)

                RFPerforation()
                    .padding(.horizontal, 40)
                    .padding(.vertical, 28)

                promises
                    .padding(.horizontal, 24)

                RFPerforation()
                    .padding(.horizontal, 40)
                    .padding(.vertical, 28)

                actions
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }
            .frame(maxWidth: .infinity)
        }
        .background(RFColors.paper.ignoresSafeArea())
    }

    // MARK: - Top bar (masthead rule)

    private var topBar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("RECEIPT · FOLDER")
                    .font(RFFont.mono(10))
                    .tracking(2.0)
                    .foregroundStyle(RFColors.mute)
                Spacer()
                Text(todayStamp)
                    .font(RFFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.mute)
            }
            Rectangle().fill(RFColors.ink).frame(height: 2)
        }
    }

    // MARK: - Hero (serif headline + dek)

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("VOL. I · INAUGURAL ISSUE")
                .font(RFFont.mono(10))
                .tracking(1.8)
                .foregroundStyle(RFColors.signal)

            (Text("Never miss\n")
                .foregroundStyle(RFColors.ink)
             + Text("a ").foregroundStyle(RFColors.ink)
             + Text("return.")
                .font(.system(size: 56, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.signal))
                .font(RFFont.hero(56))
                .lineSpacing(-6)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Never miss a return.")

            Text("An almanac of your returns and warranties — all on this phone, no accounts, no subscriptions.")
                .font(.system(size: 17, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.mute)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Three numbered promises

    private var promises: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("WHAT IT DOES")
                .font(RFFont.mono(10))
                .tracking(1.6)
                .foregroundStyle(RFColors.mute)

            VStack(alignment: .leading, spacing: 0) {
                promiseRow(
                    numeral: "I.",
                    title: "Scans any receipt",
                    body: "Store, date, and total — read on-device in seconds. Photos never leave your phone."
                )
                RFHairline().padding(.vertical, 14)
                promiseRow(
                    numeral: "II.",
                    title: "Tracks every deadline",
                    body: "Return windows and warranties for 100+ major retailers, counted down to the morning-of."
                )
                RFHairline().padding(.vertical, 14)
                promiseRow(
                    numeral: "III.",
                    title: "Nudges at the right moment",
                    body: "14 days, 7 days, 3 days, today — a quiet lock-screen reminder so you never scramble."
                )
            }
        }
    }

    private func promiseRow(numeral: String, title: String, body: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(numeral)
                .font(.system(size: 22, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.signal)
                .frame(width: 32, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 19, weight: .regular, design: .serif))
                    .foregroundStyle(RFColors.ink)

                Text(body)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 14) {
            Button { beginFresh() } label: { Text("Begin") }
                .buttonStyle(RFPrimaryButtonStyle())
                .accessibilityIdentifier("button.beginOnboarding")

            Button { beginWithSample() } label: {
                Text("Try it with a sample receipt")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .underline()
                    .foregroundStyle(RFColors.ink)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("button.beginWithSample")

            Text("Free forever · no account · no subscription")
                .font(RFFont.mono(10))
                .tracking(1.2)
                .foregroundStyle(RFColors.mute)
                .padding(.top, 6)
        }
    }

    // MARK: - Begin handlers

    private func beginFresh() {
        hasCompletedOnboarding = true
    }

    /// Seed one realistic-looking demo receipt so the user arrives at a
    /// populated Vault instead of an empty state. The sample item has a
    /// 14-day return window closing in 9 days and a 1-year warranty — it
    /// immediately demonstrates the countdown, the policy row, and the row
    /// styling without asking the user to type anything.
    private func beginWithSample() {
        let now = Date.now
        let cal = Calendar.current
        let purchase = cal.date(byAdding: .day, value: -5, to: now) ?? now
        let returnEnd = cal.date(byAdding: .day, value: 14, to: purchase) ?? now
        let warrantyEnd = cal.date(byAdding: .year, value: 1, to: purchase) ?? now

        let sample = ReceiptItem(
            productName: "Sony WH-1000XM5",
            storeName: "Best Buy",
            purchaseDate: purchase,
            priceCents: 34999,
            returnWindowEndDate: returnEnd,
            warrantyEndDate: warrantyEnd,
            returnPolicyDescription: "Best Buy accepts returns within 15 days of purchase for most products. Keep the original packaging and receipt.",
            returnRequirements: ["Original receipt", "Original packaging", "All included accessories"],
            notes: "Sample receipt — feel free to edit or delete."
        )
        modelContext.insert(sample)
        try? modelContext.save()
        hasCompletedOnboarding = true
    }

    private var todayStamp: String {
        Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).uppercased()
    }
}
