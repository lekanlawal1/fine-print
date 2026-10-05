import Foundation
@testable import FinePrintCore

/// Test packs, written as JSON so every test also exercises the real loader.
/// NOTE: these are fixtures for testing the engine, not the shipping legal content;
/// the real packs (with statute text verified against e-Laws) are Phase 2.
enum Fixtures {
    static let leasePackJSON = """
    {
      "id": "test-lease",
      "name": "Test lease pack",
      "jurisdiction": "CA-ON",
      "document_types": ["residential_lease"],
      "last_verified": "2026-10-04",
      "source_url": "https://www.ontario.ca/laws/statute/06r17",
      "rules": [
        { "id": "no-pets-void", "applies_to": "pets", "check": { "kind": "present" },
          "title": "No-pets clause", "citation": "RTA s.14",
          "explanation_if_violated": "A clause prohibiting animals is void." },
        { "id": "security-deposit", "applies_to": "security_deposit", "check": { "kind": "present" },
          "title": "Security deposit", "citation": "RTA s.105",
          "explanation_if_violated": "Security and damage deposits are not permitted." },
        { "id": "rent-deposit-cap", "applies_to": "rent_deposit",
          "check": { "kind": "max_ratio", "param": "amount", "of_param": "monthly_rent", "limit": 1 },
          "title": "Rent deposit amount", "citation": "RTA s.106",
          "explanation_if_violated": "A rent deposit can't exceed one month's rent.",
          "explanation_if_compliant": "The rent deposit is within the one-month limit." }
      ]
    }
    """

    static let heuristicsJSON = """
    {
      "id": "universal",
      "name": "Universal patterns",
      "flags": [
        { "applies_to": "auto_renewal", "title": "Automatic renewal",
          "explanation": "This renews unless you act. Note the cancellation window." },
        { "applies_to": "arbitration", "title": "Mandatory arbitration",
          "explanation": "Disputes may have to go to arbitration instead of court." }
      ]
    }
    """

    static var leasePack: RulePack { try! PackLoader.rulePack(from: Data(leasePackJSON.utf8)) }
    static var heuristics: HeuristicPack { try! PackLoader.heuristicPack(from: Data(heuristicsJSON.utf8)) }
    static var engine: RuleEngine { RuleEngine(packs: [leasePack], heuristics: heuristics) }

    static let lease = """
    RESIDENTIAL TENANCY AGREEMENT

    1. The Landlord agrees to rent the unit to the Tenant for a monthly rent of $1,500.
    2. The Tenant shall not keep any pets or animals in the unit at any time.
    3. The Tenant shall pay a damage deposit of $1,500 before moving in.
    4. This lease will automatically renew for successive one-year terms unless cancelled.
    """

    static func verified(_ type: ClauseType, _ params: [String: Double] = [:], at offset: Int = 0) -> VerifiedClause {
        VerifiedClause(clause: ExtractedClause(type: type, quote: "placeholder quote text", parameters: params),
                       range: offset ..< offset + 20, matchScore: 1)
    }
}
