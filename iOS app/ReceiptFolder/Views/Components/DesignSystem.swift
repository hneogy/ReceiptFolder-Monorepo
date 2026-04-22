import SwiftUI

// MARK: - Hex Color Initializer

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

// MARK: - Editorial Palette
//
// The app's visual identity is "Editorial Receipt" — cream paper, ink type,
// one signal red, one ochre accent. No gradients, no tinted bubbles,
// no rainbow avatars. The palette is deliberately narrow.

enum RFColors {
    // Paper stock (backgrounds). Warm cream in light, deep espresso in dark.
    static let paper = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.082, green: 0.071, blue: 0.063, alpha: 1.0)  // #151210
            : UIColor(red: 0.961, green: 0.945, blue: 0.910, alpha: 1.0)  // #F5F1E8
    })

    // Secondary surface — a shade off paper, for cards / grouped sections
    static let paperDim = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.118, green: 0.106, blue: 0.094, alpha: 1.0)  // #1E1B18
            : UIColor(red: 0.929, green: 0.906, blue: 0.847, alpha: 1.0)  // #EDE7D8
    })

    // Ink (primary text, icon strokes)
    static let ink = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.937, green: 0.910, blue: 0.851, alpha: 1.0)  // #EFE8D9 warm cream
            : UIColor(red: 0.102, green: 0.094, blue: 0.082, alpha: 1.0)  // #1A1815 near-black
    })

    // Muted text (secondary, meta, dates). Darkened from #8B8579 to #6E665A to
    // clear WCAG AA 4.5:1 contrast on cream paper.
    static let mute = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.675, green: 0.647, blue: 0.596, alpha: 1.0)  // #ACA598
            : UIColor(red: 0.431, green: 0.400, blue: 0.353, alpha: 1.0)  // #6E665A
    })

    // Hairlines, perforations
    static let rule = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.937, green: 0.910, blue: 0.851, alpha: 0.18)
            : UIColor(red: 0.102, green: 0.094, blue: 0.082, alpha: 0.16)
    })

    // Signal colors — deliberately ONLY two. Red for urgency, ochre for warranty.
    // Picked to read as editorial/vintage, not neon.
    static let signal = Color(hex: 0xC8392B)     // deep vintage red
    static let signalSoft = Color(hex: 0xE8C9C4) // red wash for urgent backgrounds

    static let ember = Color(hex: 0xB57A2E)      // ochre, for warranty
    static let emberSoft = Color(hex: 0xE8D8BD)  // ochre wash

    // Legacy token compatibility — map old names to new tokens so we don't have
    // to grep-replace across every file in a single pass.
    static let background = paper
    static let cardBackground = paperDim
    static let surfaceTint = paperDim
    static let textPrimary = ink
    static let textSecondary = mute
    static let border = rule
    static let critical = signal
    static let criticalLight = signalSoft
    static let warning = ember
    static let warningLight = emberSoft
    static let safe = ink            // no green — "safe" is just ink (no alarm)
    static let safeLight = paperDim
    static let teal = ink            // brand accent is ink, not teal, in the new language
    static let tealDark = ink
    static let emerald = ink
    static let mint = ink
    static let mintLight = paperDim
    static let indigo = ember        // warranty → ember
    static let violet = ember
    static let tabBar = paperDim
}

// MARK: - Typography
//
// Three type families, on purpose:
//   display  — serif (New York), for product names, countdowns, titles
//   ui       — sans (SF), for labels, buttons, body copy
//   mono     — monospaced (SF Mono), for dates, prices, receipt numbers
//
// The editorial design uses tuned point sizes. Full Dynamic Type scaling is
// opt-in via `RFFont.scalable*` variants; those should be used for long-form
// body text (notes, policies). The fixed-size variants are used for display
// elements where the visual tuning matters. At the app root, a
// `.dynamicTypeSize(.xSmall ... .accessibility1)` modifier caps extreme sizes
// so the masthead and countdowns don't break at AX5.

