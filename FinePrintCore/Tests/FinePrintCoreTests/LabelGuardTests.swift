// LabelGuard must catch mislabels WITHOUT blocking real violations. Both directions are
// tested with wording taken from the evaluation corpus: a guard that rejects genuine
// violations would trade wrong verdicts for false reassurance, which is worse.

import Testing
@testable import FinePrintCore

struct GuardCase: Sendable, CustomTestStringConvertible {
    let type: ClauseType
    let text: String
    let expected: String  // "ok", "unsupported", "contradicted"
    var testDescription: String { "\(type.rawValue): \(text.prefix(50)) → \(expected)" }
}

let guardCases: [GuardCase] = [
    // Real violations from the corpus: must stay consistent so rules can judge them.
    GuardCase(type: .pets, text: "The Tenant shall not keep any pets or animals in the unit at any time.", expected: "ok"),
    GuardCase(type: .pets, text: "No pets or animals of any kind are allowed in the unit.", expected: "ok"),
    GuardCase(type: .pets, text: "No pets are allowed in the building.", expected: "ok"),
    GuardCase(type: .pets, text: "No pets or anirnals are allowed in the unit or on the property at any tirne.", expected: "ok"),
    GuardCase(type: .pets, text: "The Tenant shall not keep any dogs, cats or other animals in the Premises.", expected: "ok"),
    GuardCase(type: .securityDeposit, text: "The Tenant shall also pay a damage deposit of $600, refundable at the end of the tenancy if the unit is undamaged.", expected: "ok"),
    GuardCase(type: .securityDeposit, text: "The Tenant shall pay a secur-\nity deposit of $500 on signing, to be held by the Landlord against\ndamage to the unit.", expected: "ok"),
    GuardCase(type: .securityDeposit, text: "The Tenant shall also pay a cleaning deposit of $400, which will be returned at the end of the tenancy.", expected: "ok"),
    GuardCase(type: .postDatedCheques, text: "The Tenant must provide twelve post-dated cheques for the year's rent before moving in.", expected: "ok"),
    GuardCase(type: .postDatedCheques, text: "Rent shall be paid by pre-authorized debit from the Tenant's bank account, and the Tenant must sign the debit authorization before receiving keys.", expected: "ok"),
    GuardCase(type: .nsfFee, text: "A fee of $50 will be charged for any cheque returned NSF.", expected: "ok"),
    GuardCase(type: .nonCompete, text: "For 12 months after your employment ends, you will not work for any business that competes with Northwind Analytics in Canada.", expected: "ok"),
    GuardCase(type: .accelerationClause, text: "If the Tenant fails to pay rent within five days, the full amount of rent for the balance of the term shall immediately become due and payable.", expected: "ok"),

    // Negations and permissions: the opposite of the label, so no verdict at all.
    GuardCase(type: .pets, text: "Pets are welcome. The Tenant may keep cats and dogs in the unit.", expected: "contradicted"),
    GuardCase(type: .securityDeposit, text: "No damage deposit or security deposit will be required for this tenancy.", expected: "contradicted"),
    GuardCase(type: .postDatedCheques, text: "Post-dated cheques are optional. The Tenant may pay rent by cheque, e-transfer or cash.", expected: "contradicted"),
    GuardCase(type: .postDatedCheques, text: "The Tenant may pay rent by cheque, e-transfer or pre-authorized debit, at the Tenant's choice.", expected: "contradicted"),
    GuardCase(type: .nsfFee, text: "The Landlord will not charge any fee for a returned or NSF cheque beyond the bank's own charges.", expected: "contradicted"),

    // Mislabels the on-device model actually made: downgraded to "check this yourself".
    GuardCase(type: .securityDeposit, text: "The Tenant shall pay a rent deposit of $1,800, to be applied to the last month of the tenancy.", expected: "unsupported"),
    GuardCase(type: .securityDeposit, text: "A refundable key deposit of $40 is required, which is the cost of replacing both keys.", expected: "unsupported"),
    GuardCase(type: .nonCompete, text: "For twelve months after your employment ends, you will not solicit any client of Harbourline.", expected: "unsupported"),
    GuardCase(type: .pets, text: "Guests are welcome at any time.", expected: "unsupported"),
]

