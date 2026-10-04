// Engine 1: Apple's on-device model (Foundation Models framework).
//
// Design points:
// - Typed output via @Generable, with clause types and parameter names constrained by
//   `anyOf` to the ClauseCatalog. The model physically can't emit a type the rules don't know.
// - A fresh session per request. Sessions keep a transcript, and in a 4,096-token window a
//   growing transcript would silently eat the space meant for the document.
// - If the output overflows the window, the chunk is split in half and retried (bounded depth).
// - The token budget is measured with the framework's own tokenCount where available.

import Foundation
import FoundationModels
import FinePrintCore

@Generable
struct GenParameter {
    @Guide(description: "Parameter name", .anyOf(ClauseCatalog.allParameterNames))
    var name: String
    @Guide(description: "The number exactly as stated in the document")
    var value: Double
}

@Generable
struct GenClause {
    @Guide(description: "Clause type", .anyOf(ClauseCatalog.extractableTypes.map(\.rawValue)))
    var type: String
    @Guide(description: "The clause copied exactly from the document")
    var quote: String
    @Guide(description: "Numbers stated in the document for this clause; empty if none")
    var parameters: [GenParameter]
}

@Generable
struct GenExtraction {
    @Guide(description: "Every matching clause in the text, in document order")
    var clauses: [GenClause]
}

@Generable
struct GenDocumentType {
    @Guide(description: "Document type", .anyOf(DocumentType.allCases.map(\.rawValue)))
    var type: String
    @Guide(description: "Confidence from 0 to 1")
    var confidence: Double
}

public struct FoundationModelsExtractor: ClauseExtractor {
    public let name = "Apple on-device model"
    public let chunkBudget: ChunkBudget
    let model: SystemLanguageModel
    static let maxSplitDepth = 3

    init(model: SystemLanguageModel, chunkBudget: ChunkBudget) {
        self.model = model
        self.chunkBudget = chunkBudget
    }

    /// Uses `permissiveContentTransformations`: the app only ever transforms text the user
    /// supplied, which is the use case that setting exists for.
    public static func make() async -> FoundationModelsExtractor {
        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        var reserved = 1100  // estimate when the token-counting API is unavailable
        if #available(iOS 26.4, macOS 26.4, *) {
            if let instructions = try? await model.tokenCount(for: Instructions(Prompts.extractionInstructions)),
               let schema = try? await model.tokenCount(for: GenExtraction.generationSchema) {
                reserved = instructions + schema + 50  // + prompt framing
            }
        }
        let budget = ChunkBudget(contextSize: model.contextSize, reservedForInstructions: reserved,
                                 reservedForOutput: model.contextSize >= 8192 ? 2000 : 1200)
        return FoundationModelsExtractor(model: model, chunkBudget: budget)
    }

    public func detectDocumentType(_ text: String) async throws -> TypeGuess {
        let session = LanguageModelSession(model: model, instructions: Prompts.documentTypeInstructions)
        let sampleChars = max(1000, (chunkBudget.contextSize - 600) * 2)
        let response = try await session.respond(
            to: Prompts.documentTypePrompt(sample: Prompts.sample(text, maxCharacters: sampleChars)),
            generating: GenDocumentType.self, options: GenerationOptions(temperature: 0))
        let type = DocumentType(rawValue: response.content.type) ?? .unknown
        return TypeGuess(type: type, confidence: min(max(response.content.confidence, 0), 1))
    }

    public func extractClauses(from chunk: String, documentType: DocumentType) async throws -> [ExtractedClause] {
        try await extract(chunk, documentType: documentType, depth: 0)
    }

    func extract(_ text: String, documentType: DocumentType, depth: Int) async throws -> [ExtractedClause] {
        let session = LanguageModelSession(model: model, instructions: Prompts.extractionInstructions(for: documentType))
        do {
            let response = try await session.respond(
                to: Prompts.extractionPrompt(chunk: text, documentType: documentType),
                generating: GenExtraction.self, options: GenerationOptions(temperature: 0))
            return response.content.clauses.compactMap(Self.convert)
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            guard depth < Self.maxSplitDepth, let (left, right) = TextSplitter.halves(text) else { throw ExtractionError.tooLongForContext }
            return try await extract(left, documentType: documentType, depth: depth + 1)
                + extract(right, documentType: documentType, depth: depth + 1)
        }
    }

    static func convert(_ c: GenClause) -> ExtractedClause? {
        guard let type = ClauseType(rawValue: c.type) else { return nil }
        let allowed = Set(ClauseCatalog.spec(for: type)?.parameters.map(\.name) ?? [])
        var params: [String: Double] = [:]
        for p in c.parameters where allowed.contains(p.name) && p.value.isFinite && p.value >= 0 {
            params[p.name] = p.value
        }
        return ExtractedClause(type: type, quote: c.quote, parameters: params)
    }
}

public enum ExtractionError: Error, LocalizedError {
    case tooLongForContext

    public var errorDescription: String? {
        "This section is too long for the on-device model to read, even after splitting it."
    }
}

enum TextSplitter {
    /// Split near the middle at a line break or sentence end, so a clause isn't cut in half.
    static func halves(_ text: String) -> (String, String)? {
        guard text.count > 400 else { return nil }
        let chars = Array(text)
        let mid = chars.count / 2
        let window = chars.count / 4
        let isBreak: (Int) -> Bool = { i in
            chars[i].isNewline || ((chars[i] == "." || chars[i] == ";") && i + 1 < chars.count && chars[i + 1].isWhitespace)
        }
        let candidates = (0 ... window).flatMap { [mid + $0, mid - $0] }.filter { $0 > 0 && $0 < chars.count - 1 }
        let cut = (candidates.first(where: isBreak) ?? mid) + 1
        return (String(chars[..<cut]), String(chars[cut...]))
    }
}
