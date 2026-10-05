// Phase 0 spike: three questions, answered by running, not by reading blog posts.
//   1. Is the on-device model available in this Simulator? (and if not, why)
//   2. What is the real context window? (sources disagree: 4,096 vs 8,192)
//   3. Does typed @Generable extraction work, and do the quotes it returns
//      actually exist in the source text? (preview of the app's core guardrail)
// Results print to stdout with a "SPIKE|" prefix so they can be read from the
// command line, and render on screen for a screenshot.

import FoundationModels
import SwiftUI

@Generable
enum SpikeClauseType {
    case pets, deposit, guests, rentIncrease, other
}

@Generable
struct SpikeClause {
    @Guide(description: "What the clause is about")
    var type: SpikeClauseType
    @Guide(description: "The clause copied word for word from the document. Do not paraphrase.")
    var quote: String
}

@Generable
struct SpikeExtraction {
    @Guide(description: "Every clause in the document")
    var clauses: [SpikeClause]
}

let sampleLease = """
4. The Tenant shall not keep any pets or animals in the unit at any time.
5. The Tenant shall pay a damage deposit of $1,500 before moving in.
6. Overnight guests are not permitted without the Landlord's written consent.
"""

@MainActor
final class Spike: ObservableObject {
    @Published var lines: [String] = []

    func log(_ s: String) {
        lines.append(s)
        print("SPIKE| \(s)")
    }

    func run() async {
        let model = SystemLanguageModel.default

        // 1. Availability
        switch model.availability {
        case .available:
            log("availability: AVAILABLE")
        case .unavailable(let reason):
            log("availability: UNAVAILABLE (\(reason))")
        }

        // 2. Context window
        log("contextSize: \(model.contextSize) tokens")

        guard case .available = model.availability else {
            log("extraction: SKIPPED (model unavailable)")
            log("DONE")
            return
        }

        // Token count of the sample (iOS 26.4+)
        if #available(iOS 26.4, *) {
            if let n = try? await model.tokenCount(for: sampleLease) {
                log("sample tokenCount: \(n)")
            }
        } else {
            log("sample tokenCount: n/a (needs iOS 26.4)")
        }

        // 3a. Diagnose: is ALL generation blocked, or only some configurations?
        //     (first run failed inside SensitiveContentAnalysisML with ModelManagerError 1001)
        for (label, m) in [("default guardrails", SystemLanguageModel.default),
                           ("permissive guardrails",
                            SystemLanguageModel(guardrails: .permissiveContentTransformations))] {
            do {
                let r = try await LanguageModelSession(model: m).respond(to: "Say hello in five words.")
                log("plain text [\(label)]: OK \"\(r.content)\"")
            } catch {
                log("plain text [\(label)]: FAILED \(shortError(error))")
            }
        }

        // 3b. Typed extraction + quote verification (permissive: we only transform
        //     the user's own document, the use case that setting exists for)
        let session = LanguageModelSession(
            model: SystemLanguageModel(guardrails: .permissiveContentTransformations),
            instructions: "You extract clauses from legal documents. Copy each clause verbatim.")
        let start = Date()
        do {
            let response = try await session.respond(
                to: "Document:\n\(sampleLease)", generating: SpikeExtraction.self)
            let secs = String(format: "%.1f", Date().timeIntervalSince(start))
            log("extraction: OK in \(secs)s, \(response.content.clauses.count) clauses")
            for c in response.content.clauses {
                // Core guardrail preview: does the quote really appear in the source?
                let verified = sampleLease.contains(c.quote.trimmingCharacters(in: .whitespacesAndNewlines))
                log("  [\(c.type)] verified=\(verified) \"\(c.quote.prefix(60))\"")
            }
        } catch {
            log("extraction: FAILED \(shortError(error))")
        }
        log("DONE")
    }

    /// Innermost error domain + code, e.g. "ModelManagerError 1001 via SensitiveContentAnalysisML 15"
    func shortError(_ error: Error) -> String {
        var chain: [String] = []
        var current: NSError? = error as NSError
        while let e = current {
            chain.append("\(e.domain.split(separator: ".").last ?? "") \(e.code)")
            current = (e.userInfo[NSMultipleUnderlyingErrorsKey] as? [NSError])?.first
                ?? e.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return chain.joined(separator: " → ")
    }
}

@main
struct SpikeApp: App {
    @StateObject private var spike = Spike()
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List(spike.lines, id: \.self) { Text($0).font(.system(.footnote, design: .monospaced)) }
                    .navigationTitle("Phase 0 Spike")
            }
            .task { await spike.run() }
        }
    }
}
