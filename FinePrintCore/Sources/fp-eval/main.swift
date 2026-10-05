// fp-eval: run an engine over the labelled corpus and score it.
//
//   swift run fp-eval --engine mock|ondevice|gemini
//
// Metrics are user-centred, not just clause counts:
//   - false reassurance: a violation the app should have flagged but didn't (worst outcome)
//   - wrong legal verdicts: a rule-backed verdict that shouldn't exist (e.g. ESA on a contractor)
//   - verdict agreement: rule-backed findings matching what the labelled clauses imply
//   - clause recall/precision, parameter accuracy, document-type accuracy
//   - quote drop rate: share of extracted clauses whose quote wasn't in the document
// Writes Eval/results/<engine>.md.

import Foundation
import FinePrintAI
import FinePrintCore

struct Truth: Decodable {
    struct Expected: Decodable {
        let type: String
        let marker: String
        let params: [String: Double]?
    }
    let documentType: String
    let source: String
    let expected: [Expected]
    let absent: [String]
    let allowedExtra: [String]
}

// MARK: - Arguments and setup

func argument(_ name: String, default value: String) -> String {
    let args = CommandLine.arguments
    if let i = args.firstIndex(of: name), i + 1 < args.count { return args[i + 1] }
    return value
}

if CommandLine.arguments.contains("--print-prompt") {
    print(Prompts.extractionInstructions)
    exit(0)
}

let engineName = argument("--engine", default: "mock")
let corpusDir = URL(fileURLWithPath: argument("--corpus", default: "../Eval/corpus"))
let packsDir = URL(fileURLWithPath: argument("--packs", default: "../Packs"))
let outDir = URL(fileURLWithPath: argument("--out", default: "../Eval/results"))

func loadKey() -> String? {
    if let k = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !k.isEmpty { return k }
    guard let env = try? String(contentsOfFile: "../.env", encoding: .utf8) else { return nil }
    return env.split(separator: "\n").first { $0.hasPrefix("GEMINI_API_KEY=") }
        .map { String($0.dropFirst("GEMINI_API_KEY=".count)).trimmingCharacters(in: .whitespaces) }
}

let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
let lease = try PackLoader.rulePack(from: Data(contentsOf: packsDir.appendingPathComponent("ca-on-residential-lease.json")))
let employment = try PackLoader.rulePack(from: Data(contentsOf: packsDir.appendingPathComponent("ca-on-employment.json")))
let heuristics = try PackLoader.heuristicPack(from: Data(contentsOf: packsDir.appendingPathComponent("universal-heuristics.json")))
let ruleEngine = RuleEngine(packs: [lease, employment], heuristics: heuristics)

let extractor: any ClauseExtractor
switch engineName {
case "mock":
    extractor = MockExtractor()
case "ondevice":
    extractor = await FoundationModelsExtractor.make()
case "gemini":
    guard let key = loadKey() else { fatalError("Set GEMINI_API_KEY or create fine-print/.env") }
    extractor = GeminiExtractor(apiKey: key)
default:
    fatalError("unknown engine '\(engineName)' (use mock, ondevice or gemini)")
}
print("Engine: \(extractor.name) · context \(extractor.chunkBudget.contextSize) · prompt \(Prompts.version)")

// MARK: - Scoring helpers

func charRange(of marker: String, in text: String) -> Range<Int>? {
    guard let r = text.range(of: marker, options: .caseInsensitive) else { return nil }
    let lo = text.distance(from: text.startIndex, to: r.lowerBound)
    return lo ..< lo + text.distance(from: r.lowerBound, to: r.upperBound)
}

func overlaps(_ a: Range<Int>, _ b: Range<Int>) -> Bool {
    a.lowerBound < b.upperBound && b.lowerBound < a.upperBound
}

func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) <= max(0.01, abs(b) * 0.005) }

struct DocResult {
    let name: String
    let typeOK: Bool
    let actualType: DocumentType
    let confidence: Double
    let expected: Int
    let found: Int
    let paramsExpected: Int
    let paramsCorrect: Int
    let falsePositives: [String]
    let absentHits: [String]
    let extracted: Int
    let dropped: [DroppedClause]
    let failedChunks: Int
    let labelUncertain: Int
    let failureReasons: [String]
    let ruleExpected: Int
    let ruleAgreed: Int
    let falseReassurance: [String]
    let wrongVerdicts: [String]
    let missed: [String]
    let paramErrors: [String]
    let seconds: Double
}

// MARK: - Run

let only = argument("--only", default: "")
let files = try FileManager.default.contentsOfDirectory(at: corpusDir, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension == "txt" && (only.isEmpty || $0.lastPathComponent.contains(only)) }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

