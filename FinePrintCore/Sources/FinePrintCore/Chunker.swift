// Fits long documents into a small context window.
//
// Phase 0 measured the on-device window at 4,096 tokens in the iOS Simulator and 8,192 on
// macOS 27, so the budget is computed from the runtime contextSize, never hardcoded.
// Chunks break on clause boundaries (numbered clauses, headings, blank lines) so a clause
// is not cut in half unless it alone exceeds the budget.

public protocol TokenEstimator: Sendable {
    func tokens(in text: String) -> Int
}

/// Deliberately pessimistic (3 characters per token vs the usual ~4): overestimating
/// costs an extra chunk; underestimating overflows the context window mid-request.
public struct ConservativeTokenEstimator: TokenEstimator {
    public var charactersPerToken: Double

    public init(charactersPerToken: Double = 3.0) {
        self.charactersPerToken = charactersPerToken
    }

    public func tokens(in text: String) -> Int {
        Int((Double(text.count) / charactersPerToken).rounded(.up))
    }
}

public struct ChunkBudget: Sendable {
    public var contextSize: Int
    /// Instructions + output schema sent with every request.
    public var reservedForInstructions: Int
    /// Room for the model's JSON answer.
    public var reservedForOutput: Int

    public init(contextSize: Int, reservedForInstructions: Int = 900, reservedForOutput: Int = 1200) {
        self.contextSize = contextSize
        self.reservedForInstructions = reservedForInstructions
        self.reservedForOutput = reservedForOutput
    }

    /// Tokens available for document text per request (never below a usable floor).
    public var inputTokens: Int {
        max(200, contextSize - reservedForInstructions - reservedForOutput)
    }
}

public struct Chunk: Sendable, Equatable {
    public let text: String
    /// Character offset of the chunk's first character in the original document.
    public let offset: Int
}

public struct Chunker: Sendable {
    public var budget: ChunkBudget
    public var estimator: any TokenEstimator

    public init(budget: ChunkBudget, estimator: any TokenEstimator = ConservativeTokenEstimator()) {
        self.budget = budget
        self.estimator = estimator
    }

    public func chunks(for text: String) -> [Chunk] {
        let chars = Array(text)
        guard !chars.isEmpty else { return [] }
        let limit = budget.inputTokens

        var pieces: [Range<Int>] = []
        for segment in Self.segments(chars) {
            if tokens(chars, segment) <= limit {
                pieces.append(segment)
            } else {
                pieces.append(contentsOf: split(chars, segment, limit: limit))
            }
        }

        // Greedily pack contiguous pieces into chunks.
        var result: [Chunk] = []
        var current: Range<Int>?
        for piece in pieces {
            if let cur = current, tokens(chars, cur.lowerBound ..< piece.upperBound) <= limit {
                current = cur.lowerBound ..< piece.upperBound
            } else {
                if let cur = current { result.append(makeChunk(chars, cur)) }
                current = piece
            }
        }
        if let cur = current { result.append(makeChunk(chars, cur)) }
        return result.filter { !$0.text.allSatisfy(\.isWhitespace) }
    }

    // MARK: - Segmentation

    /// Contiguous ranges that together cover the whole text, each starting at a clause boundary.
    static func segments(_ chars: [Character]) -> [Range<Int>] {
        var lineStarts = [0]
        for (i, c) in chars.enumerated() where c.isNewline && i + 1 < chars.count {
            lineStarts.append(i + 1)
        }
        var boundaries = [0]
        var previousBlank = false
        for (n, start) in lineStarts.enumerated() {
            let end = n + 1 < lineStarts.count ? lineStarts[n + 1] : chars.count
            let line = String(chars[start ..< end])
            let blank = line.allSatisfy(\.isWhitespace)
            if start != 0, !blank, previousBlank || isClauseStart(line) {
                boundaries.append(start)
            }
            previousBlank = blank
        }
        boundaries.append(chars.count)
        return zip(boundaries, boundaries.dropFirst()).compactMap { $0 < $1 ? $0 ..< $1 : nil }
    }

    /// "4.", "4.2)", "(a)", "Section 7", "ARTICLE 3", or an ALL-CAPS heading.
    static func isClauseStart(_ line: String) -> Bool {
        let t = line.drop(while: \.isWhitespace)
        guard let first = t.first else { return false }

        if first.isNumber {
            var rest = t.drop(while: { $0.isNumber || $0 == "." })
            if rest.first == ")" { rest = rest.dropFirst() }
            if let last = t.prefix(t.count - rest.count).last, last == "." || last == ")" {
                return rest.first?.isWhitespace ?? false
            }
            return false
        }
        if first == "(" {
            let inner = t.dropFirst().prefix(while: { $0.isLetter || $0.isNumber })
            return (1 ... 3).contains(inner.count) && t.dropFirst(1 + inner.count).first == ")"
        }
        let lower = t.lowercased()
        for word in ["section ", "article ", "clause ", "schedule "] where lower.hasPrefix(word) {
            if lower.dropFirst(word.count).first?.isNumber == true { return true }
        }
        let letters = t.filter(\.isLetter)
        return letters.count >= 5 && letters.allSatisfy(\.isUppercase)
    }

    // MARK: - Oversized segments

    /// Split an oversized segment at sentence ends; hard-split any sentence that is still too long.
    func split(_ chars: [Character], _ range: Range<Int>, limit: Int) -> [Range<Int>] {
        var sentences: [Range<Int>] = []
        var start = range.lowerBound
        var i = range.lowerBound
        while i < range.upperBound {
            let c = chars[i]
            let atEnd = i + 1 == range.upperBound
            if (c == "." || c == ";" || c == "?" || c == "!") && (atEnd || chars[i + 1].isWhitespace) || atEnd {
                sentences.append(start ..< i + 1)
                start = i + 1
            }
            i += 1
        }
        var out: [Range<Int>] = []
        let maxChars = max(1, Int(Double(limit) * 3.0))
        for s in sentences {
            if tokens(chars, s) <= limit {
                out.append(s)
            } else {
                var lo = s.lowerBound
                while lo < s.upperBound {
                    let hi = min(lo + maxChars, s.upperBound)
                    out.append(lo ..< hi)
                    lo = hi
                }
            }
        }
        return out
    }

    func tokens(_ chars: [Character], _ range: Range<Int>) -> Int {
        estimator.tokens(in: String(chars[range]))
    }

    func makeChunk(_ chars: [Character], _ range: Range<Int>) -> Chunk {
        Chunk(text: String(chars[range]), offset: range.lowerBound)
    }
}
