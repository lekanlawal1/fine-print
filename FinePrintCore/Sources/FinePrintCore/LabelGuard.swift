// LabelGuard: checks that a clause's WORDING supports the label the AI gave it, before any
// rule can issue a legal verdict.
//
// Why it exists (Phase 5 evaluation): quote verification proves a clause is real, but not
// that it's labelled correctly. Both engines labelled "Pets are welcome. The Tenant may keep
// cats and dogs" as a pets clause, and the s.14 rule then called it void. The on-device model
// also labelled a legal rent deposit as a security deposit. The label is the model's opinion;
// this is deterministic code checking it against the text.
//
// Outcomes, in order:
//   1. contradicted: explicit opposite wording ("pets are welcome", "no damage deposit",
//      "optional"): the label is rejected and the clause gets no verdict at all.
//   2. unsupported: no on-topic words, wording that points to a different clause type, or
//      no sign the clause actually imposes anything: routed to "check this yourself".
//   3. consistent: rules may judge it.
// Patterns are matched against the NORMALIZED source text (lowercase, straight quotes,
// hyphens removed), so "post-dated" is written "postdated" here.

import Foundation

public enum LabelCheck: Sendable, Equatable {
    case consistent
    case unsupported(String)
    case contradicted(String)
}

struct LabelRule: Sendable {
    /// At least one must appear, or the clause isn't about this topic.
    var topic: [String] = []
    /// Wording that means the opposite. Ignored when directly preceded by "no"/"not".
    var opposite: [String] = []
    /// Wording that suggests a different clause type.
    var otherConcept: [String] = []
    /// Signs the clause actually imposes/restricts something (if listed, one must appear).
    var imposes: [String] = []
}

public enum LabelGuard {
    static let rules: [ClauseType: LabelRule] = [
        .pets: LabelRule(
            topic: ["pet", "animal", "dog", "cat", "bird", "fish"],
            opposite: ["pets are welcome", "animals are welcome", "may keep", "pets are permitted",
                       "pets are allowed", "permitted to keep", "allowed to keep"],
            imposes: ["no ", "not ", "prohibit", "forbid", "without"]),
        .securityDeposit: LabelRule(
            topic: ["deposit"],
            opposite: ["no damage deposit", "no security deposit", "no deposit", "not be required",
                       "not required", "waived"],
            otherConcept: ["rent deposit", "last month", "applied to the rent", "applied to rent",
                           "key", "fob", "access card", "remote"],
            imposes: ["pay", "payable", "provide", "required", "collect"]),
        .rentDeposit: LabelRule(topic: ["deposit", "last month"], opposite: ["no rent deposit", "no deposit"]),
        .keyDeposit: LabelRule(topic: ["key", "fob", "card", "remote"], opposite: ["no key deposit", "no deposit"],
                               imposes: ["deposit"]),
        .nsfFee: LabelRule(
            topic: ["nsf", "returned", "bounced", "dishonour", "dishonor", "insufficient"],
            opposite: ["will not charge", "not charge any", "no fee", "no charge", "free of charge"],
            imposes: ["fee", "charge", "cost", "penalty"]),
        .accelerationClause: LabelRule(
            topic: ["remainder", "remaining", "balance", "become due", "becomes due", "immediately due", "accelerat"]),
        .postDatedCheques: LabelRule(
            topic: ["postdated", "preauthorized", "preauthorised", "automatic", "debit", "autopay",
                    "credit card", "cheque"],
            opposite: ["optional", "may pay", "choice", "prefer", "option", "if the tenant wishes"],
            imposes: ["must", "shall", "required", "condition"]),
        .landlordEntry: LabelRule(topic: ["enter", "entry", "access"]),
        .rentIncrease: LabelRule(topic: ["increase", "raise"]),
        .nonCompete: LabelRule(topic: ["compet", "rival"]),
        .vacation: LabelRule(topic: ["vacation", "holiday", "paid time off", "pto", "days off"]),
        .overtime: LabelRule(topic: ["overtime", "over 44", "hours worked over", "in excess", "beyond",
                                     "time and a half", "one and onehalf"]),
    ]

    /// - Parameter text: the clause's text as it appears in the source document.
    public static func check(_ type: ClauseType, text: String) -> LabelCheck {
        guard let rule = rules[type] else { return .consistent }  // no rule-backed verdicts for this type
        let t = TextNormalizer.normalize(text).string
        let name = type.rawValue.replacingOccurrences(of: "_", with: " ")

        if !rule.topic.isEmpty, !rule.topic.contains(where: t.contains) {
            return .unsupported("its wording doesn't mention anything about \(name)")
        }
        if let phrase = rule.opposite.first(where: { containsUnnegated(t, $0) }) {
            return .contradicted("the wording says \"\(phrase)\", which is the opposite of a \(name) restriction")
        }
        if let phrase = rule.otherConcept.first(where: t.contains) {
            return .unsupported("its wording (\"\(phrase)\") suggests a different kind of clause")
        }
        if !rule.imposes.isEmpty, !rule.imposes.contains(where: t.contains) {
            return .unsupported("its wording doesn't clearly impose a \(name) term")
        }
        return .consistent
    }

    /// True if `phrase` occurs without "no "/"not " immediately before it
    /// ("no pets are allowed" must not count as "pets are allowed").
    static func containsUnnegated(_ text: String, _ phrase: String) -> Bool {
        var searchStart = text.startIndex
        while let r = text.range(of: phrase, range: searchStart ..< text.endIndex) {
            let before = text[text.index(r.lowerBound, offsetBy: -min(5, text.distance(from: text.startIndex, to: r.lowerBound))) ..< r.lowerBound]
            if !before.hasSuffix("no ") && !before.hasSuffix("not ") { return true }
            searchStart = r.upperBound
        }
        return false
    }
}
