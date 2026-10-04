// The full pipeline: detect type → chunk → extract → VERIFY → dedupe → judge → report.
//
// Verification runs against the whole document, not the chunk, so a quote is accepted only
// if it exists somewhere in what the user actually provided. A chunk the engine fails on is
// recorded and reported, never silently skipped: the user is told which part to read
// themselves.

import Foundation

public enum SourceKind: Sendable {
    /// Typed or pasted text, or a PDF's text layer: quotes must match exactly.
    case text
    /// Text recognized from an image: tolerate OCR errors with fuzzy matching.
    case ocr
}

/// Pipeline stages, reported as they happen so the UI can show real progress.
public enum AnalysisStage: Sendable, Equatable {
    case classifying
    case reading(section: Int, of: Int)
    case checkingQuotes
    case applyingRules
}

public struct DroppedClause: Sendable, Hashable {
    public let clause: ExtractedClause
    public let reason: VerificationFailure
}

public struct FailedChunk: Sendable, Hashable {
    /// Character range of the section that couldn't be analyzed.
    public let range: Range<Int>
    public let reason: String
}

public struct AnalysisReport: Sendable {
    public let documentType: DocumentType
    public let typeConfidence: Double
    /// Set when the engine couldn't classify the document at all (treated as unknown).
    public let typeDetectionError: String?
    public let findings: [Finding]
    /// Clauses the engine claimed but that couldn't be found in the document.
    public let dropped: [DroppedClause]
    /// Sections the engine failed on; the user must read these themselves.
    public let failedChunks: [FailedChunk]
    /// Every clause that passed verification (including ones that produced no finding).
    public let verifiedClauses: [VerifiedClause]
    public let engineName: String
    public let chunkCount: Int
    public let contextSize: Int
    public let elapsedSeconds: Double

    public func count(_ tier: Tier) -> Int { findings.filter { $0.tier == tier }.count }
}

public struct Analyzer: Sendable {
    public var extractor: any ClauseExtractor
    public var engine: RuleEngine
    public var budget: ChunkBudget
    /// Below this, the document is treated as "unknown": no rule pack, amber flags only.
    public var typeConfidenceThreshold: Double
    public var ocrFuzzyThreshold: Double

    public init(extractor: any ClauseExtractor, engine: RuleEngine, budget: ChunkBudget? = nil,
                typeConfidenceThreshold: Double = 0.6, ocrFuzzyThreshold: Double = 0.85) {
        self.extractor = extractor
        self.engine = engine
        self.budget = budget ?? extractor.chunkBudget
        self.typeConfidenceThreshold = typeConfidenceThreshold
        self.ocrFuzzyThreshold = ocrFuzzyThreshold
    }

    public func analyze(_ text: String, source: SourceKind,
                        onProgress: @Sendable (AnalysisStage) -> Void = { _ in }) async throws -> AnalysisReport {
        let started = Date()

        // A classification failure is not fatal: unknown type = amber flags only.
        onProgress(.classifying)
        var guess = TypeGuess(type: .unknown, confidence: 0)
        var typeError: String?
        do {
            guess = try await extractor.detectDocumentType(text)
        } catch {
            typeError = Self.describe(error)
        }
        let documentType = guess.confidence >= typeConfidenceThreshold ? guess.type : .unknown

        let chunks = Chunker(budget: budget).chunks(for: text)
        var extracted: [ExtractedClause] = []
        var failed: [FailedChunk] = []
        for (index, chunk) in chunks.enumerated() {
            try Task.checkCancellation()
            onProgress(.reading(section: index + 1, of: chunks.count))
            do {
                extracted += try await extractor.extractClauses(from: chunk.text, documentType: documentType)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failed.append(FailedChunk(range: chunk.offset ..< chunk.offset + chunk.text.count,
                                          reason: Self.describe(error)))
            }
        }

        onProgress(.checkingQuotes)
        let verifier = QuoteVerifier(fuzzyThreshold: source == .ocr ? ocrFuzzyThreshold : nil)
        let normalized = TextNormalizer.normalize(text)
        var verified: [VerifiedClause] = []
        var dropped: [DroppedClause] = []
        let inScope = Set(ClauseCatalog.types(for: documentType))
        let characters = Array(text)
        for clause in extracted {
            // 1. Scope: a clause type irrelevant to this document type is discarded.
            guard inScope.contains(clause.type) else {
                dropped.append(DroppedClause(clause: clause, reason: .outOfScope(documentType)))
                continue
            }
            // 2. Quote: the text must exist in the document.
            let match: QuoteMatch
            switch verifier.verify(clause.quote, in: normalized) {
            case let .success(m): match = m
            case let .failure(reason):
                dropped.append(DroppedClause(clause: clause, reason: reason))
                continue
            }
            // 3. Label: the real wording must support the AI's label before any rule judges it.
            let wording = String(characters[match.range])
            switch LabelGuard.check(clause.type, text: wording) {
            case .consistent:
                verified.append(VerifiedClause(clause: clause, range: match.range, matchScore: match.score))
            case let .unsupported(note):
                verified.append(VerifiedClause(clause: clause, range: match.range, matchScore: match.score, labelNote: note))
            case let .contradicted(note):
                dropped.append(DroppedClause(clause: clause, reason: .labelContradicted(note)))
            }
        }

        onProgress(.applyingRules)
        let unique = Self.dedupe(verified)
        return AnalysisReport(
            documentType: documentType, typeConfidence: guess.confidence, typeDetectionError: typeError,
            findings: engine.evaluate(unique, documentType: documentType),
            dropped: dropped, failedChunks: failed, verifiedClauses: unique,
            engineName: extractor.name, chunkCount: chunks.count, contextSize: budget.contextSize,
            elapsedSeconds: Date().timeIntervalSince(started))
    }

    /// The same clause can be extracted twice (overlapping chunks, or a model repeating
    /// itself). Same type + more than half overlap = duplicate; keep the first.
    /// Different types on the same text are kept: one clause can be both arbitration and venue.
    static func dedupe(_ clauses: [VerifiedClause]) -> [VerifiedClause] {
        var kept: [VerifiedClause] = []
        for c in clauses.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) {
            let duplicate = kept.contains { k in
                guard k.type == c.type else { return false }
                let overlap = max(0, min(k.range.upperBound, c.range.upperBound) - max(k.range.lowerBound, c.range.lowerBound))
                return Double(overlap) > 0.5 * Double(min(k.range.count, c.range.count))
            }
            if !duplicate { kept.append(c) }
        }
        return kept
    }

    static func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }
}
