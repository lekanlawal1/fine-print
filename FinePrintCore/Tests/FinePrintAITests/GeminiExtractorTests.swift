// Gemini engine tests against a stubbed network: no real API calls, no key, no cost.

import Foundation
import Testing
@testable import FinePrintAI
@testable import FinePrintCore

final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responses: [(Int, String)] = []
    nonisolated(unsafe) static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests.append(request)
        let (status, body) = Self.responses.isEmpty ? (500, "{}") : Self.responses.removeFirst()
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

/// A Gemini response whose answer text is `json`.
func geminiBody(_ json: String, finish: String = "STOP", thought: String? = nil) -> String {
    var parts: [[String: Any]] = []
    if let thought { parts.append(["text": thought, "thought": true]) }
    parts.append(["text": json])
    let body: [String: Any] = ["candidates": [["content": ["parts": parts], "finishReason": finish]]]
    return String(data: try! JSONSerialization.data(withJSONObject: body), encoding: .utf8)!
}

@Suite("GeminiExtractor (stubbed network)", .serialized)
struct GeminiExtractorTests {
    func extractor() -> GeminiExtractor {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        StubProtocol.requests = []
        return GeminiExtractor(apiKey: "test-key", session: URLSession(configuration: config), baseDelay: 0.01)
    }

    @Test func parsesClausesAndFiltersParameters() async throws {
        let gemini = extractor()
        StubProtocol.responses = [(200, geminiBody("""
            {"clauses":[
              {"type":"rent_deposit","quote":"A rent deposit of $1,500 is required.",
               "parameters":[{"name":"amount","value":1500},{"name":"monthly_rent","value":1500},
                             {"name":"notice_days","value":90}]},
              {"type":"not_a_real_type","quote":"Something else entirely here."}
            ]}
            """))]
        let clauses = try await gemini.extractClauses(from: "text", documentType: .residentialLease)
        #expect(clauses.count == 1)  // unknown type dropped
        #expect(clauses[0].type == .rentDeposit)
        // notice_days doesn't belong to rent_deposit, so it's filtered out
        #expect(clauses[0].parameters == ["amount": 1500, "monthly_rent": 1500])
    }

    @Test func ignoresThoughtParts() async throws {
        let gemini = extractor()
        StubProtocol.responses = [(200, geminiBody(#"{"type":"employment","confidence":0.9}"#, thought: "let me think..."))]
        let guess = try await gemini.detectDocumentType("Offer of employment")
        #expect(guess == TypeGuess(type: .employment, confidence: 0.9))
    }

    @Test func sendsKeyInHeaderNeverInURL() async throws {
        let gemini = extractor()
        StubProtocol.responses = [(200, geminiBody(#"{"type":"unknown","confidence":0.2}"#))]
        _ = try await gemini.detectDocumentType("x")
        let request = try #require(StubProtocol.requests.first)
        #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "test-key")
        #expect(request.url?.absoluteString.contains("test-key") == false)
    }

    @Test func retriesRateLimitsThenSucceeds() async throws {
        let gemini = extractor()
        StubProtocol.responses = [(429, #"{"error":{"message":"quota"}}"#),
                                  (503, #"{"error":{"message":"busy"}}"#),
                                  (200, geminiBody(#"{"type":"employment","confidence":0.8}"#))]
        let guess = try await gemini.detectDocumentType("x")
        #expect(guess.type == .employment)
        #expect(StubProtocol.requests.count == 3)
    }

    @Test func doesNotRetryABadKey() async {
        let gemini = extractor()
        StubProtocol.responses = [(401, #"{"error":{"message":"API key not valid"}}"#), (200, "{}")]
        await #expect(throws: GeminiError.http(status: 401, message: "API key not valid")) {
            _ = try await gemini.detectDocumentType("x")
        }
        #expect(StubProtocol.requests.count == 1)
    }

    @Test func truncatedAnswerSplitsTheChunkAndRetries() async throws {
        let gemini = extractor()
        let chunk = String(repeating: "The tenant agrees to the terms in this paragraph.\n", count: 20)
        StubProtocol.responses = [
            (200, geminiBody("{\"clauses\":[", finish: "MAX_TOKENS")),
            (200, geminiBody(#"{"clauses":[{"type":"guests","quote":"First half clause text here."}]}"#)),
            (200, geminiBody(#"{"clauses":[{"type":"pets","quote":"Second half clause text here."}]}"#)),
        ]
        let clauses = try await gemini.extractClauses(from: chunk, documentType: .residentialLease)
        #expect(clauses.map(\.type) == [.guests, .pets])
        #expect(StubProtocol.requests.count == 3)
    }

    @Test func invalidJSONIsReportedNotCrashed() async {
        let gemini = extractor()
        StubProtocol.responses = [(200, geminiBody("not json at all"))]
        await #expect(throws: GeminiError.invalidJSON) {
            _ = try await gemini.extractClauses(from: "x", documentType: .unknown)
        }
    }
}

@Suite("TextSplitter")
struct TextSplitterTests {
    @Test func splitsAtALineBreakNearTheMiddleWithoutLosingText() throws {
        let text = (1 ... 20).map { "\($0). Clause number \($0) of the agreement." }.joined(separator: "\n")
        let (a, b) = try #require(TextSplitter.halves(text))
        #expect(a + b == text)
        #expect(a.last == "\n" || a.last == ".")
        #expect(abs(a.count - b.count) < text.count / 2)
    }

    @Test func refusesToSplitShortText() {
        #expect(TextSplitter.halves("short") == nil)
    }
}
