// Turns verified clauses into findings. Pure and deterministic: given the same clauses
// and packs it always produces the same verdicts, so every rule can be unit-tested.
//
// Scoping matters: a rule pack applies only to the document types it declares. A
// lease-type clause found in a document we couldn't identify gets at most an amber flag,
// never a legal verdict.

public struct RuleEngine: Sendable {
    public var packs: [RulePack]
    public var heuristics: HeuristicPack?

    public init(packs: [RulePack], heuristics: HeuristicPack?) {
        self.packs = packs
        self.heuristics = heuristics
    }

    public func evaluate(_ clauses: [VerifiedClause], documentType: DocumentType) -> [Finding] {
        let applicable = packs.filter { $0.documentTypes.contains(documentType) }
        var findings: [Finding] = []

        for clause in clauses {
            let matches = applicable.flatMap { pack in
                pack.rules.filter { $0.appliesTo == clause.type }.map { (pack, $0) }
            }
            if !matches.isEmpty {
                findings += matches.map { apply($0.1, from: $0.0, to: clause) }
            } else if let flag = heuristics?.flags.first(where: { $0.appliesTo == clause.type }) {
                findings.append(Finding(
                    id: "heuristic.\(flag.appliesTo.rawValue)#\(clause.range.lowerBound)",
                    tier: .worthALook, title: flag.title, explanation: flag.explanation,
                    clause: clause, citation: nil, packName: heuristics?.name,
                    lastVerified: nil, sourceURL: nil, exceptionNote: nil))
            }
            // Clauses with no rule and no heuristic (e.g. type .other) produce no finding.
        }
        return findings.sorted { order($0) < order($1) }
    }

    func apply(_ rule: Rule, from pack: RulePack, to clause: VerifiedClause) -> Finding {
        let p = clause.clause.parameters
        let outcome: Outcome
        if let note = clause.labelNote {
            // LabelGuard couldn't confirm the AI's label: never a legal verdict on a doubtful label.
            outcome = .labelUncertain(note)
        } else {
            outcome = evaluate(rule.check, p)
        }
        return finding(for: outcome, rule: rule, pack: pack, clause: clause)
    }

    func evaluate(_ check: Check, _ p: [String: Double]) -> Outcome {
        let outcome: Outcome
        switch check {
        case .present:
            outcome = .violated
        case .review:
            outcome = .review
        case let .maxRatio(param, ofParam, limit):
            if let a = p[param], let b = p[ofParam], b > 0 {
                outcome = a / b <= limit ? .compliant : .violated
            } else {
                outcome = .missing([param, ofParam].filter { p[$0] == nil })
            }
        case let .maxValue(param, limit):
            outcome = p[param].map { $0 <= limit ? .compliant : .violated } ?? .missing([param])
        case let .minValue(param, limit):
            outcome = p[param].map { $0 >= limit ? .compliant : .violated } ?? .missing([param])
        }
        return outcome
    }

    func finding(for outcome: Outcome, rule: Rule, pack: RulePack, clause: VerifiedClause) -> Finding {
        let tier: Tier
        let explanation: String
        switch outcome {
        case let .labelUncertain(note):
            tier = .needsHuman
            explanation = "The AI labelled this clause \u{201C}\(rule.title.lowercased())\u{201D}, but \(note). "
                + "Because the label isn't certain, the app won't give a legal verdict on it. "
                + "If it is this kind of clause, \(rule.citation) applies. Read it yourself."
        case .violated:
            tier = .ruleViolation
            explanation = rule.explanationIfViolated
        case .compliant:
            tier = .ruleCompliant
            explanation = rule.explanationIfCompliant ?? "Consistent with \(rule.citation)."
        case let .missing(names):
            // A rule that needs numbers we couldn't read is a question for a person, not a guess.
            tier = .needsHuman
            explanation = "This clause is covered by \(rule.citation), but the app couldn't read "
                + "the value(s) it needs to check it (\(names.joined(separator: ", "))). Read it yourself."
        case .review:
            // The law applies, but compliance depends on facts outside the document.
            tier = .needsHuman
            explanation = rule.explanationIfViolated
        }

        return Finding(
            id: "\(pack.id).\(rule.id)#\(clause.range.lowerBound)",
            tier: tier, title: rule.title, explanation: explanation, clause: clause,
            citation: rule.citation, packName: pack.name, lastVerified: pack.lastVerified,
            sourceURL: rule.sourceUrl ?? pack.sourceUrl, exceptionNote: rule.exceptionNote)
    }

    enum Outcome {
        case violated, compliant, review
        case missing([String])
        case labelUncertain(String)
    }

    /// Most serious first, then document order.
    func order(_ f: Finding) -> (Int, Int) {
        let rank: [Tier: Int] = [.ruleViolation: 0, .needsHuman: 1, .worthALook: 2, .ruleCompliant: 3]
        return (rank[f.tier] ?? 9, f.clause.range.lowerBound)
    }
}
