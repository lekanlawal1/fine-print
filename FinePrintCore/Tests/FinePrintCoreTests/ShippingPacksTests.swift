// Tests for the REAL rule packs in fine-print/Packs (the files the app ships).
// Every rule must have at least one test case; a coverage test enforces that, so a rule
// can't be added to a pack without a test.

import Foundation
import Testing
@testable import FinePrintCore

enum ShippingPacks {
    static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // FinePrintCoreTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // FinePrintCore
        .deletingLastPathComponent()  // fine-print
        .appendingPathComponent("Packs")

    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: directory.appendingPathComponent(name))
    }

    static let lease = try! PackLoader.rulePack(from: data("ca-on-residential-lease.json"))
    static let employment = try! PackLoader.rulePack(from: data("ca-on-employment.json"))
    static let heuristics = try! PackLoader.heuristicPack(from: data("universal-heuristics.json"))
    static let engine = RuleEngine(packs: [lease, employment], heuristics: heuristics)
}

struct RuleCase: Sendable, CustomTestStringConvertible {
    let rule: String
    let document: DocumentType
    let type: ClauseType
    let params: [String: Double]
    let expected: Tier

    var testDescription: String { "\(rule) \(params) → \(expected.rawValue)" }
}

let ruleCases: [RuleCase] = [
    // Residential lease
    RuleCase(rule: "no-pets-void", document: .residentialLease, type: .pets, params: [:], expected: .ruleViolation),
    RuleCase(rule: "acceleration-void", document: .residentialLease, type: .accelerationClause, params: [:], expected: .ruleViolation),
    RuleCase(rule: "security-deposit", document: .residentialLease, type: .securityDeposit, params: ["amount": 500], expected: .ruleViolation),
    RuleCase(rule: "rent-deposit-cap", document: .residentialLease, type: .rentDeposit, params: ["amount": 1500, "monthly_rent": 1500], expected: .ruleCompliant),
    RuleCase(rule: "rent-deposit-cap", document: .residentialLease, type: .rentDeposit, params: ["amount": 1600, "monthly_rent": 1500], expected: .ruleViolation),
    RuleCase(rule: "rent-deposit-cap", document: .residentialLease, type: .rentDeposit, params: ["amount": 1500], expected: .needsHuman),
    RuleCase(rule: "key-deposit-limit", document: .residentialLease, type: .keyDeposit, params: ["amount": 50], expected: .needsHuman),
    RuleCase(rule: "key-deposit-limit", document: .residentialLease, type: .keyDeposit, params: ["amount": 50, "replacement_cost": 50], expected: .ruleCompliant),
    RuleCase(rule: "key-deposit-limit", document: .residentialLease, type: .keyDeposit, params: ["amount": 100, "replacement_cost": 50], expected: .ruleViolation),
    RuleCase(rule: "nsf-admin-fee", document: .residentialLease, type: .nsfFee, params: ["amount": 20], expected: .ruleCompliant),
    RuleCase(rule: "nsf-admin-fee", document: .residentialLease, type: .nsfFee, params: ["amount": 50], expected: .ruleViolation),
    RuleCase(rule: "required-postdated-cheques", document: .residentialLease, type: .postDatedCheques, params: [:], expected: .ruleViolation),
    RuleCase(rule: "entry-notice", document: .residentialLease, type: .landlordEntry, params: ["notice_hours": 24], expected: .ruleCompliant),
    RuleCase(rule: "entry-notice", document: .residentialLease, type: .landlordEntry, params: ["notice_hours": 12], expected: .ruleViolation),
    RuleCase(rule: "entry-notice", document: .residentialLease, type: .landlordEntry, params: ["notice_hours": 0], expected: .ruleViolation),
    RuleCase(rule: "rent-increase-notice", document: .residentialLease, type: .rentIncrease, params: ["notice_days": 90], expected: .ruleCompliant),
    RuleCase(rule: "rent-increase-notice", document: .residentialLease, type: .rentIncrease, params: ["notice_days": 30], expected: .ruleViolation),
    RuleCase(rule: "rent-increase-frequency", document: .residentialLease, type: .rentIncrease, params: ["months_between_increases": 12], expected: .ruleCompliant),
    RuleCase(rule: "rent-increase-frequency", document: .residentialLease, type: .rentIncrease, params: ["months_between_increases": 6], expected: .ruleViolation),
    // Employment
    RuleCase(rule: "non-compete-void", document: .employment, type: .nonCompete, params: [:], expected: .ruleViolation),
    RuleCase(rule: "vacation-minimum", document: .employment, type: .vacation, params: ["vacation_weeks": 2], expected: .ruleCompliant),
    RuleCase(rule: "vacation-minimum", document: .employment, type: .vacation, params: ["vacation_weeks": 1], expected: .ruleViolation),
    RuleCase(rule: "overtime-threshold", document: .employment, type: .overtime, params: ["overtime_threshold_hours": 44], expected: .ruleCompliant),
    RuleCase(rule: "overtime-threshold", document: .employment, type: .overtime, params: ["overtime_threshold_hours": 50], expected: .ruleViolation),
    RuleCase(rule: "overtime-rate", document: .employment, type: .overtime, params: ["overtime_multiplier": 1.5], expected: .ruleCompliant),
    RuleCase(rule: "overtime-rate", document: .employment, type: .overtime, params: ["overtime_multiplier": 1.0], expected: .ruleViolation),
    RuleCase(rule: "termination-notice-review", document: .employment, type: .termination, params: [:], expected: .needsHuman),
]

