// Single source of truth for what each clause type means and which numbers it needs.
// Both AI engines build their prompts and output schemas from this, so the model's
// vocabulary can't drift from what the rule packs check. A test asserts that every
// parameter a shipping rule reads is declared here.

public struct ClauseSpec: Sendable {
    public let type: ClauseType
    /// What the model should tag with this type (and, where it matters, what it should NOT).
    public let description: String
    /// Numbers to extract when the document states them: name → meaning.
    public let parameters: [(name: String, meaning: String)]
}

public enum ClauseCatalog {
    public static let specs: [ClauseSpec] = [
        // Residential lease
        .init(type: .pets, description: "restricts or prohibits pets or animals", parameters: []),
        .init(type: .securityDeposit,
              description: "a damage, security, pet or cleaning deposit (NOT a deposit applied to last month's rent)",
              parameters: [("amount", "deposit amount in dollars")]),
        .init(type: .rentDeposit, description: "a rent deposit or last month's rent deposit",
              parameters: [("amount", "deposit amount in dollars"),
                           ("monthly_rent", "monthly rent in dollars, if stated anywhere in the document")]),
        .init(type: .keyDeposit, description: "a deposit for keys, fobs, remotes or access cards",
              parameters: [("amount", "deposit amount in dollars"),
                           ("replacement_cost", "stated cost to replace the key or card, in dollars")]),
        .init(type: .nsfFee, description: "a fee for a returned, bounced or NSF cheque or payment",
              parameters: [("amount", "fee in dollars")]),
        .init(type: .accelerationClause,
              description: "makes remaining or future rent (or a lump sum) due if the tenant defaults or breaks the lease",
              parameters: []),
        .init(type: .postDatedCheques,
              description: "REQUIRES post-dated cheques or automatic payments for rent (NOT when they are only optional)",
              parameters: []),
        .init(type: .landlordEntry, description: "when or how the landlord may enter the unit",
              parameters: [("notice_hours", "advance notice required, in hours; 0 if entry is allowed without notice")]),
        .init(type: .rentIncrease, description: "how or when rent can be increased",
              parameters: [("notice_days", "advance notice of an increase, in days"),
                           ("months_between_increases", "minimum months between increases")]),
        .init(type: .guests, description: "limits on guests or visitors", parameters: []),
        // Employment
        .init(type: .nonCompete,
              description: "stops someone working for a competitor or starting a competing business after leaving",
              parameters: []),
        .init(type: .vacation, description: "paid vacation entitlement",
              parameters: [("vacation_weeks", "vacation per year in weeks; convert working days on a 5-day week (10 days = 2)")]),
        .init(type: .overtime, description: "overtime hours or overtime pay",
              parameters: [("overtime_threshold_hours", "weekly hours after which overtime starts"),
                           ("overtime_multiplier", "overtime pay as a multiple of regular pay, e.g. 1.5; "
                                + "\"regular rate\" or \"straight time\" means 1")]),
        .init(type: .termination, description: "how the agreement or employment can be ended, and any notice", parameters: []),
        // Universal
        .init(type: .autoRenewal, description: "renews automatically unless cancelled", parameters: []),
        .init(type: .unilateralAmendment, description: "lets one party change the terms on its own", parameters: []),
        .init(type: .liabilityWaiver, description: "limits or excludes a party's liability", parameters: []),
        .init(type: .arbitration, description: "requires arbitration or waives class actions or jury trials", parameters: []),
        .init(type: .indemnity, description: "requires one party to cover the other's losses or legal costs", parameters: []),
        .init(type: .contentLicense,
              description: "grants or assigns rights in content, work product or intellectual property "
                  + "(\"all work you create belongs to the Company\", \"assigns all rights in the work\")",
              parameters: []),
        .init(type: .dataSharing, description: "shares personal data with third parties", parameters: []),
        .init(type: .cancellationFee, description: "a fee for cancelling or ending early",
              parameters: [("amount", "fee in dollars")]),
        .init(type: .priceIncrease, description: "allows the price to change during the agreement", parameters: []),
        .init(type: .venue, description: "chooses which law, courts or location govern disputes", parameters: []),
        .init(type: .nonDisparagement, description: "restricts saying negative things about a party", parameters: []),
        .init(type: .assignment,
              description: "allows the AGREEMENT ITSELF to be transferred to another party (not rights in "
                  + "work or IP; that is content_license)",
              parameters: []),
    ]

    public static var extractableTypes: [ClauseType] { specs.map(\.type) }

    static let universal: [ClauseType] = [
        .autoRenewal, .unilateralAmendment, .liabilityWaiver, .arbitration, .indemnity, .contentLicense,
        .dataSharing, .cancellationFee, .priceIncrease, .venue, .nonDisparagement, .assignment, .termination,
    ]

    /// Clause types worth looking for in a given document type (prompt v2).
    /// Phase 3 showed a small model given all 26 types leans on the first ones listed and
    /// mislabels across domains (a subscription "price change" became "rent_increase").
    /// Unknown documents get the universal set plus non-compete: no rule pack applies to them
    /// anyway, so nothing with a legal verdict is lost by scoping.
    public static func types(for documentType: DocumentType) -> [ClauseType] {
        let lease: [ClauseType] = [.pets, .securityDeposit, .rentDeposit, .keyDeposit, .nsfFee, .accelerationClause,
                                   .postDatedCheques, .landlordEntry, .rentIncrease, .guests]
        let employment: [ClauseType] = [.nonCompete, .vacation, .overtime]
        let scoped: [ClauseType] = switch documentType {
        case .residentialLease: lease + universal
        case .employment: employment + universal
        case .subscriptionTerms: universal
        case .unknown: [.nonCompete] + universal
        }
        return specs.map(\.type).filter(scoped.contains)  // keep catalog order
    }

    public static var allParameterNames: [String] {
        Array(Set(specs.flatMap { $0.parameters.map(\.name) })).sorted()
    }

    public static func spec(for type: ClauseType) -> ClauseSpec? {
        specs.first { $0.type == type }
    }

    /// The clause-type list as it appears in both engines' instructions.
    public static var promptList: String { promptList(for: specs.map(\.type)) }

    public static func promptList(for types: [ClauseType]) -> String {
        specs.filter { types.contains($0.type) }.map { spec in
            var line = "- \(spec.type.rawValue): \(spec.description)"
            if !spec.parameters.isEmpty {
                line += ". Parameters: " + spec.parameters.map { "\($0.name) (\($0.meaning))" }.joined(separator: "; ")
            }
            return line
        }.joined(separator: "\n")
    }
}
