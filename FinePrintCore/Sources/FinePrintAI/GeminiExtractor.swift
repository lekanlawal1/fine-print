// Engine 2: Gemini over REST (the same model family as Projects 2 and 4).
//
// Same prompt text and the same closed vocabulary as the on-device engine, enforced here
// with Gemini's JSON-schema output mode (`responseSchema`, enums for type and parameter
// names). Retries 429/5xx with exponential backoff, like Project 2. Text leaves the device on
// this path, which is why the app asks for consent before using it.

import Foundation
import FinePrintCore

public struct GeminiExtractor: ClauseExtractor {
    public let name: String
    /// Gemini's real window is far larger; chunks stay moderate to keep latency and output
    /// size predictable.
    public let chunkBudget = ChunkBudget(contextSize: 24_000, reservedForInstructions: 2_000, reservedForOutput: 8_000)

    let apiKey: String
    let model: String
    let session: URLSession
    let maxAttempts: Int
    let baseDelay: Double
    let thinkingLevel: String

    public init(apiKey: String, model: String = "gemini-3-flash-preview", session: URLSession = .shared,
                maxAttempts: Int = 4, baseDelay: Double = 2, thinkingLevel: String = "low") {
        self.apiKey = apiKey
        self.model = model
        self.session = session
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.thinkingLevel = thinkingLevel
        self.name = "Gemini (\(model))"
    }

