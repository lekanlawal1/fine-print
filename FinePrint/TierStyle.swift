// Every verdict tier has an icon, a text label AND a colour, so meaning never depends on
// colour alone (colour-blind users, VoiceOver, greyscale screenshots).

import FinePrintAI
import FinePrintCore
import SwiftUI

extension Tier {
    var label: String { ReportFormatter.heading(self) }

    var symbol: String {
        switch self {
        case .ruleViolation: "xmark.octagon.fill"
        case .needsHuman: "questionmark.circle.fill"
        case .worthALook: "eye.circle.fill"
        case .ruleCompliant: "checkmark.seal.fill"
        }
    }

    var color: Color {
        switch self {
        case .ruleViolation: Theme.violation
        case .needsHuman: Theme.needsHuman
        case .worthALook: Theme.worthALook
        case .ruleCompliant: Theme.compliant
        }
    }

    /// One-line meaning shown under section headers.
    var meaning: String {
        switch self {
        case .ruleViolation: "These clauses conflict with a specific section of Ontario law."
        case .needsHuman: "The law covers these, but the app can't decide from the text alone."
        case .worthALook: "Common patterns to read carefully. No legal claim is made."
        case .ruleCompliant: "Checked against a rule and consistent with it."
        }
    }

    static let displayOrder: [Tier] = [.ruleViolation, .needsHuman, .worthALook, .ruleCompliant]
}

struct TierBadge: View {
    let tier: Tier
    var body: some View {
        Label(tier.label, systemImage: tier.symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tier.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tier.color.opacity(0.12), in: Capsule())
    }
}

struct TierCount: View {
    let tier: Tier
    let count: Int
    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: tier.symbol).font(.title3).foregroundStyle(tier.color)
            Text("\(count)").font(.title2.weight(.bold)).fontDesign(.serif).monospacedDigit()
                .foregroundStyle(Theme.ink)
            Text(tier.label).font(.caption2).foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center).lineLimit(3).minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) \(tier.label)")
    }
}

extension EngineKind {
    var displayName: String {
        switch self {
        case .gemini: "Gemini"
        case .onDevice: "On-device AI"
        case .keyword: "Keyword engine (no AI)"
        }
    }

    var symbol: String {
        switch self {
        case .gemini: "cloud.fill"
        case .onDevice: "iphone"
        case .keyword: "text.magnifyingglass"
        }
    }
}

extension String {
    /// Character-offset slicing, matching the offsets the core pipeline produces.
    func slice(_ range: Range<Int>) -> String {
        let chars = Array(self)
        return String(chars[range.clamped(to: 0 ..< chars.count)])
    }
}
