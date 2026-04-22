import SwiftUI

/// macOS-specific palette + type tokens. Mirrors the iOS `RFColors` /
/// `RFFont` by hex values so the two platforms look identical, but uses
/// `@Environment(\.colorScheme)` for light/dark instead of the iOS
/// `UIColor(dynamicProvider:)` API.
enum MacColors {
    static func paper(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.082, green: 0.071, blue: 0.063)
            : Color(red: 0.961, green: 0.945, blue: 0.910)
    }
    static func paperDim(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.118, green: 0.106, blue: 0.094)
            : Color(red: 0.929, green: 0.906, blue: 0.847)
    }
    static func ink(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.937, green: 0.910, blue: 0.851)
            : Color(red: 0.102, green: 0.094, blue: 0.082)
    }
    static func mute(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.675, green: 0.647, blue: 0.596)
            : Color(red: 0.431, green: 0.400, blue: 0.353)
    }
    static let signal = Color(red: 0.784, green: 0.224, blue: 0.169)  // #C8392B
    static let ember  = Color(red: 0.710, green: 0.478, blue: 0.180)  // #B57A2E
    static func rule(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.937, green: 0.910, blue: 0.851, opacity: 0.18)
            : Color(red: 0.102, green: 0.094, blue: 0.082, opacity: 0.16)
    }
}

enum MacFont {
    static func hero(_ size: CGFloat = 48) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }
    static func title(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }
    static func serifBody(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }
    static func mono(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }
}

/// Simple perforation line — matches iOS RFPerforation.
struct MacPerforation: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        GeometryReader { geo in
            let dot: CGFloat = 3
            let gap: CGFloat = 6
            let count = max(0, Int((geo.size.width + gap) / (dot + gap)))
            HStack(spacing: gap) {
                ForEach(0..<count, id: \.self) { _ in
                    Circle()
                        .fill(MacColors.rule(scheme))
                        .frame(width: dot, height: dot)
                }
            }
        }
        .frame(height: 3)
    }
}
