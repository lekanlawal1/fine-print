// swift-tools-version: 6.0
// FinePrintCore: every piece of Fine Print's logic that must be trustworthy, with no UI and
// no AI dependency, unit-tested from the command line with `swift test` in seconds.
// FinePrintAI: the engines that read documents (Apple on-device model, Gemini) plus the
// launch-time capability probe. Kept separate so the core never depends on an AI framework.
// fp-eval: command-line evaluation over the labelled corpus in ../Eval.
import PackageDescription

let package = Package(
    name: "FinePrintCore",
    platforms: [.iOS("26.0"), .macOS("26.0")],
    products: [
        .library(name: "FinePrintCore", targets: ["FinePrintCore"]),
        .library(name: "FinePrintAI", targets: ["FinePrintAI"]),
        .executable(name: "fp-eval", targets: ["fp-eval"]),
    ],
    targets: [
        .target(name: "FinePrintCore"),
        .target(name: "FinePrintAI", dependencies: ["FinePrintCore"]),
        .executableTarget(name: "fp-eval", dependencies: ["FinePrintCore", "FinePrintAI"]),
        .testTarget(name: "FinePrintCoreTests", dependencies: ["FinePrintCore"]),
        .testTarget(name: "FinePrintAITests", dependencies: ["FinePrintAI", "FinePrintCore"]),
    ]
)
