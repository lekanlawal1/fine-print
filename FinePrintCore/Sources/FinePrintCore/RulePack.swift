// Rule packs and heuristic packs are DATA (JSON), not code: adding a jurisdiction or a
// document type never touches the app. Every rule must carry a citation, a source URL and
// a last-verified date, and the validator refuses a pack that doesn't.

import Foundation

public struct RulePack: Codable, Sendable {
    public var id: String
    public var name: String
    public var jurisdiction: String
    public var documentTypes: [DocumentType]
    /// yyyy-MM-dd: the date the statute text was last checked by a person.
    public var lastVerified: String
    public var sourceUrl: String
    public var rules: [Rule]
}

public struct Rule: Codable, Sendable {
    public var id: String
    public var appliesTo: ClauseType
    public var check: Check
    public var title: String
    public var citation: String
    public var explanationIfViolated: String
    public var explanationIfCompliant: String?
    /// Exceptions the app can't determine from the text (shown alongside the verdict).
    public var exceptionNote: String?
    /// Overrides the pack's source_url when the rule comes from a different instrument
    /// (e.g. a regulation rather than the Act).
    public var sourceUrl: String?
}

/// The only kinds of logic a rule can express. Small on purpose: every check is
/// deterministic and testable, and none of them involves the model.
public enum Check: Codable, Sendable, Equatable {
    /// The clause existing at all conflicts with the law (e.g. a no-pets clause).
    case present
    /// The law covers this clause, but compliance depends on facts the document can't
    /// show (e.g. length of service). Always routed to a person, with the citation.
    case review
    /// parameters[param] / parameters[ofParam] must be <= limit.
    case maxRatio(param: String, ofParam: String, limit: Double)
    /// parameters[param] must be <= limit.
    case maxValue(param: String, limit: Double)
    /// parameters[param] must be >= limit.
    case minValue(param: String, limit: Double)

    private enum CodingKeys: String, CodingKey { case kind, param, ofParam, limit }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .kind) {
        case "present":
            self = .present
        case "review":
            self = .review
        case "max_ratio":
            self = .maxRatio(param: try c.decode(String.self, forKey: .param),
                             ofParam: try c.decode(String.self, forKey: .ofParam),
                             limit: try c.decode(Double.self, forKey: .limit))
        case "max_value":
            self = .maxValue(param: try c.decode(String.self, forKey: .param),
                             limit: try c.decode(Double.self, forKey: .limit))
        case "min_value":
            self = .minValue(param: try c.decode(String.self, forKey: .param),
                             limit: try c.decode(Double.self, forKey: .limit))
        case let other:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: c,
                                                   debugDescription: "unknown check kind '\(other)'")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .present:
            try c.encode("present", forKey: .kind)
        case .review:
            try c.encode("review", forKey: .kind)
        case let .maxRatio(param, ofParam, limit):
            try c.encode("max_ratio", forKey: .kind)
            try c.encode(param, forKey: .param)
            try c.encode(ofParam, forKey: .ofParam)
            try c.encode(limit, forKey: .limit)
        case let .maxValue(param, limit):
            try c.encode("max_value", forKey: .kind)
            try c.encode(param, forKey: .param)
            try c.encode(limit, forKey: .limit)
        case let .minValue(param, limit):
            try c.encode("min_value", forKey: .kind)
            try c.encode(param, forKey: .param)
            try c.encode(limit, forKey: .limit)
        }
    }
}

/// Universal "worth a look" flags. Deliberately has no citation field: these make no legal claim.
public struct HeuristicPack: Codable, Sendable {
    public var id: String
    public var name: String
    public var flags: [HeuristicFlag]
}

public struct HeuristicFlag: Codable, Sendable {
    public var appliesTo: ClauseType
    public var title: String
    public var explanation: String
}

// MARK: - Loading and validation

public enum PackLoader {
    static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    public static func rulePack(from data: Data) throws -> RulePack {
        try decoder.decode(RulePack.self, from: data)
    }

    public static func heuristicPack(from data: Data) throws -> HeuristicPack {
        try decoder.decode(HeuristicPack.self, from: data)
    }
}

public enum PackValidator {
    /// Every problem found; an empty array means the pack may ship.
    public static func validate(_ pack: RulePack) -> [String] {
        var problems: [String] = []
        if pack.id.isEmpty { problems.append("pack id is empty") }
        if pack.name.isEmpty { problems.append("pack name is empty") }
        if pack.rules.isEmpty { problems.append("pack has no rules") }
        if pack.documentTypes.isEmpty { problems.append("pack applies to no document types") }
        if pack.documentTypes.contains(.unknown) {
            // Honesty rule: a document we couldn't identify never gets a legal verdict.
            problems.append("rule packs may not apply to the 'unknown' document type")
        }
        if !isISODate(pack.lastVerified) {
            problems.append("last_verified '\(pack.lastVerified)' is not a yyyy-MM-dd date")
        }
        if !pack.sourceUrl.hasPrefix("https://") {
            problems.append("source_url must be an https:// link to the statute")
        }

        var seen = Set<String>()
        for rule in pack.rules {
            if !seen.insert(rule.id).inserted { problems.append("duplicate rule id '\(rule.id)'") }
            if rule.citation.trimmingCharacters(in: .whitespaces).isEmpty {
                problems.append("rule '\(rule.id)' has no citation")
            }
            if rule.title.isEmpty { problems.append("rule '\(rule.id)' has no title") }
            if rule.explanationIfViolated.isEmpty {
                problems.append("rule '\(rule.id)' has no explanation")
            }
            if let url = rule.sourceUrl, !url.hasPrefix("https://") {
                problems.append("rule '\(rule.id)' source_url must be https://")
            }
            switch rule.check {
            case .present, .review:
                break
            case let .maxRatio(param, ofParam, limit):
                if param.isEmpty || ofParam.isEmpty || limit <= 0 {
                    problems.append("rule '\(rule.id)' has an invalid max_ratio check")
                }
            case let .maxValue(param, _), let .minValue(param, _):
                if param.isEmpty { problems.append("rule '\(rule.id)' check has no parameter") }
            }
        }
        return problems
    }

    public static func validate(_ pack: HeuristicPack) -> [String] {
        var problems: [String] = []
        var seen = Set<ClauseType>()
        for flag in pack.flags {
            if !seen.insert(flag.appliesTo).inserted {
                problems.append("duplicate heuristic for '\(flag.appliesTo.rawValue)'")
            }
            if flag.title.isEmpty || flag.explanation.isEmpty {
                problems.append("heuristic for '\(flag.appliesTo.rawValue)' is missing text")
            }
        }
        return problems
    }

    static func isISODate(_ s: String) -> Bool {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: s) else { return false }
        return f.string(from: date) == s
    }
}