enum RFFont {
    // Display serif — fixed size, designed to be paired with minimumScaleFactor
    // at the call site for hero elements.
    static func hero(_ size: CGFloat = 64) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }
    static func title(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }
    static func heading(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }
    static func serifBody(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    // UI sans
    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    static func bodyMedium(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
    static func label(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    // Monospace — for tabular data
    static func mono(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }
    static func monoMedium(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
    static func monoBold(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }

    // MARK: - Scalable variants (respect Dynamic Type fully).
    // Use these for long-form content that users may need to enlarge.
    static var scalableBodySerif: Font { .system(.body, design: .serif) }
    static var scalableBody: Font { .system(.body) }
    static var scalableFootnote: Font { .system(.footnote) }
}

// MARK: - Eyebrow label (tracked uppercase small caps)

struct RFEyebrow: View {
    let text: String
    var color: Color = RFColors.mute

    var body: some View {
        Text(text.uppercased())
            .font(RFFont.label(11))
            .tracking(1.6)
            .foregroundStyle(color)
    }
}

// MARK: - Perforation Divider
//
// The app's signature. A row of small dots — a tear-off receipt stub line.
// Used between logical sections instead of card shadows.

struct RFPerforation: View {
    var color: Color = RFColors.rule
    var dotSize: CGFloat = 2.5
    var spacing: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let count = max(0, Int((geo.size.width + spacing) / (dotSize + spacing)))
            HStack(spacing: spacing) {
                ForEach(0..<count, id: \.self) { _ in
                    Circle()
                        .fill(color)
                        .frame(width: dotSize, height: dotSize)
                }
            }
        }
        .frame(height: dotSize)
        .accessibilityHidden(true)
    }
}

// MARK: - Hairline

struct RFHairline: View {
    var color: Color = RFColors.rule

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 0.5)
            .accessibilityHidden(true)
    }
}

// MARK: - Button Styles

struct RFPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RFFont.bodyMedium(15))
            .tracking(0.4)
            .foregroundStyle(RFColors.paper)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RFColors.ink)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            .offset(y: configuration.isPressed ? 1 : 0)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct RFSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RFFont.bodyMedium(15))
            .tracking(0.4)
            .foregroundStyle(RFColors.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(RFColors.ink, lineWidth: 1)
            )
            .offset(y: configuration.isPressed ? 1 : 0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct RFDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RFFont.bodyMedium(15))
            .tracking(0.4)
            .foregroundStyle(RFColors.paper)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RFColors.signal)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            .offset(y: configuration.isPressed ? 1 : 0)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Store Mark
//
// Replaces rainbow "StoreAvatar" with an editorial monogram:
// two letters in serif, hairline border, ink color. One hue, no hash rainbow.

struct StoreAvatar: View {
    let name: String
    var size: CGFloat = 44

    private var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.36, weight: .regular, design: .serif))
            .foregroundStyle(RFColors.ink)
            .frame(width: size, height: size)
            .background(RFColors.paper)
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(RFColors.ink, lineWidth: 0.75)
            )
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
    }
}

// MARK: - Section Header

struct RFSectionHeader: View {
    let title: String
    var action: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(RFFont.label(11))
                .tracking(1.6)
                .foregroundStyle(RFColors.mute)
            Spacer()
            if let action, let onAction {
                Button(action: onAction) {
                    Text(action)
                        .font(RFFont.label(11))
                        .tracking(1.0)
                        .foregroundStyle(RFColors.ink)
                        .underline()
                }
            }
        }
    }
}

// MARK: - Action Button (icon + label stack)

struct RFActionButton: View {
    let icon: String
    let label: String
    var color: Color = RFColors.ink
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(color)
                    .frame(width: 52, height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .stroke(color, lineWidth: 0.75)
                    )

                Text(label)
                    .font(RFFont.label(10))
                    .tracking(1.2)
                    .foregroundStyle(RFColors.ink)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Urgency Pill
//
// Rectangular (not capsule) with hairline border and mono days count.
// Red fill only when truly urgent (critical). Otherwise outline.

struct RFUrgencyPill: View {
    let urgency: UrgencyLevel
    let daysRemaining: Int?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 5, height: 5)
            Text(pillText.uppercased())
                .font(RFFont.monoBold(10))
                .tracking(0.8)
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(fillColor)
        .overlay(
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .stroke(borderColor, lineWidth: 0.75)
        )
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        .accessibilityLabel(fullAccessibilityLabel)
    }

    private var dotColor: Color {
        switch urgency {
        case .critical: RFColors.signal
        case .warning: RFColors.signal
        case .warrantyExpiring: RFColors.ember
        case .active: RFColors.ink
        }
    }

    private var fillColor: Color {
        urgency == .critical ? RFColors.signal : .clear
    }

    private var borderColor: Color {
        switch urgency {
        case .critical: RFColors.signal
        case .warning: RFColors.signal
        case .warrantyExpiring: RFColors.ember
        case .active: RFColors.ink.opacity(0.4)
        }
    }

    private var textColor: Color {
        urgency == .critical ? RFColors.paper : RFColors.ink
    }

    private var pillText: String {
        guard let days = daysRemaining else { return urgency.label }
        if days == 0 { return "Last day" }
        return "\(days)d"
    }

    private var fullAccessibilityLabel: String {
        switch urgency {
        case .critical:
            guard let days = daysRemaining else { return "Critical" }
            return days == 0 ? "Critical, last day to return" : "Critical, \(days) days remaining"
        case .warning:
            guard let days = daysRemaining else { return "Warning" }
            return "Warning, \(days) days remaining"
        case .warrantyExpiring:
            guard let days = daysRemaining else { return "Warranty expiring" }
            return "Warranty expiring, \(days) days remaining"
        case .active:
            return "Active, plenty of time"
        }
    }
}

