import Foundation
import Testing
@testable import FinePrintCore

@Suite("Report export and progress")
struct ReportAndProgressTests {
    func report() async throws -> AnalysisReport {
        let engine = RuleEngine(packs: [ShippingPacks.lease], heuristics: ShippingPacks.heuristics)
        return try await Analyzer(extractor: MockExtractor(), engine: engine).analyze(Fixtures.lease, source: .text)
    }

    @Test func exportCarriesDisclaimerCitationsAndRealQuotes() async throws {
        let text = ReportFormatter.text(try await report(), documentTitle: "Sample lease", source: Fixtures.lease)
        #expect(text.contains(ReportFormatter.disclaimer))
        #expect(text.contains("Residential Tenancies Act, 2006, s. 14"))
        #expect(text.contains("(checked 2026-10-04)"))
        #expect(text.contains("\"The Tenant shall not keep any pets or animals in the unit at any time.\""))
        #expect(text.contains("Read by: Keyword engine (no AI)"))
    }

    @Test func amberSectionMakesNoLegalClaims() async throws {
        let text = ReportFormatter.text(try await report(), documentTitle: "x", source: Fixtures.lease)
        let amber = text.components(separatedBy: "WORTH A LOOK").dropFirst().first?
            .components(separatedBy: "\n\n").first ?? ""
        #expect(!amber.isEmpty)
        #expect(!amber.lowercased().contains("void") && !amber.lowercased().contains("illegal"))
        #expect(!amber.contains("Source:"))
    }

    @Test func progressReportsEveryStageInOrder() async throws {
        final class Recorder: @unchecked Sendable { var stages: [AnalysisStage] = [] }
        let recorder = Recorder()
        _ = try await Analyzer(extractor: MockExtractor(), engine: Fixtures.engine)
            .analyze(Fixtures.lease, source: .text) { recorder.stages.append($0) }
        #expect(recorder.stages == [.classifying, .reading(section: 1, of: 1), .checkingQuotes, .applyingRules])
    }
}
