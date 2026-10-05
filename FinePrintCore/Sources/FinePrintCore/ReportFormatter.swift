// Shareable plain-text report (what the Export button sends). Lives in the core so its
// wording rules are unit-tested: the disclaimer is always present, every rule-backed line
// carries its citation and verified date, and amber items never claim anything is illegal.

public enum ReportFormatter {
    public static let disclaimer =
        "Fine Print gives information, not legal advice. Rule-backed results quote the cited law; "
        + "\"worth a look\" items are common patterns and make no legal claim. Check anything important "
        + "with a qualified professional or the relevant tribunal."

    public static func text(_ report: AnalysisReport, documentTitle: String, source: String) -> String {
        let chars = Array(source)
        var out: [String] = [
            "FINE PRINT REPORT: \(documentTitle)",
            "Document type: \(label(report.documentType)) (confidence \(Int((report.typeConfidence * 100).rounded()))%)",
            "Read by: \(report.engineName)",
            "",
            "Summary: \(report.count(.ruleViolation)) conflict(s) with the law, "
                + "\(report.count(.needsHuman)) to check yourself, "
                + "\(report.count(.worthALook)) worth a look, "
                + "\(report.count(.ruleCompliant)) consistent with the rules.",
            "",
        ]
        for tier in [Tier.ruleViolation, .needsHuman, .worthALook, .ruleCompliant] {
            let items = report.findings.filter { $0.tier == tier }
            guard !items.isEmpty else { continue }
            out.append("\(heading(tier).uppercased())")
            for f in items {
                let quote = String(chars[f.clause.range.clamped(to: 0 ..< chars.count)])
                out.append("- \(f.title)")
                out.append("  \"\(quote)\"")
                out.append("  \(f.explanation)")
                if let citation = f.citation {
                    out.append("  Source: \(citation) (checked \(f.lastVerified ?? "n/a"))")
                }
                if let note = f.exceptionNote { out.append("  Note: \(note)") }
            }
            out.append("")
        }
        if !report.failedChunks.isEmpty {
            out.append("NOT ANALYZED: \(report.failedChunks.count) section(s) couldn't be read by the engine. Read them yourself.")
            out.append("")
        }
        for line in discardSummary(report) {
            out.append("Discarded: \(line)")
        }
        if !report.dropped.isEmpty { out.append("") }
        out.append(disclaimer)
        return out.joined(separator: "\n")
    }

    /// One plain-English line per reason the pipeline discarded AI suggestions.
    public static func discardSummary(_ report: AnalysisReport) -> [String] {
        let quotes = report.dropped.filter(\.reason.isQuoteFailure).count
        let labels = report.dropped.filter { if case .labelContradicted = $0.reason { true } else { false } }.count
        let scope = report.dropped.filter { if case .outOfScope = $0.reason { true } else { false } }.count
        var lines: [String] = []
        if quotes > 0 { lines.append("\(quotes) AI suggestion(s) whose quote couldn't be found word-for-word in the document.") }
        if labels > 0 { lines.append("\(labels) AI label(s) the document's own wording contradicted (e.g. \"pets are welcome\" labelled as a pet ban).") }
        if scope > 0 { lines.append("\(scope) suggestion(s) for clause types that don't apply to this kind of document.") }
        return lines
    }

    public static func label(_ type: DocumentType) -> String {
        switch type {
        case .residentialLease: "Residential lease"
        case .employment: "Employment contract or offer"
        case .subscriptionTerms: "Subscription or terms of service"
        case .unknown: "Other / not recognized"
        }
    }

    public static func heading(_ tier: Tier) -> String {
        switch tier {
        case .ruleViolation: "Conflicts with the law"
        case .needsHuman: "Check this yourself"
        case .worthALook: "Worth a look"
        case .ruleCompliant: "Consistent with the rules"
        }
    }
}