// MARK: - Progress Bar
//
// Thin 2pt rule, no gradient, ink-colored.

struct RFProgressBar: View {
    let progress: Double
    let color: Color
    var height: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(RFColors.rule)

                Rectangle()
                    .fill(color)
                    .frame(width: max(0, geo.size.width * min(1, progress)))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Tab Bar
//
// Fixed bottom bar. No floating pill, no protruding FAB.
// Serif labels, a signal-red underline for the selected tab, a central scan
// button rendered as a small square with a viewfinder glyph.

enum RFTab: Int, CaseIterable, Hashable {
    case vault, expiring, insights, settings

    var icon: String {
        switch self {
        case .vault: "tray.full"
        case .expiring: "clock"
        case .insights: "chart.bar"
        case .settings: "gearshape"
        }
    }

    var label: String {
        switch self {
        case .vault: "Vault"
        case .expiring: "Expiring"
        case .insights: "Insights"
        case .settings: "Settings"
        }
    }
}

struct RFTabBar: View {
    @Binding var selectedTab: RFTab
    let onScanTapped: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            RFHairline()

            HStack(spacing: 0) {
                tabButton(.vault)
                tabButton(.expiring)
                scanButton
                tabButton(.insights)
                tabButton(.settings)
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .background(RFColors.paper)
        }
    }

    private func tabButton(_ tab: RFTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(selectedTab == tab ? RFColors.ink : RFColors.mute)

                Text(tab.label)
                    .font(.system(size: 10, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(selectedTab == tab ? RFColors.ink : RFColors.mute)

                Rectangle()
                    .fill(selectedTab == tab ? RFColors.signal : .clear)
                    .frame(width: 14, height: 1.5)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label)
        .accessibilityIdentifier("tab.\(tab.label.lowercased())")
    }

    private var scanButton: some View {
        Button(action: onScanTapped) {
            VStack(spacing: 4) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(RFColors.paper)
                    .frame(width: 38, height: 38)
                    .background(RFColors.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))

                Text("Scan")
                    .font(.system(size: 10, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.ink)

                Rectangle().fill(.clear).frame(width: 14, height: 1.5)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Scan receipt")
        .accessibilityIdentifier("tab.scan")
    }
}

// MARK: - Onboarding Illustration

struct OnboardingIllustration: View {
    let icon: String
    let accentIcons: [(String, CGFloat, CGFloat, Color)]

    var body: some View {
        ZStack {
            Rectangle()
                .stroke(RFColors.ink, lineWidth: 1)
                .frame(width: 180, height: 180)

            Image(systemName: icon)
                .font(.system(size: 64, weight: .regular))
                .foregroundStyle(RFColors.ink)

            ForEach(Array(accentIcons.enumerated()), id: \.offset) { _, item in
                Image(systemName: item.0)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(RFColors.ink)
                    .padding(8)
                    .background(RFColors.paperDim)
                    .overlay(
                        Rectangle().stroke(RFColors.ink, lineWidth: 0.75)
                    )
                    .offset(x: item.1, y: item.2)
            }
        }
    }
}

// MARK: - Masthead
//
// The app's signature header: a newspaper-style masthead that renders the
// app name in serif, a date in mono, and a thick-then-thin rule beneath.

struct RFMasthead: View {
    let title: String
    var subtitle: String? = nil
    var meta: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            if let meta {
                HStack {
                    Text(meta.uppercased())
                        .font(RFFont.mono(10))
                        .tracking(1.2)
                        .foregroundStyle(RFColors.mute)
                    Spacer()
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()).uppercased())
                        .font(RFFont.mono(10))
                        .tracking(1.2)
                        .foregroundStyle(RFColors.mute)
                }
            }

            Rectangle()
                .fill(RFColors.ink)
                .frame(height: 2)

            Text(title)
                .font(RFFont.hero(56))
                .foregroundStyle(RFColors.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            RFHairline()
                .padding(.top, 4)
        }
    }
}