var results: [DocResult] = []
for file in files {
    let name = file.deletingPathExtension().lastPathComponent
    let text = try String(contentsOf: file, encoding: .utf8)
    let truth = try decoder.decode(Truth.self, from: Data(contentsOf: file.deletingPathExtension().appendingPathExtension("truth.json")))
    let expectedType = DocumentType(rawValue: truth.documentType)!
    print("· \(name) …", terminator: "")
    fflush(stdout)

    let analyzer = Analyzer(extractor: extractor, engine: ruleEngine)
    let report = try await analyzer.analyze(text, source: truth.source == "ocr" ? .ocr : .text)

    // Clause matching: same type, overlapping the labelled marker.
    var found = 0, paramsExpected = 0, paramsCorrect = 0
    var missed: [String] = [], paramErrors: [String] = []
    var matchedIDs = Set<Int>()
    var truthClauses: [VerifiedClause] = []
    for e in truth.expected {
        guard let markerRange = charRange(of: e.marker, in: text) else { fatalError("marker not in \(name): \(e.marker)") }
        let type = ClauseType(rawValue: e.type)!
        truthClauses.append(VerifiedClause(clause: ExtractedClause(type: type, quote: e.marker, parameters: e.params ?? [:]),
                                           range: markerRange, matchScore: 1))
        let hit = report.verifiedClauses.enumerated().first { $0.element.type == type && overlaps($0.element.range, markerRange) }
        guard let (index, clause) = hit else {
            missed.append("\(e.type) (\"\(e.marker)\")")
            continue
        }
        found += 1
        matchedIDs.insert(index)
        for (k, v) in e.params ?? [:] {
            paramsExpected += 1
            if let got = clause.clause.parameters[k], close(got, v) {
                paramsCorrect += 1
            } else {
                paramErrors.append("\(e.type).\(k): expected \(v), got \(clause.clause.parameters[k].map { "\($0)" } ?? "nothing")")
            }
        }
    }

    let falsePositives = report.verifiedClauses.enumerated()
        .filter { !matchedIDs.contains($0.offset) && !truth.allowedExtra.contains($0.element.type.rawValue) }
        .map { "\($0.element.type.rawValue): \"\(String(Array(text)[$0.element.range]).prefix(60))\"" }
    let absentHits = report.verifiedClauses.filter { truth.absent.contains($0.type.rawValue) }.map(\.type.rawValue)

    // Verdict-level scoring: what the labelled clauses SHOULD produce vs what the app produced.
    let expectedRules = ruleEngine.evaluate(truthClauses, documentType: expectedType).filter { $0.citation != nil }
    let actualRules = report.findings.filter { $0.citation != nil }
    let actualByTitle = Dictionary(actualRules.map { ($0.title, $0.tier) }, uniquingKeysWith: { a, b in a == .ruleViolation ? a : b })
    let expectedByTitle = Dictionary(expectedRules.map { ($0.title, $0.tier) }, uniquingKeysWith: { a, _ in a })
    let agreed = expectedByTitle.filter { actualByTitle[$0.key] == $0.value }.count
    let falseReassurance = expectedByTitle.filter { $0.value == .ruleViolation && actualByTitle[$0.key] != .ruleViolation }
        .map { "\($0.key) (app said: \(actualByTitle[$0.key]?.rawValue ?? "nothing"))" }
    let wrongVerdicts = actualByTitle.filter { title, tier in
        // Only real verdicts count; "check this yourself" (needs_human) is not a legal verdict.
        guard tier == .ruleViolation || tier == .ruleCompliant else { return false }
        return expectedByTitle[title] == nil || (tier == .ruleViolation && expectedByTitle[title] != .ruleViolation)
    }
        .map { "\($0.key) → \($0.value.rawValue)" }

    let r = DocResult(
        name: name, typeOK: report.documentType == expectedType, actualType: report.documentType,
        confidence: report.typeConfidence, expected: truth.expected.count, found: found,
        paramsExpected: paramsExpected, paramsCorrect: paramsCorrect, falsePositives: falsePositives,
        absentHits: absentHits, extracted: report.verifiedClauses.count + report.dropped.count,
        dropped: report.dropped, failedChunks: report.failedChunks.count,
        labelUncertain: report.verifiedClauses.filter { $0.labelNote != nil }.count,
        failureReasons: report.failedChunks.map(\.reason) + (report.typeDetectionError.map { ["type detection: \($0)"] } ?? []),
        ruleExpected: expectedByTitle.count, ruleAgreed: agreed,
        falseReassurance: falseReassurance.sorted(), wrongVerdicts: wrongVerdicts.sorted(),
        missed: missed, paramErrors: paramErrors, seconds: report.elapsedSeconds)
    results.append(r)
    print(" recall \(found)/\(r.expected), verdicts \(agreed)/\(r.ruleExpected), \(String(format: "%.1f", r.seconds))s")
}

