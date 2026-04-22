import SwiftUI

/// Onboarding — rendered as three "issues" of a small publication. Each page
/// has a serif masthead, a printed illustration, a pull-quote subtitle, and
/// a page-number indicator instead of dots.
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            eyebrow: "Issue No. I",
            title: "Never Miss",
            titleAccent: "a Return",
            subtitle: "Every purchase has a window. Receipt Folder keeps watch so you never forfeit a refund.",
            icon: "clock",
            accentIcons: [
                ("checkmark", -70, -60),
                ("calendar", 80, -40),
                ("dollarsign", -60, 65)
            ]
        ),
        OnboardingPage(
            eyebrow: "Issue No. II",
            title: "Scan &",
            titleAccent: "Catalogue",
            subtitle: "Point your camera at any receipt. Store, date, and total are read on-device in seconds.",
            icon: "doc.text.viewfinder",
            accentIcons: [
                ("text.viewfinder", -75, -50),
                ("sparkle", 75, -50),
                ("wand.and.stars", 65, 60)
            ]
        ),
        OnboardingPage(
            eyebrow: "Issue No. III",
            title: "Stay",
            titleAccent: "Ahead",
            subtitle: "Timely reminders — from two weeks out to the morning of your deadline. Never scramble again.",
            icon: "bell",
            accentIcons: [
                ("exclamationmark", -75, -50),
                ("clock", 75, -45),
                ("shield.checkered", -65, 60)
            ]
        )
    ]

    var body: some View {
        ZStack {
            RFColors.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 24)

                Spacer()

                illustrationFrame
                    .id(currentPage)
                    .transition(.opacity)
                    .padding(.bottom, 40)

                Spacer()

                pageContent
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)

                RFPerforation()
                    .padding(.horizontal, 40)
                    .padding(.bottom, 24)

                bottomControls
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("RECEIPT · FOLDER")
                    .font(RFFont.mono(10))
                    .tracking(1.8)
                    .foregroundStyle(RFColors.mute)
                Spacer()
                Text("PAGE \(romanNumeral(currentPage + 1)) / \(romanNumeral(pages.count))")
                    .font(RFFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.mute)

                if currentPage < pages.count - 1 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { completeOnboarding() }
                    } label: {
                        Text("SKIP")
                            .font(RFFont.mono(10))
                            .tracking(1.4)
                            .foregroundStyle(RFColors.ink)
                            .underline()
                            .padding(.leading, 14)
                    }
                }
            }

            Rectangle().fill(RFColors.ink).frame(height: 2)
        }
    }

    // MARK: - Illustration

    private var illustrationFrame: some View {
        let page = pages[currentPage]
        return ZStack {
            Rectangle()
                .stroke(RFColors.ink, lineWidth: 0.75)
                .frame(width: 240, height: 240)

            Rectangle()
                .stroke(RFColors.ink, lineWidth: 1.5)
                .frame(width: 200, height: 200)

            Image(systemName: page.icon)
                .font(.system(size: 80, weight: .regular))
                .foregroundStyle(RFColors.ink)

            ForEach(Array(page.accentIcons.enumerated()), id: \.offset) { _, item in
                Image(systemName: item.0)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(RFColors.ink)
                    .padding(10)
                    .background(RFColors.paper)
                    .overlay(Rectangle().stroke(RFColors.ink, lineWidth: 0.75))
                    .offset(x: item.1, y: item.2)
            }
        }
        .frame(height: 280)
    }

    // MARK: - Page content

    private var pageContent: some View {
        let page = pages[currentPage]
        return VStack(spacing: 14) {
            Text(page.eyebrow.uppercased())
                .font(RFFont.mono(11))
                .tracking(1.8)
                .foregroundStyle(RFColors.mute)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(page.title)
                    .font(RFFont.hero(52))
                    .foregroundStyle(RFColors.ink)
                Text(page.titleAccent)
                    .font(.system(size: 52, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.signal)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .id("title-\(currentPage)")

            Text(page.subtitle)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(RFColors.mute)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 8)
                .id("subtitle-\(currentPage)")
        }
    }

    // MARK: - Bottom controls

    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Page indicator — printed tick marks
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Rectangle()
                        .fill(index == currentPage ? RFColors.signal : RFColors.rule)
                        .frame(width: index == currentPage ? 28 : 14, height: 1.5)
                        .animation(.easeInOut(duration: 0.25), value: currentPage)
                }
            }

            if currentPage < pages.count - 1 {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { currentPage += 1 }
                } label: {
                    Text("Turn the page")
                }
                .buttonStyle(RFPrimaryButtonStyle())
            } else {
                Button {
                    withAnimation { completeOnboarding() }
                } label: {
                    Text("Begin")
                }
                .buttonStyle(RFPrimaryButtonStyle())
            }
        }
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    private func romanNumeral(_ n: Int) -> String {
        switch n {
        case 1: return "I"
        case 2: return "II"
        case 3: return "III"
        case 4: return "IV"
        case 5: return "V"
        default: return "\(n)"
        }
    }
}

// MARK: - Page Model

private struct OnboardingPage {
    let eyebrow: String
    let title: String
    let titleAccent: String
    let subtitle: String
    let icon: String
    let accentIcons: [(String, CGFloat, CGFloat)]
}
