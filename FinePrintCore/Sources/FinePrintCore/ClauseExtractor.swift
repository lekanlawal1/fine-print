// The seam between the pipeline and whatever reads the document.
//
// Three implementations are planned: on-device Foundation Models and Gemini (both in the
// app target, since they need frameworks and network), and this MockExtractor, which is
// deterministic and lives in the core so the whole pipeline can be tested with no AI.

import Foundation

public protocol ClauseExtractor: Sendable {
    /// Shown in the report so users always know which engine produced it.
    var name: String { get }
    /// How much document text fits in one request for this engine.
    var chunkBudget: ChunkBudget { get }
    func detectDocumentType(_ text: String) async throws -> TypeGuess
    func extractClauses(from chunk: String, documentType: DocumentType) async throws -> [ExtractedClause]
}

/// Keyword-based stand-in for the AI. Honest about what it is: it finds sentences containing
/// known phrases and returns them verbatim. Used for tests, and as the last-resort engine.
public struct MockExtractor: ClauseExtractor {
    public let name = "Keyword engine (no AI)"
    public let chunkBudget = ChunkBudget(contextSize: 8192)
    /// Clauses to inject as if the model had made them up, for testing the quote verifier.
    public var fabricated: [ExtractedClause]

    public init(fabricated: [ExtractedClause] = []) {
        self.fabricated = fabricated
    }

    // Order matters: more specific phrases first ("compete" contains "pet").
    static let keywords: [(ClauseType, [String])] = [
        (.nonCompete, ["non-compete", "compete with", "competing business"]),
        (.nsfFee, ["nsf", "returned cheque", "bounced cheque", "dishonoured cheque"]),
        (.accelerationClause, ["remaining rent", "becomes due immediately", "become due immediately"]),
        (.securityDeposit, ["damage deposit", "security deposit", "pet deposit"]),
        (.rentDeposit, ["last month's rent", "rent deposit"]),
        (.keyDeposit, ["key deposit"]),
        (.pets, ["pet", "animal"]),
        (.guests, ["guest"]),
        (.rentIncrease, ["increase the rent", "rent increase"]),
        (.landlordEntry, ["enter the unit", "enter the premises"]),
        (.postDatedCheques, ["post-dated", "postdated"]),
        (.vacation, ["vacation"]),
        (.overtime, ["overtime"]),
        (.cancellationFee, ["cancellation fee", "early termination fee"]),
        (.termination, ["terminat"]),
        (.autoRenewal, ["automatically renew", "auto-renew"]),
        (.unilateralAmendment, ["modify these terms", "change these terms", "without notice"]),
        (.liabilityWaiver, ["not be liable", "waive"]),
        (.arbitration, ["arbitration"]),
        (.indemnity, ["indemnif"]),
        (.contentLicense, ["license to use", "perpetual"]),
        (.dataSharing, ["third part", "share your"]),
        (.priceIncrease, ["change the price", "price increase"]),
        (.venue, ["courts of", "governed by the laws"]),
        (.nonDisparagement, ["disparag"]),
        (.assignment, ["assign"]),
    ]

    static let typeSignals: [(DocumentType, [String])] = [
        (.residentialLease, ["tenant", "landlord", "rent", "lease", "unit"]),
        (.employment, ["employee", "employer", "salary", "employment", "position"]),
        (.subscriptionTerms, ["subscription", "terms of service", "account", "service", "user"]),
    ]

    public func detectDocumentType(_ text: String) async throws -> TypeGuess {
        let lower = text.lowercased()
        let scores = Self.typeSignals.map { type, words in
            (type, words.reduce(0) { $0 + lower.components(separatedBy: $1).count - 1 })
        }
        let total = scores.reduce(0) { $0 + $1.1 }
        guard total > 0, let best = scores.max(by: { $0.1 < $1.1 }) else {
            return TypeGuess(type: .unknown, confidence: 0)
        }
        return TypeGuess(type: best.0, confidence: Double(best.1) / Double(total))
    }

    public func extractClauses(from chunk: String, documentType: DocumentType) async throws -> [ExtractedClause] {
        let sentences = Self.sentences(in: chunk)
        let monthlyRent = sentences.lazy
            .filter { $0.lowercased().contains("rent") && $0.lowercased().contains("month") }
            .compactMap { Self.firstAmount(in: $0) }.first

        var out: [ExtractedClause] = []
        for sentence in sentences {
            let lower = sentence.lowercased()
            guard let type = Self.keywords.first(where: { $0.1.contains { lower.contains($0) } })?.0 else { continue }
            var params: [String: Double] = [:]
            if let amount = Self.firstAmount(in: sentence) { params["amount"] = amount }
            if let rent = monthlyRent { params["monthly_rent"] = rent }
            out.append(ExtractedClause(type: type, quote: sentence, parameters: params))
        }
        return out + fabricated
    }

    /// Sentences as verbatim substrings (split after . ; ? ! or line breaks).
    static func sentences(in text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for c in text {
            if c.isNewline {
                result.append(current)
                current = ""
                continue
            }
            current.append(c)
            if c == "." || c == ";" || c == "?" || c == "!" {
                result.append(current)
                current = ""
            }
        }
        result.append(current)
        return result.map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count >= 15 }
    }

    /// First "$1,500.00"-style amount in the text.
    static func firstAmount(in text: String) -> Double? {
        guard let dollar = text.firstIndex(of: "$") else { return nil }
        let digits = text[text.index(after: dollar)...].prefix { $0.isNumber || $0 == "," || $0 == "." }
        return Double(digits.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: CharacterSet(charactersIn: ".")))
    }
}
