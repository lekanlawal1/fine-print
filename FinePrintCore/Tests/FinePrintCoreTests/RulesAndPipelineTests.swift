import Foundation
import Testing
@testable import FinePrintCore

@Suite("Rule packs")
struct RulePackTests {
    @Test func loadsSnakeCaseJSON() {
        let pack = Fixtures.leasePack
        #expect(pack.documentTypes == [.residentialLease])
        #expect(pack.rules.count == 3)
        #expect(pack.rules[2].check == .maxRatio(param: "amount", ofParam: "monthly_rent", limit: 1))
    }

    @Test func validPackPassesValidation() {
        #expect(PackValidator.validate(Fixtures.leasePack).isEmpty)
        #expect(PackValidator.validate(Fixtures.heuristics).isEmpty)
    }

    @Test func validatorRejectsUnshippablePacks() {
        var pack = Fixtures.leasePack
        pack.rules.append(pack.rules[0])                 // duplicate id
        pack.rules[1].citation = "  "                     // no citation
        pack.lastVerified = "2026-13-40"                  // not a real date
        pack.sourceUrl = "http://example.com"             // not https
        pack.documentTypes.append(.unknown)               // verdicts on unidentified documents

        let problems = PackValidator.validate(pack).joined(separator: " | ")
        #expect(problems.contains("duplicate rule id"))
        #expect(problems.contains("has no citation"))
        #expect(problems.contains("not a yyyy-MM-dd date"))
        #expect(problems.contains("https://"))
        #expect(problems.contains("'unknown' document type"))
    }

    @Test func unknownCheckKindFailsToLoad() {
        let bad = Fixtures.leasePackJSON.replacingOccurrences(of: "\"kind\": \"present\"", with: "\"kind\": \"vibes\"")
        #expect(throws: DecodingError.self) { try PackLoader.rulePack(from: Data(bad.utf8)) }
    }
}

@Suite("RuleEngine")
struct RuleEngineTests {
    let engine = Fixtures.engine

    @Test func presentCheckIsRuleBackedViolationWithCitation() throws {
        let f = try #require(engine.evaluate([Fixtures.verified(.pets)], documentType: .residentialLease).first)
        #expect(f.tier == .ruleViolation)
        #expect(f.citation == "RTA s.14")
        #expect(f.lastVerified == "2026-10-04")
        #expect(f.sourceURL?.hasPrefix("https://") == true)
    }

    @Test func ratioCheckIsDeterministic() {
        let ok = engine.evaluate([Fixtures.verified(.rentDeposit, ["amount": 1500, "monthly_rent": 1500])],
                                 documentType: .residentialLease)
        let over = engine.evaluate([Fixtures.verified(.rentDeposit, ["amount": 3000, "monthly_rent": 1500])],
                                   documentType: .residentialLease)
        #expect(ok.first?.tier == .ruleCompliant)
        #expect(over.first?.tier == .ruleViolation)
    }

    @Test func missingNumbersGoToAHumanNotAGuess() {
        let f = engine.evaluate([Fixtures.verified(.rentDeposit, ["amount": 1500])], documentType: .residentialLease)
        #expect(f.first?.tier == .needsHuman)
        #expect(f.first?.explanation.contains("monthly_rent") == true)
    }

    @Test func unidentifiedDocumentsNeverGetLegalVerdicts() {
        let findings = engine.evaluate([Fixtures.verified(.pets), Fixtures.verified(.autoRenewal, at: 50)],
                                       documentType: .unknown)
        #expect(findings.allSatisfy { $0.citation == nil })
        #expect(findings.map(\.tier) == [.worthALook])   // only the heuristic; the pets rule is out of scope
    }

    @Test func heuristicsCarryNoCitation() throws {
        let f = try #require(engine.evaluate([Fixtures.verified(.arbitration)], documentType: .subscriptionTerms).first)
        #expect(f.tier == .worthALook)
        #expect(f.citation == nil && f.lastVerified == nil)
    }

    @Test func mostSeriousFindingsComeFirst() {
        let findings = engine.evaluate([
            Fixtures.verified(.autoRenewal, at: 0),
            Fixtures.verified(.rentDeposit, ["amount": 1500, "monthly_rent": 1500], at: 30),
            Fixtures.verified(.pets, at: 60),
        ], documentType: .residentialLease)
        #expect(findings.map(\.tier) == [.ruleViolation, .worthALook, .ruleCompliant])
    }
}

@Suite("Analyzer pipeline")
struct AnalyzerTests {
    func analyzer(fabricated: [ExtractedClause] = []) -> Analyzer {
        Analyzer(extractor: MockExtractor(fabricated: fabricated), engine: Fixtures.engine,
                 budget: ChunkBudget(contextSize: 4096))
    }

    @Test func endToEndLeaseAnalysis() async throws {
        let report = try await analyzer().analyze(Fixtures.lease, source: .text)
        #expect(report.documentType == .residentialLease)
        #expect(report.engineName == "Keyword engine (no AI)")

        let byRule = Dictionary(uniqueKeysWithValues: report.findings.map { ($0.title, $0.tier) })
        #expect(byRule["No-pets clause"] == .ruleViolation)
        #expect(byRule["Security deposit"] == .ruleViolation)
        #expect(byRule["Automatic renewal"] == .worthALook)
        #expect(report.dropped.isEmpty)
    }

    @Test func fabricatedClauseIsDroppedBeforeAnyRuleSeesIt() async throws {
        let fake = ExtractedClause(type: .rentDeposit,
                                   quote: "The Tenant shall pay a rent deposit equal to three months of rent.",
                                   parameters: ["amount": 4500, "monthly_rent": 1500])
        let report = try await analyzer(fabricated: [fake]).analyze(Fixtures.lease, source: .text)

        #expect(report.dropped.map(\.clause) == [fake])
        #expect(!report.findings.contains { $0.title == "Rent deposit amount" })
    }

    @Test func findingsPointAtTheRealTextInTheDocument() async throws {
        let report = try await analyzer().analyze(Fixtures.lease, source: .text)
        let pets = try #require(report.findings.first { $0.title == "No-pets clause" })
        let highlighted = String(Array(Fixtures.lease)[pets.clause.range])
        #expect(highlighted == "The Tenant shall not keep any pets or animals in the unit at any time.")
    }

    @Test func duplicateExtractionsAreMerged() {
        let a = VerifiedClause(clause: ExtractedClause(type: .pets, quote: "x"), range: 10 ..< 60, matchScore: 1)
        let b = VerifiedClause(clause: ExtractedClause(type: .pets, quote: "y"), range: 12 ..< 58, matchScore: 1)
        let c = VerifiedClause(clause: ExtractedClause(type: .venue, quote: "z"), range: 12 ..< 58, matchScore: 1)
        #expect(Analyzer.dedupe([a, b, c]).map(\.type) == [.pets, .venue])
    }
}
