import Testing
@testable import FinePrintCore

@Suite("Chunker")
struct ChunkerTests {
    let estimator = ConservativeTokenEstimator()

    func numberedDocument(clauses: Int) -> String {
        (1 ... clauses).map { n in
            "\(n). " + String(repeating: "The party agrees to the terms set out in this section. ", count: 4)
        }.joined(separator: "\n")
    }

    @Test func shortDocumentIsOneChunk() {
        let chunks = Chunker(budget: ChunkBudget(contextSize: 4096)).chunks(for: Fixtures.lease)
        #expect(chunks.count == 1)
        #expect(chunks[0].text == Fixtures.lease)
    }

    @Test func respectsBudgetAndCoversWholeDocument() {
        let doc = numberedDocument(clauses: 40)
        let budget = ChunkBudget(contextSize: 600, reservedForInstructions: 100, reservedForOutput: 100)
        let chunks = Chunker(budget: budget).chunks(for: doc)

        #expect(chunks.count > 1)
        for chunk in chunks {
            #expect(estimator.tokens(in: chunk.text) <= budget.inputTokens)
        }
        // Contiguous and complete: no text is lost between chunks.
        #expect(chunks.map(\.text).joined() == doc)
        #expect(chunks.first?.offset == 0)
    }

    @Test func breaksOnClauseBoundaries() {
        let budget = ChunkBudget(contextSize: 600, reservedForInstructions: 100, reservedForOutput: 100)
        for chunk in Chunker(budget: budget).chunks(for: numberedDocument(clauses: 40)) {
            #expect(chunk.text.first?.isNumber == true, "chunk should start at a numbered clause")
        }
    }

    @Test func splitsOversizedClauseAtSentences() {
        let giant = "1. " + String(repeating: "This sentence is part of one enormous clause. ", count: 80)
        let budget = ChunkBudget(contextSize: 600, reservedForInstructions: 100, reservedForOutput: 100)
        let chunks = Chunker(budget: budget).chunks(for: giant)
        #expect(chunks.count > 1)
        #expect(chunks.allSatisfy { estimator.tokens(in: $0.text) <= budget.inputTokens })
        #expect(chunks.map(\.text).joined() == giant)
    }

    @Test(arguments: [
        ("4. Rent", true), ("4.2) Deposit", true), ("(a) Pets", true), ("Section 7 Entry", true),
        ("ARTICLE 3", true), ("TERMS AND CONDITIONS", true),
        ("2026 budget review", false), ("$1,500 deposit", false), ("The tenant agrees", false),
    ])
    func clauseStartDetection(line: String, expected: Bool) {
        #expect(Chunker.isClauseStart(line) == expected)
    }

    @Test func budgetComesFromRuntimeContextSize() {
        // Phase 0: 4,096 tokens in the iOS Simulator, 8,192 on macOS 27.
        #expect(ChunkBudget(contextSize: 8192).inputTokens > ChunkBudget(contextSize: 4096).inputTokens)
        #expect(ChunkBudget(contextSize: 100).inputTokens == 200)  // never below the floor
    }
}
