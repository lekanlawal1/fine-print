// One finding: the clause highlighted in its surrounding text, what it means, and (for
// rule-backed findings) the exact law it was checked against and when.

import FinePrintCore
import SwiftUI

struct ClauseDetailView: View {
    let finding: Finding
    let document: LoadedDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    TierBadge(tier: finding.tier)
                    Text(finding.title).font(.title2.weight(.bold)).fontDesign(.serif).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                block("In your document") {
                    Text(highlighted)
                        .font(.callout)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.field, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    if finding.clause.matchScore < 1 {
                        Label("Matched to text read from an image (\(Int((finding.clause.matchScore * 100).rounded()))% similar), "
                              + "allowing for OCR errors.", systemImage: "doc.viewfinder")
                            .font(.caption).foregroundStyle(Theme.inkSecondary)
                    }
                }

                block("What this means") {
                    Text(finding.explanation)
                }

                if let note = finding.exceptionNote {
                    block("Exceptions") {
                        Text(note).foregroundStyle(Theme.inkSecondary)
                    }
                }

                if let citation = finding.citation {
                    block("Source") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(citation).font(.callout.weight(.medium))
                            if let checked = finding.lastVerified {
                                Text("Checked against the official text on \(checked).")
                                    .font(.caption).foregroundStyle(Theme.inkSecondary)
                            }
                            if let url = finding.sourceURL.flatMap(URL.init(string:)) {
                                Link(destination: url) {
                                    Label("Read the law on ontario.ca", systemImage: "arrow.up.right.square")
                                }
                                .font(.callout)
                            }
                        }
                    }
                } else {
                    Label("This is a common pattern worth reading carefully. The app makes no legal claim about it.",
                          systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(Theme.inkSecondary)
                }

                Text(ReportFormatter.disclaimer).font(.caption2).foregroundStyle(Theme.inkSecondary.opacity(0.6))
            }
            .padding()
        }
        .foregroundStyle(Theme.ink)
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The clause in bold with a tinted background, with up to 220 characters of context
    /// on each side so the reader sees exactly where it sits.
    private var highlighted: AttributedString {
        let chars = Array(document.text)
        let range = finding.clause.range.clamped(to: 0 ..< chars.count)
        let lo = max(0, range.lowerBound - 220)
        let hi = min(chars.count, range.upperBound + 220)
        var before = AttributedString((lo > 0 ? "…" : "") + String(chars[lo ..< range.lowerBound]))
        var clause = AttributedString(String(chars[range]))
        var after = AttributedString(String(chars[range.upperBound ..< hi]) + (hi < chars.count ? "…" : ""))
        before.foregroundColor = .secondary
        after.foregroundColor = .secondary
        clause.font = .callout.bold()
        clause.backgroundColor = finding.tier.color.opacity(0.18)
        return before + clause + after
    }

    @ViewBuilder
    private func block(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSecondary)
            content()
        }
    }
}
