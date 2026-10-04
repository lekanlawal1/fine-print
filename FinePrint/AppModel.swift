// App-wide state: rule packs, the selected engine, and the user's privacy settings.

import FinePrintAI
import FinePrintCore
import Foundation
import Observation

/// A document ready to analyze.
struct LoadedDocument: Hashable {
    let title: String
    let text: String
    let source: SourceKind
}

/// What the Analysis screen is asked to do.
struct AnalysisRequest: Hashable {
    let document: LoadedDocument
    /// true = the user declined to send this document off the device.
    let offline: Bool
}

@MainActor
@Observable
final class AppModel {
    private(set) var engine: EngineSelection?
    private(set) var checkingEngines = false
    private(set) var packs: [RulePack] = []
    private(set) var heuristics: HeuristicPack?
    private(set) var packProblems: [String] = []
    private var offlineEngine: EngineSelection?

    /// The user's standing permission for Gemini; consent is still asked once per session.
    var geminiAllowed: Bool {
        didSet { UserDefaults.standard.set(geminiAllowed, forKey: "geminiAllowed") }
    }
    var allowOnDevice: Bool {
        didSet { UserDefaults.standard.set(allowOnDevice, forKey: "allowOnDevice") }
    }
    /// Set when the user confirms sending documents to Gemini in this session.
    var sessionConsent = false

    var ruleEngine: RuleEngine { RuleEngine(packs: packs, heuristics: heuristics) }
    var hasGeminiKey: Bool { geminiKey() != nil }

    enum KeySource { case keychain, developmentEnvironment, none }

    /// Where the key actually comes from, so Settings never misstates it.
    var keySource: KeySource {
        if let key = Keychain.read(), !key.isEmpty { return .keychain }
        #if DEBUG
        if let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !key.isEmpty { return .developmentEnvironment }
        #endif
        return .none
    }

    init() {
        let defaults = UserDefaults.standard
        geminiAllowed = defaults.object(forKey: "geminiAllowed") as? Bool ?? false
        allowOnDevice = defaults.object(forKey: "allowOnDevice") as? Bool ?? true
        loadPacks()
        #if DEBUG
        if ProcessInfo.processInfo.environment["FP_KEYCHAIN_SELFTEST"] == "1" { Keychain.selfTest() }
        #endif
    }

    // MARK: - Rule packs

    private func loadPacks() {
        guard let dir = Bundle.main.url(forResource: "Packs", withExtension: nil) else {
            packProblems = ["Rule packs are missing from the app bundle."]
            return
        }
        for name in ["ca-on-residential-lease", "ca-on-employment"] {
            do {
                let pack = try PackLoader.rulePack(from: Data(contentsOf: dir.appendingPathComponent("\(name).json")))
                // The same validator the tests use: a pack that fails it never loads.
                let problems = PackValidator.validate(pack)
                if problems.isEmpty { packs.append(pack) } else { packProblems += problems.map { "\(name): \($0)" } }
            } catch {
                packProblems.append("\(name): \(error.localizedDescription)")
            }
        }
        heuristics = try? PackLoader.heuristicPack(
            from: Data(contentsOf: dir.appendingPathComponent("universal-heuristics.json")))
    }

    // MARK: - Engines

    func geminiKey() -> String? {
        if let key = Keychain.read(), !key.isEmpty { return key }
        #if DEBUG
        // Development only: lets a Simulator demo run with a key passed in the launch
        // environment (SIMCTL_CHILD_GEMINI_API_KEY) instead of typing it into the app.
        if let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !key.isEmpty { return key }
        #endif
        return nil
    }

    func checkEngines() async {
        checkingEngines = true
        engine = await EngineSelector.select(geminiAPIKey: geminiAllowed ? geminiKey() : nil,
                                             allowOnDevice: allowOnDevice)
        offlineEngine = nil
        sessionConsent = false
        checkingEngines = false
    }

    /// The best engine that keeps the document on the device.
    func engineForRequest(_ request: AnalysisRequest) async -> EngineSelection? {
        guard request.offline else { return engine }
        if offlineEngine == nil {
            offlineEngine = await EngineSelector.select(geminiAPIKey: nil, allowOnDevice: allowOnDevice)
        }
        return offlineEngine
    }

    /// Set when saving the key fails, so Settings can say so instead of failing silently.
    var keySaveError: String?

    func saveGeminiKey(_ key: String) async {
        keySaveError = Keychain.save(key.trimmingCharacters(in: .whitespacesAndNewlines))
        await checkEngines()
    }

    func removeGeminiKey() async {
        Keychain.delete()
        await checkEngines()
    }
}