// MARK: - Report

func pct(_ a: Int, _ b: Int) -> String { b == 0 ? "n/a" : String(format: "%.0f%%", 100 * Double(a) / Double(b)) }
let sum = { (f: (DocResult) -> Int) in results.reduce(0) { $0 + f($1) } }

let tExp = sum(\.expected), tFound = sum(\.found)
let tFP = sum { $0.falsePositives.count + $0.absentHits.count }
let tParamsExp = sum(\.paramsExpected), tParamsOK = sum(\.paramsCorrect)
let tExtracted = sum(\.extracted), tDropped = sum { $0.dropped.filter(\.reason.isQuoteFailure).count }
let tRejected = sum { $0.dropped.filter { if case .labelContradicted = $0.reason { true } else { false } }.count }
let tScope = sum { $0.dropped.filter { if case .outOfScope = $0.reason { true } else { false } }.count }
let tUncertain = sum(\.labelUncertain)
let tRuleExp = sum(\.ruleExpected), tRuleOK = sum(\.ruleAgreed)
let tReassure = sum { $0.falseReassurance.count }, tWrong = sum { $0.wrongVerdicts.count }
let tTypeOK = results.filter(\.typeOK).count

var md: [String] = [
    "# Eval: \(extractor.name)", "",
    "Prompt \(Prompts.version) · context window \(extractor.chunkBudget.contextSize) tokens · \(results.count) documents · run \(ISO8601DateFormatter().string(from: Date()))", "",
    "## Headline", "",
    "| Metric | Result |", "|---|---|",
    "| **False reassurance** (violations not flagged) | **\(tReassure)** |",
    "| **Wrong legal verdicts** | **\(tWrong)** |",
    "| Verdict agreement (rule-backed) | \(tRuleOK)/\(tRuleExp) (\(pct(tRuleOK, tRuleExp))) |",
    "| Clause recall | \(tFound)/\(tExp) (\(pct(tFound, tExp))) |",
    "| Clause precision | \(pct(tFound, tFound + tFP)) (\(tFP) unexpected) |",
    "| Parameter accuracy | \(tParamsOK)/\(tParamsExp) (\(pct(tParamsOK, tParamsExp))) |",
    "| Document type accuracy | \(tTypeOK)/\(results.count) |",
    "| Quote drop rate (fabricated or mangled quotes) | \(tDropped)/\(tExtracted) (\(pct(tDropped, tExtracted))) |",
    "| Labels rejected by LabelGuard (wording said the opposite) | \(tRejected) |",
    "| Labels downgraded to \"check this yourself\" | \(tUncertain) |",
    "| Out-of-scope clause types dropped | \(tScope) |",
    "| Sections the engine failed on | \(sum(\.failedChunks)) |",
    "| Total time | \(String(format: "%.1f", results.reduce(0) { $0 + $1.seconds }))s |", "",
    "## Per document", "",
    "| Document | Type | Recall | Params | Verdicts | Unexpected | Dropped | Time |", "|---|---|---|---|---|---|---|---|",
]
for r in results {
    md.append("| \(r.name) | \(r.typeOK ? "✓" : "✗") \(r.actualType.rawValue) (\(String(format: "%.2f", r.confidence))) | \(r.found)/\(r.expected) | \(r.paramsCorrect)/\(r.paramsExpected) | \(r.ruleAgreed)/\(r.ruleExpected) | \(r.falsePositives.count + r.absentHits.count) | \(r.dropped.count)/\(r.extracted) | \(String(format: "%.1f", r.seconds))s |")
}
md += ["", "## Details", ""]
for r in results {
    var lines: [String] = []
    lines += r.failureReasons.map { "- ❌ engine failure: \($0)" }
    lines += r.falseReassurance.map { "- ⚠️ false reassurance: \($0)" }
    lines += r.wrongVerdicts.map { "- ⚠️ wrong legal verdict: \($0)" }
    lines += r.missed.map { "- missed: \($0)" }
    lines += r.paramErrors.map { "- parameter: \($0)" }
    lines += r.falsePositives.map { "- unexpected: \($0)" }
    lines += r.absentHits.map { "- should be absent: \($0)" }
    lines += r.dropped.map { "- dropped quote (\($0.reason)): \($0.clause.type.rawValue) \"\($0.clause.quote.prefix(70))\"" }
    if !lines.isEmpty { md += ["### \(r.name)"] + lines + [""] }
}

try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let tag = argument("--tag", default: "")
let out = outDir.appendingPathComponent(tag.isEmpty ? "\(engineName).md" : "\(engineName)-\(tag).md")
try md.joined(separator: "\n").write(to: out, atomically: true, encoding: .utf8)
print("\n" + md[4 ... 18].joined(separator: "\n"))
print("\nWrote \(out.path)")
