# Phase 0 Spike: Results

**Question:** can Apple's on-device Foundation Models run in the iOS Simulator on this Mac,
what is the real context window, and does typed `@Generable` extraction work?

**Setup:** MacBook (Apple M3), macOS 27.0, Xcode 27.0. Spike app in `Spike/` (generated with
XcodeGen), deployment target iOS 26.0. API names were read from the SDK's
`FoundationModels.swiftinterface`, not from blog posts.

## Results

| Check | iOS 27.0 Simulator | iOS 26.5 Simulator | macOS 27 host (command-line test) |
|---|---|---|---|
| `availability` | **available** | **available** | available |
| `contextSize` | 4,096 | 4,096 | **8,192** |
| Plain text generation, default guardrails | **FAILED**: `SensitiveContentAnalysisML 15 → ModelManagerError 1001` | same | **OK** ("Hello.") |
| Plain text, `permissiveContentTransformations` | **FAILED**: `ModelManagerError 1026` | same | not tested |
| Typed `@Generable` extraction | **FAILED** (same chain as default) | same | not tested |

## What it means

1. **`availability` says "available" while every generation fails.** Every request passes
   through a separate safety-classifier model (`SensitiveContentAnalysisML`), and in the
   Simulator that model's asset can't be loaded. Developer-forum reports match: "Local Model
   Asset unavailable" in the Simulator.
2. **The context window depends on the OS and model version:** 4,096 in the iOS Simulator,
   8,192 on macOS 27. That explains the conflicting sources. The design must read
   `contextSize` at runtime, never hardcode it.
3. **The API itself works.** The same code generates successfully on the Mac host, so this is
   an environment problem, not a code problem.

## Design changes adopted

- **Capability probe instead of trusting `availability`.** At launch the app makes one tiny
  real generation call. Only if it succeeds is the on-device engine selected; otherwise the app
  falls back (Gemini with the user's key, then the Mock engine) and tells the user why. This is
  the "don't trust the flag, test the capability" lesson, learned from real evidence.
- **Runtime token budget.** The chunker sizes chunks from the live `contextSize` (4,096 or 8,192).
- **The Gemini fallback is now essential, not optional,** for any Simulator demo with real AI,
  unless the environment fix below works.

## Fixes reported to work (all need the user, since they touch system settings)

From Apple Developer Forums threads on these error codes: restart the Mac, then toggle Apple
Intelligence off and on in System Settings. Xcode and macOS are already matched (27.0/27.0),
which is the other commonly reported cause. After any fix, re-run the spike:
`xcrun simctl launch --console-pty booted com.lekanlawal.fineprint.spike`.

## Housekeeping

A temporary iOS 26.5 simulator created for this test was deleted afterwards. Free disk space is
now about 3.0 GB, so the spike's `Spike/build/` folder can be deleted to recover space.
