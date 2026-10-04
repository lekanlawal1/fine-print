// Shared vocabulary for the whole pipeline.
//
// ClauseType is a CLOSED set on purpose: the AI may only tag a clause with one of these
// values, and the rule engine maps (type + parameters) to verdicts. The model never gets
// to write a legal conclusion in free text.

public enum DocumentType: String, Codable, CaseIterable, Sendable {
    case residentialLease = "residential_lease"
    case employment
    case subscriptionTerms = "subscription_terms"
    case unknown
}

public enum ClauseType: String, Codable, CaseIterable, Sendable {
    // residential lease
    case pets
    case securityDeposit = "security_deposit"
    case rentDeposit = "rent_deposit"
    case keyDeposit = "key_deposit"
    case guests
    case rentIncrease = "rent_increase"
    case landlordEntry = "landlord_entry"
    /// The lease REQUIRES post-dated cheques or automatic payments (RTA s.108).
    case postDatedCheques = "post_dated_cheques"
    /// Remaining rent becomes due if the tenant defaults (RTA s.15).
    case accelerationClause = "acceleration_clause"
    /// A fee for a returned/NSF cheque (O. Reg. 516/06 s.17).
    case nsfFee = "nsf_fee"
    // employment
    case nonCompete = "non_compete"
    case vacation
    case termination
    case overtime
    // universal "worth a look" patterns
    case autoRenewal = "auto_renewal"
    case unilateralAmendment = "unilateral_amendment"
    case liabilityWaiver = "liability_waiver"
    case arbitration
    case indemnity
    case contentLicense = "content_license"
    case dataSharing = "data_sharing"
    case cancellationFee = "cancellation_fee"
    case priceIncrease = "price_increase"
    case venue
    case nonDisparagement = "non_disparagement"
    case assignment
    case other
}

/// What an extractor (AI or mock) claims it found. Untrusted until verified.
public struct ExtractedClause: Codable, Sendable, Hashable {
    public var type: ClauseType
    /// Must be copied verbatim from the document; QuoteVerifier enforces this.
    public var quote: String
    /// Numbers some rules need, e.g. ["amount": 1500, "monthly_rent": 1500].
    public var parameters: [String: Double]

    public init(type: ClauseType, quote: String, parameters: [String: Double] = [:]) {
        self.type = type
        self.quote = quote
        self.parameters = parameters
    }
}

/// An extracted clause whose quote was located in the source text.
public struct VerifiedClause: Sendable, Hashable {
    public let clause: ExtractedClause
    /// Character offsets into the ORIGINAL source text (for highlighting).
    public let range: Range<Int>
    /// 1.0 for an exact match; below 1.0 only for fuzzy (OCR) matches.
    public let matchScore: Double
    /// Set by LabelGuard when the wording doesn't clearly support the AI's label. A clause
    /// with a note never gets a rule-backed verdict; it's routed to "check this yourself".
    public let labelNote: String?

    public init(clause: ExtractedClause, range: Range<Int>, matchScore: Double, labelNote: String? = nil) {
        self.clause = clause
        self.range = range
        self.matchScore = matchScore
        self.labelNote = labelNote
    }

    public var type: ClauseType { clause.type }
}

public enum Tier: String, Codable, CaseIterable, Sendable {
    /// The law contradicts this clause (deterministic rule + citation).
    case ruleViolation = "rule_violation"
    /// A rule check passed.
    case ruleCompliant = "rule_compliant"
    /// Common risk pattern; no legal claim is made.
    case worthALook = "worth_a_look"
    /// The system can't decide; a person should read this one.
    case needsHuman = "needs_human"
}

public struct Finding: Sendable, Identifiable, Hashable {
    public let id: String
    public let tier: Tier
    public let title: String
    public let explanation: String
    public let clause: VerifiedClause
    // Present only for rule-backed tiers; heuristics never carry a citation.
    public let citation: String?
    public let packName: String?
    public let lastVerified: String?
    public let sourceURL: String?
    public let exceptionNote: String?
}

public struct TypeGuess: Sendable, Equatable {
    public var type: DocumentType
    public var confidence: Double

    public init(type: DocumentType, confidence: Double) {
        self.type = type
        self.confidence = confidence
    }
}