@Suite("Shipping rule packs")
struct ShippingPacksTests {
    @Test func allPacksLoadAndValidate() {
        #expect(PackValidator.validate(ShippingPacks.lease).isEmpty, "\(PackValidator.validate(ShippingPacks.lease))")
        #expect(PackValidator.validate(ShippingPacks.employment).isEmpty, "\(PackValidator.validate(ShippingPacks.employment))")
        #expect(PackValidator.validate(ShippingPacks.heuristics).isEmpty, "\(PackValidator.validate(ShippingPacks.heuristics))")
    }

    @Test(arguments: ruleCases)
    func rule(_ c: RuleCase) throws {
        let clause = Fixtures.verified(c.type, c.params)
        let findings = ShippingPacks.engine.evaluate([clause], documentType: c.document)
        let pack = c.document == .employment ? ShippingPacks.employment : ShippingPacks.lease
        let finding = try #require(findings.first { $0.id.hasPrefix("\(pack.id).\(c.rule)#") },
                                   "no finding for \(c.rule)")
        #expect(finding.tier == c.expected)
        #expect(finding.citation?.isEmpty == false)
        #expect(finding.lastVerified == pack.lastVerified)
    }

    @Test func everyShippingRuleHasATestCase() {
        let allRules = Set((ShippingPacks.lease.rules + ShippingPacks.employment.rules).map(\.id))
        let tested = Set(ruleCases.map(\.rule))
        #expect(allRules.subtracting(tested).isEmpty, "untested rules: \(allRules.subtracting(tested).sorted())")
    }

    @Test func rulesFromTheRegulationLinkToTheRegulation() {
        for type in [ClauseType.keyDeposit, .nsfFee] {
            let f = ShippingPacks.engine.evaluate([Fixtures.verified(type, ["amount": 10])], documentType: .residentialLease)
            #expect(f.first?.sourceURL == "https://www.ontario.ca/laws/regulation/060516")
        }
    }

    @Test func employmentRulesNeverFireOnALease() {
        // A non-compete outside an employment document (e.g. a contractor agreement filed as
        // unknown) gets the amber flag, never the ESA verdict.
        for doc in [DocumentType.residentialLease, .unknown, .subscriptionTerms] {
            let f = ShippingPacks.engine.evaluate([Fixtures.verified(.nonCompete)], documentType: doc)
            #expect(f.map(\.tier) == [.worthALook])
            #expect(f.allSatisfy { $0.citation == nil })
        }
    }

    @Test func everyParameterARuleReadsIsInTheCatalog() {
        // If a rule reads a number the extraction prompt never asks for, that rule can only
        // ever return "needs a human". This catches that drift.
        let declared = Set(ClauseCatalog.allParameterNames)
        for rule in ShippingPacks.lease.rules + ShippingPacks.employment.rules {
            let needed: [String]
            switch rule.check {
            case .present, .review: needed = []
            case let .maxRatio(p, of, _): needed = [p, of]
            case let .maxValue(p, _), let .minValue(p, _): needed = [p]
            }
            for name in needed {
                #expect(declared.contains(name), "rule '\(rule.id)' reads '\(name)', which the catalog never asks for")
            }
            #expect(ClauseCatalog.spec(for: rule.appliesTo) != nil, "rule '\(rule.id)' targets a type the AI can't extract")
        }
    }

    @Test func guestLimitsAreAmberBecauseNoSectionAddressesThem() throws {
        let f = try #require(ShippingPacks.engine.evaluate([Fixtures.verified(.guests)], documentType: .residentialLease).first)
        #expect(f.tier == .worthALook)
        #expect(f.citation == nil)
    }

    @Test func amberFlagsNeverClaimSomethingIsIllegal() {
        let forbidden = ["illegal", "unlawful", "void", "unenforceable", "not allowed", "prohibited"]
        for flag in ShippingPacks.heuristics.flags {
            let text = (flag.title + " " + flag.explanation).lowercased()
            for word in forbidden {
                #expect(!text.contains(word), "heuristic '\(flag.appliesTo.rawValue)' says '\(word)'")
            }
        }
    }
}
