// The app's headline guardrail: an extracted clause only counts if its quote can be found
// in the document. A model that invents or paraphrases a clause produces a quote that
// doesn't exist in the source, and the clause is dropped before any rule sees it.

public struct QuoteMatch: Sendable, Equatable {
    /// Character offsets into the original source text.
    public let range: Range<Int>
    /// 1.0 = exact (after normalization); lower = fuzzy match.
    public let score: Double
}

/// Why an extracted clause was discarded before any rule saw it.
public enum VerificationFailure: Error, Sendable, Hashable {
    /// Short quotes ("pets") match almost anything, so they prove nothing.
    case tooShort
    /// Best similarity found anywhere in the source (0 when fuzzy matching is off).
    case notFound(bestScore: Double)
    /// The clause type isn't relevant to this document type (e.g. "rent increase" in gym terms).
    case outOfScope(DocumentType)
    /// LabelGuard: the wording says the opposite of the AI's label ("pets are welcome").
    case labelContradicted(String)

    /// True when the AI's QUOTE was the problem (fabricated or mangled), as opposed to its label.
    public var isQuoteFailure: Bool {
        switch self {
        case .tooShort, .notFound: true
        case .outOfScope, .labelContradicted: false
        }
    }
}

public struct QuoteVerifier: Sendable {
    /// Minimum normalized length for a quote to count as evidence.
    public var minimumCharacters: Int
    /// nil = exact matching only (typed text, PDF text layer).
    /// A value like 0.85 = tolerate OCR errors (images run through Vision).
    public var fuzzyThreshold: Double?
    /// Fuzzy matching is O(source × quote); very long quotes are matched exactly only.
    public var maxFuzzyQuoteLength: Int

    public init(minimumCharacters: Int = 15, fuzzyThreshold: Double? = nil, maxFuzzyQuoteLength: Int = 800) {
        self.minimumCharacters = minimumCharacters
        self.fuzzyThreshold = fuzzyThreshold
        self.maxFuzzyQuoteLength = maxFuzzyQuoteLength
    }

    public func verify(_ quote: String, in source: NormalizedText) -> Result<QuoteMatch, VerificationFailure> {
        let needle = TextNormalizer.normalize(quote).chars
        guard needle.count >= minimumCharacters else { return .failure(.tooShort) }

        if let start = Self.exactFind(needle, in: source.chars) {
            return .success(QuoteMatch(range: source.originalRange(start ..< start + needle.count), score: 1.0))
        }

        guard let threshold = fuzzyThreshold, needle.count <= maxFuzzyQuoteLength,
              let approx = Self.approximateFind(needle, in: source.chars)
        else { return .failure(.notFound(bestScore: 0)) }

        let score = 1.0 - Double(approx.distance) / Double(needle.count)
        guard score >= threshold else { return .failure(.notFound(bestScore: score)) }
        return .success(QuoteMatch(range: source.originalRange(approx.range), score: score))
    }

    // MARK: - Matching

    static func exactFind(_ needle: [Character], in hay: [Character]) -> Int? {
        guard !needle.isEmpty, needle.count <= hay.count else { return nil }
        let first = needle[0]
        var i = 0
        let last = hay.count - needle.count
        while i <= last {
            if hay[i] == first {
                var k = 1
                while k < needle.count, hay[i + k] == needle[k] { k += 1 }
                if k == needle.count { return i }
            }
            i += 1
        }
        return nil
    }

    /// Best approximate occurrence of `pattern` anywhere in `text` by edit distance.
    /// Pass 1 (Sellers' algorithm): free start in the text, so the minimum of the last DP
    /// row gives the best END position. Pass 2: an anchored DP backwards from that end
    /// recovers the START. Both passes are O(n·m) time with O(m) or O(m²) memory.
    static func approximateFind(_ pattern: [Character], in text: [Character]) -> (range: Range<Int>, distance: Int)? {
        let m = pattern.count
        guard m > 0, !text.isEmpty else { return nil }

        var col = Array(0 ... m)
        var bestEnd = -1
        var bestDist = Int.max
        for j in 0 ..< text.count {
            var diag = col[0]
            col[0] = 0
            for i in 1 ... m {
                let up = col[i]
                let cost = pattern[i - 1] == text[j] ? 0 : 1
                col[i] = min(diag + cost, up + 1, col[i - 1] + 1)
                diag = up
            }
            if col[m] < bestDist {
                bestDist = col[m]
                bestEnd = j
            }
        }
        guard bestEnd >= 0 else { return nil }

        // Pass 2: align reversed pattern against text reversed from bestEnd, anchored at bestEnd.
        let lo = max(0, bestEnd - 2 * m)
        let seg = Array(text[lo ... bestEnd].reversed())
        let rp = Array(pattern.reversed())
        var prev = Array(0 ... seg.count)  // row 0: skipping text chars costs 1 each
        for i in 1 ... m {
            var cur = [Int](repeating: 0, count: seg.count + 1)
            cur[0] = i
            for j in 1 ... seg.count {
                let cost = rp[i - 1] == seg[j - 1] ? 0 : 1
                cur[j] = min(prev[j - 1] + cost, prev[j] + 1, cur[j - 1] + 1)
            }
            prev = cur
        }
        // Free end in the reversed segment = free start in the forward text.
        var consumed = 1
        var dist = Int.max
        for j in 1 ... seg.count where prev[j] < dist {
            dist = prev[j]
            consumed = j
        }
        let start = bestEnd + 1 - consumed
        return (start ..< bestEnd + 1, bestDist)
    }
}
