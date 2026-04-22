import SwiftUI

/// Editorial palette tokens shared between the app and the widget extension.
///
/// The main app's `RFColors` pulls from the full design system (with adaptive
/// light/dark UIColor closures). Widgets can't share that file directly because
/// it brings view modifiers and typography into the widget binary, bloating it.
/// This file is the minimum palette both targets need.
enum WidgetPalette {
    /// Deep vintage red — return-window urgency.
    static let signal = Color(red: 0.784, green: 0.224, blue: 0.169)      // #C8392B

    /// Ochre — warranty / secondary-urgency.
    static let ember = Color(red: 0.710, green: 0.478, blue: 0.180)       // #B57A2E

    /// Near-black ink.
    static let ink = Color(red: 0.102, green: 0.094, blue: 0.082)         // #1A1815

    /// Warm mute for secondary text.
    static let mute = Color(red: 0.431, green: 0.400, blue: 0.353)        // #6E665A

    /// Cream paper background.
    static let paper = Color(red: 0.961, green: 0.945, blue: 0.910)       // #F5F1E8
}