    public func detectDocumentType(_ text: String) async throws -> TypeGuess {
        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "type": ["type": "STRING", "enum": DocumentType.allCases.map(\.rawValue)],
                "confidence": ["type": "NUMBER"],
            ],
            "required": ["type", "confidence"],
        ]
        let json = try await generate(system: Prompts.documentTypeInstructions,
                                      prompt: Prompts.documentTypePrompt(sample: Prompts.sample(text)),
                                      schema: schema)
        let dto = try decode(DocumentTypeDTO.self, json)
        return TypeGuess(type: DocumentType(rawValue: dto.type) ?? .unknown,
                         confidence: min(max(dto.confidence, 0), 1))
    }

    public func extractClauses(from chunk: String, documentType: DocumentType) async throws -> [ExtractedClause] {
        try await extract(chunk, documentType: documentType, depth: 0)
    }

    /// A cut-off answer (MAX_TOKENS) means too many clauses for one response: split and retry.
    func extract(_ text: String, documentType: DocumentType, depth: Int) async throws -> [ExtractedClause] {
        do {
            return try await extractOnce(text, documentType: documentType)
        } catch GeminiError.truncated {
            guard depth < 3, let (left, right) = TextSplitter.halves(text) else { throw GeminiError.truncated }
            return try await extract(left, documentType: documentType, depth: depth + 1)
                + extract(right, documentType: documentType, depth: depth + 1)
        }
    }

    func extractOnce(_ chunk: String, documentType: DocumentType) async throws -> [ExtractedClause] {
        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "clauses": [
                    "type": "ARRAY",
                    "items": [
                        "type": "OBJECT",
                        "properties": [
                            "type": ["type": "STRING", "enum": ClauseCatalog.extractableTypes.map(\.rawValue)],
                            "quote": ["type": "STRING"],
                            "parameters": [
                                "type": "ARRAY",
                                "items": [
                                    "type": "OBJECT",
                                    "properties": [
                                        "name": ["type": "STRING", "enum": ClauseCatalog.allParameterNames],
                                        "value": ["type": "NUMBER"],
                                    ],
                                    "required": ["name", "value"],
                                ],
                            ],
                        ],
                        "required": ["type", "quote"],
                    ],
                ],
            ],
            "required": ["clauses"],
        ]
        let json = try await generate(system: Prompts.extractionInstructions(for: documentType),
                                      prompt: Prompts.extractionPrompt(chunk: chunk, documentType: documentType),
                                      schema: schema)
        return try decode(ExtractionDTO.self, json).clauses.compactMap(Self.convert)
    }

    // MARK: - HTTP

    func generate(system: String, prompt: String, schema: [String: Any]) async throws -> String {
        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": system]]],
            "contents": [["role": "user", "parts": [["text": prompt]]]],
            "generationConfig": [
                "temperature": 0,
                "responseMimeType": "application/json",
                "responseSchema": schema,
                // Measured: at the default (high) thinking level, some inputs sent the model
                // into 60K+ thinking tokens and ~3-minute responses for a ~300-token answer.
                // Extraction + tagging doesn't need deep reasoning; "low" ran every corpus
                // document in ~2s with identical clause counts. See docs/phase3_engines.md.
                "thinkingConfig": ["thinkingLevel": thinkingLevel],
            ],
        ]
        var request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")  // header, never the URL
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var lastError: Error = GeminiError.emptyResponse
        for attempt in 1 ... maxAttempts {
            try Task.checkCancellation()
            do {
                let (data, response) = try await session.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                if status == 429 || status >= 500 {
                    lastError = GeminiError.http(status: status, message: Self.errorMessage(data))
                } else if status != 200 {
                    // 400/401/403: retrying won't help (bad key, bad request).
                    throw GeminiError.http(status: status, message: Self.errorMessage(data))
                } else {
                    return try Self.text(from: data)
                }
            } catch let error as GeminiError {
                if case let .http(status, _) = error, status != 429, status < 500 { throw error }
                // Deterministic failures: at temperature 0 a retry returns the same answer.
                // A truncated answer is handled by splitting the chunk, not by retrying it.
                if case .blocked = error { throw error }
                if error == .truncated { throw error }
                lastError = error
            } catch let error as URLError {
                lastError = error  // timeouts and transport errors are retryable
            }
            if attempt < maxAttempts {
                try await Task.sleep(for: .seconds(baseDelay * pow(2, Double(attempt - 1))))
            }
        }
        throw lastError
    }

    static func text(from data: Data) throws -> String {
        let r = try JSONDecoder().decode(GenerateResponse.self, from: data)
        if let reason = r.promptFeedback?.blockReason { throw GeminiError.blocked(reason) }
        guard let candidate = r.candidates?.first else { throw GeminiError.emptyResponse }
        if candidate.finishReason == "MAX_TOKENS" { throw GeminiError.truncated }
        // Thinking models can return thought parts; only answer text counts.
        let text = (candidate.content?.parts ?? []).filter { $0.thought != true }.compactMap(\.text).joined()
        guard !text.isEmpty else { throw GeminiError.emptyResponse }
        return text
    }

    static func errorMessage(_ data: Data) -> String {
        (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error.message
            ?? String(data: data.prefix(200), encoding: .utf8) ?? ""
    }

    func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        do { return try JSONDecoder().decode(T.self, from: Data(json.utf8)) }
        catch { throw GeminiError.invalidJSON }
    }

    static func convert(_ c: ClauseDTO) -> ExtractedClause? {
        guard let type = ClauseType(rawValue: c.type) else { return nil }
        let allowed = Set(ClauseCatalog.spec(for: type)?.parameters.map(\.name) ?? [])
        var params: [String: Double] = [:]
        for p in c.parameters ?? [] where allowed.contains(p.name) && p.value.isFinite && p.value >= 0 {
            params[p.name] = p.value
        }
        return ExtractedClause(type: type, quote: c.quote, parameters: params)
    }

    // MARK: - Wire types

    struct GenerateResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable { let parts: [Part]? }
            struct Part: Decodable { let text: String?; let thought: Bool? }
            let content: Content?
            let finishReason: String?
        }
        struct Feedback: Decodable { let blockReason: String? }
        let candidates: [Candidate]?
        let promptFeedback: Feedback?
    }

    struct ErrorResponse: Decodable {
        struct Body: Decodable { let message: String }
        let error: Body
    }

    struct DocumentTypeDTO: Decodable { let type: String; let confidence: Double }
    struct ParameterDTO: Decodable { let name: String; let value: Double }
    struct ClauseDTO: Decodable { let type: String; let quote: String; let parameters: [ParameterDTO]? }
    struct ExtractionDTO: Decodable { let clauses: [ClauseDTO] }
}

public enum GeminiError: Error, LocalizedError, Equatable {
    case http(status: Int, message: String)
    case blocked(String)
    case truncated
    case emptyResponse
    case invalidJSON

    public var errorDescription: String? {
        switch self {
        case let .http(status, message): "Gemini returned HTTP \(status): \(message)"
        case let .blocked(reason): "Gemini declined to process this text (\(reason))."
        case .truncated: "Gemini's answer was cut off before it finished."
        case .emptyResponse: "Gemini returned an empty answer."
        case .invalidJSON: "Gemini's answer wasn't valid structured output."
        }
    }
}
