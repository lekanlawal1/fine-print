// Warm "paper" theme: cream backgrounds, warm off-white cards, terracotta accent, warm brown
// ink, serif headings. Every colour has a matching warm dark-mode value.

import SwiftUI
import UIKit

enum Theme {
    static let background = Color(light: 0xF6EFE4, dark: 0x1C1814)
    static let card = Color(light: 0xFFFAF2, dark: 0x282320)
    static let field = Color(light: 0xF1E7D8, dark: 0x221D19)
    static let border = Color(light: 0xE6D8C4, dark: 0x3A322B)
    static let ink = Color(light: 0x2B211A, dark: 0xF3E9DD)
    static let inkSecondary = Color(light: 0x6E5D4E, dark: 0xBFAE9C)
    static let accent = Color(light: 0xB4532A, dark: 0xE08A5C)

    // Verdict colours: warm-shifted but kept far apart, and always paired with an icon + label.
    static let violation = Color(light: 0xB3261E, dark: 0xF2766B)
    static let needsHuman = Color(light: 0x6A4C93, dark: 0xB39DDB)
    static let worthALook = Color(light: 0xB86E00, dark: 0xF0B04A)
    static let compliant = Color(light: 0x4E7A3A, dark: 0x8CC07A)

    static let corner: CGFloat = 20
    static let gutter: CGFloat = 16
}

extension Color {
    /// A colour that follows light/dark mode, from 0xRRGGBB values.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}

/// A rounded warm card with a hairline border.
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }
}

/// Small caps-style section label used above cards.
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(Theme.inkSecondary)
            .padding(.leading, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Warm background + card rows for List/Form screens (results, settings).
struct WarmListStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Theme.background)
    }
}

extension View {
    func warmList() -> some View { modifier(WarmListStyle()) }
}
