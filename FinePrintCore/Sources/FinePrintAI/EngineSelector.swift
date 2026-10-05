// Picks the engine at launch by TESTING capability, not by trusting a flag.
//
// Phase 0 found that in the iOS Simulator SystemLanguageModel reports `.available` while
// every generation fails (its safety-model asset can't load). So the on-device engine is
// chosen only after a real tiny generation succeeds.
//
// Order (product decision from the Phase 3 scorecard: Gemini 100% clause recall vs 29%
// on-device): Gemini, when the user has saved a key AND allowed documents to leave the
// device → on-device (private, offline) → keyword engine (always works, no AI).

import Foundation
import FoundationModels
import FinePrintCore

public enum EngineKind: String, Sendable {
    case onDevice = "on_device"
    case gemini
    case keyword
}

public struct EngineSelection: Sendable {
    public let kind: EngineKind
    public let extractor: any ClauseExtractor
    /// Human-readable trail of what was tried and why, shown in Settings.
    public let log: [String]
}

public enum EngineSelector {
    /// - Parameter geminiAPIKey: pass nil unless the user has allowed cloud processing.
    public static func select(geminiAPIKey: String?, allowOnDevice: Bool = true,
                              probeTimeout: Double = 20) async -> EngineSelection {
        var log: [String] = []

        if let key = geminiAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
            let gemini = GeminiExtractor(apiKey: key, maxAttempts: 2)
            do {
                _ = try await withTimeout(probeTimeout) { try await gemini.detectDocumentType("Probe: this is a test.") }
                log.append("Gemini: key works. Preferred engine (most accurate in evaluation).")
                return EngineSelection(kind: .gemini, extractor: GeminiExtractor(apiKey: key), log: log)
            } catch {
                log.append("Gemini: test request failed (\(short(error))).")
            }
        } else {
            log.append("Gemini: not set up (needs an API key and your permission to send documents).")
        }

        if allowOnDevice {
            let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
            switch model.availability {
            case .available:
                do {
                    try await withTimeout(probeTimeout) {
                        _ = try await LanguageModelSession(model: model).respond(to: "Reply with the single word OK.")
                    }
                    log.append("On-device model: reported available, and a test generation succeeded.")
                    return EngineSelection(kind: .onDevice, extractor: await FoundationModelsExtractor.make(), log: log)
                } catch {
                    log.append("On-device model: reported available, but a test generation failed (\(short(error))).")
                }
            case let .unavailable(reason):
                log.append("On-device model: unavailable (\(reason)).")
            }
        } else {
            log.append("On-device model: turned off in Settings.")
        }

        log.append("Using the keyword engine (no AI). Results are limited to known phrases.")
        return EngineSelection(kind: .keyword, extractor: MockExtractor(), log: log)
    }

    /// A readable cause, e.g. "SensitiveContentAnalysisML 15 → ModelManagerError 1001"
    /// instead of a multi-line NSError dump.
    static func short(_ error: Error) -> String {
        if let described = (error as? LocalizedError)?.errorDescription, !described.contains("Domain=") {
            return String(described.prefix(160))
        }
        var chain: [String] = []
        var current: NSError? = error as NSError
        while let e = current, chain.count < 5 {
            let domain = e.domain.split(separator: ".").last.map(String.init) ?? e.domain
            if chain.last != "\(domain) \(e.code)" { chain.append("\(domain) \(e.code)") }
            current = (e.userInfo[NSMultipleUnderlyingErrorsKey] as? [NSError])?.first
                ?? e.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return chain.joined(separator: " → ")
    }
}

struct TimeoutError: Error, LocalizedError {
    var errorDescription: String? { "timed out" }
}

/// Runs `operation`, failing with TimeoutError if it doesn't finish in time.
func withTimeout<T: Sendable>(_ seconds: Double, _ operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw TimeoutError()
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