@Suite("LabelGuard")
struct LabelGuardTests {
    @Test(arguments: guardCases)
    func check(_ c: GuardCase) {
        let result = LabelGuard.check(c.type, text: c.text)
        switch (c.expected, result) {
        case ("ok", .consistent), ("unsupported", .unsupported), ("contradicted", .contradicted): break
        default: Issue.record("expected \(c.expected), got \(result)")
        }
    }

    @Test func typesWithoutVerdictsAreNeverBlocked() {
        #expect(LabelGuard.check(.arbitration, text: "anything at all") == .consistent)
        #expect(LabelGuard.check(.autoRenewal, text: "x") == .consistent)
    }

    @Test func everyRuleCarryingTypeHasAGuard() {
        // A rule-backed type without a guard could issue verdicts on mislabels unchecked.
        for rule in ShippingPacks.lease.rules + ShippingPacks.employment.rules where rule.check != .review {
            #expect(LabelGuard.rules[rule.appliesTo] != nil, "no LabelGuard rule for \(rule.appliesTo.rawValue)")
        }
    }
}

@Suite("Analyzer with LabelGuard and scope")
struct GuardedAnalyzerTests {
    let engine = RuleEngine(packs: [ShippingPacks.lease, ShippingPacks.employment], heuristics: ShippingPacks.heuristics)

    /// An extractor that returns exactly the clauses it's given (simulating a model's mistakes).
    struct Scripted: ClauseExtractor {
        let name = "scripted"
        let chunkBudget = ChunkBudget(contextSize: 8192)
        let type: DocumentType
        let clauses: [ExtractedClause]
        func detectDocumentType(_ text: String) async throws -> TypeGuess { TypeGuess(type: type, confidence: 1) }
        func extractClauses(from chunk: String, documentType: DocumentType) async throws -> [ExtractedClause] { clauses }
    }

    @Test func permissivePetsClauseGetsNoVerdict() async throws {
        let doc = "1. Pets are welcome. The Tenant may keep cats and dogs in the unit."
        let report = try await Analyzer(extractor: Scripted(type: .residentialLease, clauses: [
            ExtractedClause(type: .pets, quote: "Pets are welcome. The Tenant may keep cats and dogs in the unit."),
        ]), engine: engine).analyze(doc, source: .text)
        #expect(report.findings.isEmpty)
        #expect(report.dropped.first.map { if case .labelContradicted = $0.reason { true } else { false } } == true)
    }

    @Test func mislabelledRentDepositBecomesCheckYourselfNotAViolation() async throws {
        let doc = "2. The Tenant shall pay a rent deposit of $1,800, to be applied to the last month of the tenancy."
        let report = try await Analyzer(extractor: Scripted(type: .residentialLease, clauses: [
            ExtractedClause(type: .securityDeposit, quote: "The Tenant shall pay a rent deposit of $1,800, to be applied to the last month of the tenancy.",
                            parameters: ["amount": 1800]),
        ]), engine: engine).analyze(doc, source: .text)
        let f = try #require(report.findings.first)
        #expect(f.tier == .needsHuman)
        #expect(f.explanation.contains("won't give a legal verdict"))
    }

    @Test func outOfScopeTypesAreDropped() async throws {
        let doc = "We may change the price of your subscription with 7 days' notice."
        let report = try await Analyzer(extractor: Scripted(type: .subscriptionTerms, clauses: [
            ExtractedClause(type: .rentIncrease, quote: "We may change the price of your subscription with 7 days' notice."),
        ]), engine: engine).analyze(doc, source: .text)
        #expect(report.findings.isEmpty)
        #expect(report.dropped.first?.reason == .outOfScope(.subscriptionTerms))
        #expect(report.dropped.first?.reason.isQuoteFailure == false)
    }

    @Test func scopedPromptOnlyListsRelevantTypes() {
        let subscription = Prompts.extractionInstructions(for: .subscriptionTerms)
        #expect(!subscription.contains("rent_increase"))
        #expect(!subscription.contains("- pets:"))
        #expect(subscription.contains("auto_renewal"))
        let lease = Prompts.extractionInstructions(for: .residentialLease)
        #expect(lease.contains("rent_increase") && !lease.contains("- vacation:"))
    }
}
