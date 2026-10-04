import Testing
@testable import FinePrintCore

@Suite("TextNormalizer")
struct TextNormalizerTests {
    @Test func foldsQuotesAndCase() {
        #expect(TextNormalizer.normalize("\u{201C}Tenant\u{2019}s\u{201D} PET").string == "\"tenant's\" pet")
    }

    @Test func collapsesAndTrimsWhitespace() {
        #expect(TextNormalizer.normalize("  a \n\n b\t c ").string == "a b c")
    }

    @Test func joinsLineBreakHyphenationAndDropsDashes() {
        #expect(TextNormalizer.normalize("rent-\nal unit").string == "rental unit")
        #expect(TextNormalizer.normalize("self-contained").string == "selfcontained")
        #expect(TextNormalizer.normalize("rent \u{2014} due").string == "rent due")
    }

    @Test func expandsLigaturesAndMapsBackToOriginal() {
        let n = TextNormalizer.normalize("\u{FB01}ne print")
        #expect(n.string == "fine print")
        // "fine" (4 normalized chars) came from the 3 original characters "ﬁne".
        #expect(n.originalRange(0 ..< 4) == 0 ..< 3)
    }
}

@Suite("QuoteVerifier")
struct QuoteVerifierTests {
    let source = """
    4. The Tenant shall not keep any pets or animals in the unit at any time.
    5. The Tenant shall pay a damage deposit of $1,500 before moving in.
    """
    var normalized: NormalizedText { TextNormalizer.normalize(source) }

    func originalText(_ r: Range<Int>, in s: String) -> String {
        String(Array(s)[r])
    }

    @Test func exactQuoteMapsToOriginalText() throws {
        let quote = "The Tenant shall not keep any pets or animals in the unit at any time."
        let match = try QuoteVerifier().verify(quote, in: normalized).get()
        #expect(match.score == 1.0)
        #expect(originalText(match.range, in: source) == quote)
    }

    @Test func toleratesModelReformatting() throws {
        // Curly quotes, doubled spaces, a line break, different case: still the same clause.
        let quote = "the tenant  shall NOT keep any pets\nor animals"
        #expect(throws: Never.self) { try QuoteVerifier().verify(quote, in: normalized).get() }
    }

    @Test func rejectsFabricatedClause() {
        let result = QuoteVerifier().verify("The Tenant may keep one small cat with written approval.", in: normalized)
        #expect(result == .failure(.notFound(bestScore: 0)))
    }

    @Test func rejectsQuotesTooShortToProveAnything() {
        #expect(QuoteVerifier().verify("pets", in: normalized) == .failure(.tooShort))
    }

    @Test func rejectsParaphraseEvenWithFuzzyMatching() {
        let paraphrase = "The Tenant is not allowed to have pets or animals in the unit."
        guard case let .failure(.notFound(score)) = QuoteVerifier(fuzzyThreshold: 0.85).verify(paraphrase, in: normalized)
        else { Issue.record("a paraphrase must not verify"); return }
        #expect(score < 0.85)
    }

    @Test func ocrNoiseNeedsFuzzyModeAndStillLocatesTheClause() throws {
        let ocrSource = "4. The Tenant shaII not keep any pets or anirnals in the unit at any tirne.\n5. Rent is due monthly."
        let clean = "The Tenant shall not keep any pets or animals in the unit at any time."
        let n = TextNormalizer.normalize(ocrSource)

        #expect(throws: VerificationFailure.self) { try QuoteVerifier().verify(clean, in: n).get() }

        let match = try QuoteVerifier(fuzzyThreshold: 0.85).verify(clean, in: n).get()
        #expect(match.score >= 0.85 && match.score < 1.0)
        let located = originalText(match.range, in: ocrSource)
        #expect(located.hasPrefix("The Tenant"))
        #expect(located.hasSuffix("tirne."))
    }
}
