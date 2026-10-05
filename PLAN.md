# Fine Print: Build Plan

An iOS app that reads any legal-style document (lease, job offer, subscription, terms of
service), extracts what matters with on-device AI, and separates **what the law says** from
**what is merely worth a look**. All six phases are complete; see the README for results.

**Thesis (same as Projects 2, 4 and 5):** the AI drafts, code decides. The model reads and
quotes. It never issues a legal verdict, and it never gets to say something the document
doesn't say.

---

## 1. Verified environment and open unknowns

| Fact | Status | Source |
|---|---|---|
| Xcode 27.0, iOS 27.0 SDK, macOS 27.0, Apple M3 | Verified on this Mac | `xcodebuild`, `uname` |
| Simulator runtimes iOS 26.5 and 27.0; iPhone 17 Pro already booted | Verified | `simctl` |
| **Free disk: 3.8 GB** | **Risk.** Builds and simulators need headroom. | `diskutil` |
| On-device context window | **Resolved by Phase 0:** 4,096 in the iOS Simulator, 8,192 on macOS 27. Read `contextSize` at runtime. | [Phase 0 results](docs/phase0_spike.md) |
| Private Cloud Compute (32K context) | **Not available to us.** Needs App Store Small Business enrolment. | WWDC26 write-ups |
| Foundation Models in the Simulator | **Resolved by Phase 0:** `availability` reports "available" but every generation fails (safety-model asset missing). Works on the Mac host. Design now uses a launch-time capability probe. | [Phase 0 results](docs/phase0_spike.md) |
| Ontario RTA s.14 (no-pets void), s.105 (security deposits prohibited), s.106 (rent deposit capped at one month) | Confirmed by multiple secondary sources. Still to be checked against e-Laws text. | web search |
| Ontario ESA s.67.2 (non-competes void, with executive and sale-of-business exceptions; since 25 Oct 2021) | Confirmed by multiple secondary sources. Still to be checked against e-Laws text. | web search |
| Other cited sections (rent increases, entry notice, vacation, termination, overtime) | **Not yet verified. No section numbers are quoted until they are.** | n/a |

## 2. Scope

**In v1**
- Input: pasted text, PDF (PDFKit text layer), image from Photos (Vision OCR). No camera, since the Simulator has none.
- Document-type detection: lease, employment offer, subscription/terms, unknown.
- Universal clause extraction with verbatim quotes, checked by code.
- Rule packs: **Ontario residential lease** and **Ontario employment**.
- Universal "worth a look" heuristics for any document type.
- Shareable report (PDF/Markdown) through `ShareLink`.
- AI engine: on-device Foundation Models, with a Gemini fallback using the user's own key.

**Out of v1 (stated, not hidden)**
- Other provinces, other contract types as rule packs, accounts and sync, document storage beyond the session, camera capture, App Store release.
- Anything that sounds like legal advice. The app informs and cites.

## 3. Architecture

```
Input (paste / PDF / photo→OCR)
   → normalize text
   → detect document type          (AI proposes + confidence; below threshold = "unknown")
   → chunk by clause/heading       (token budget from runtime contextSize)
   → extract per chunk             (AI → typed Clause structs, each with a verbatim quote)
   → VERIFY quotes                 (code: drop anything not found in the source text)
   → merge + dedupe chunks
   → judge
        ├─ rule pack for this type?  → RULE-BACKED verdict + citation + "last verified"
        └─ universal heuristics      → WORTH-A-LOOK flags (no legal claim)
   → report (summary, clause list, detail, export)
```

**Verdict tiers (never blurred in the UI)**

| Tier | Meaning | Basis | Colour and icon |
|---|---|---|---|
| Rule-backed: void/unlawful | The law contradicts this clause | Deterministic rule + section cite + verified date | red, octagon |
| Rule-backed: compliant | Matches a rule check | same | green, check |
| Worth a look | Common risk pattern, no legal claim | Heuristic | amber, eye |
| Needs a human | The AI couldn't classify it or quote verification failed | n/a | grey, question |

Colour is never the only signal. Every tier has an icon and a text label (accessibility, and the same principle as the dataviz skill's rules).

**Engine abstraction.** A `ClauseExtractor` protocol with three implementations:
1. `FoundationModelsExtractor` (on-device, default).
2. `GeminiExtractor` (user pastes a key in Settings, stored in the Keychain, explicit consent each session because text leaves the device).
3. `MockExtractor` (deterministic fixtures, for tests and a reliable demo).

This protocol is also the interview answer to "what if the on-device model isn't available?"

**Deployment target:** iOS 26.0, with iOS 27-only APIs avoided, so the app does not depend on beta-era provider packages.

## 4. The core engineering problems

1. **Long documents vs a 4K–8K context window.** Chunk on clause or heading boundaries, reserve tokens for instructions and schema, overlap slightly, extract per chunk, then merge and dedupe by quote overlap. Count tokens with the runtime API where it exists, and use a conservative heuristic otherwise.
2. **Quote verification.** Normalize whitespace, smart quotes and hyphenation, then require a substring match. For OCR input, allow a fuzzy match (normalized edit distance over a sliding window, threshold to be tuned on the test set). Unverifiable items are dropped and counted, and the count shows in a debug panel. This is the app's headline guardrail.
3. **Classification without hallucinated law.** The model only tags a clause with a type from a closed enum (pets, deposit, guests, entry notice, rent increase, non-compete, vacation, termination, auto-renewal, arbitration, and so on). The rule engine maps type plus extracted parameters (for example, deposit amount ÷ monthly rent) to a verdict.
4. **Parameter extraction for rules that need numbers.** Example: a deposit clause becomes `{type: deposit, amount: 1500, rent: 1500}`, then the rule `rent_deposit ≤ 1 × monthly_rent` runs in code.
5. **Privacy.** On-device by default. The Gemini path shows exactly what will be sent and requires consent. No analytics, no document persistence in v1.

## 5. Rule packs (data, not code)

A pack is a JSON file validated by a schema, so adding one never touches app code.

```
{ "id": "ca-on-residential-lease", "jurisdiction": "CA-ON", "last_verified": "YYYY-MM-DD",
  "source": "https://www.ontario.ca/laws/statute/06r17",
  "rules": [ { "id": "...", "applies_to": "pets", "check": {...},
               "verdict_if_violated": "void", "citation": "RTA s.14",
               "explanation": "plain English" } ] }
```

**Verification protocol before any rule ships:** read the statute text from e-Laws, record the section number and the date checked, write a test case that exercises the rule, and have the UI display the date. Rules I can't verify don't go in; the clause falls back to an amber flag.

**Lease pack candidates:** no-pets (s.14), security/damage deposit (s.105), rent deposit cap (s.106), key deposit limits, rent-increase frequency and notice, landlord entry notice, post-dated cheque requirements, standard-lease requirement.
**Employment pack candidates:** non-compete (s.67.2 with its exceptions), vacation minimums, termination clauses vs ESA minimums, overtime thresholds, "contracting out" (ESA s.5). Section numbers beyond s.67.2 are unverified.
**Universal heuristics (amber):** auto-renewal, unilateral amendment, broad liability waiver, mandatory arbitration or class-action waiver, user indemnity, content licence or IP assignment, third-party data sharing, cancellation or early-termination fees, automatic price increases, out-of-province venue, non-disparagement, assignment without consent.

## 6. Screens

1. **Import:** paste box, Files (PDF), Photos, and "Try a sample" (bundled demo documents).
2. **Analysis:** progress by stage (reading → classifying → checking quotes → applying rules), then a colour-and-icon clause list grouped by tier.
3. **Clause detail:** the quoted text highlighted in context, the rule or heuristic, the citation, a plain-English explanation, and the verified date.
4. **Summary and export:** counts by tier, document type and confidence, and the AI engine used. A shareable report with the disclaimer.
5. **Settings:** engine choice, Gemini key (Keychain), privacy notes, rule-pack versions and verified dates.

Accessibility: Dynamic Type, VoiceOver labels on every verdict, icon plus text on every colour.

## 7. Code structure

```
fine-print/
  FinePrintCore/         Swift Package: all logic, no UI
    Sources/ Chunker, QuoteVerifier, DocumentTypeDetector, RuleEngine, Heuristics,
             ClauseExtractor (protocol + 3 impls), Models
    Tests/               runs with `swift test` on the command line, no simulator needed
  FinePrint/             SwiftUI app target (thin: views + view models)
  Packs/                 ca-on-residential-lease.json, ca-on-employment.json, schema
  Samples/               synthetic demo documents + the public Ontario standard lease form
  Eval/                  corpus with planted-clause ground truth + runner
  docs/                  README, guardrails.md, prompt_engineering.md, eval results, case study
```

Putting the logic in a separate package means the riskiest parts (quote verification, chunking, rules) are unit-tested fast on the command line, and the app target stays small.

## 8. Testing and evaluation

- **Unit tests (CLI):** chunker boundaries, quote verifier (including OCR-noise cases and hallucinated quotes), rule engine per rule, pack schema validation.
- **Eval corpus:** about 20–30 synthetic documents with planted clauses and known ground truth, plus the official Ontario standard lease form. No copyrighted terms-of-service text is reproduced.
- **Metrics:** clause recall and precision, type-detection accuracy, **quote-verification drop rate** (how often the model fabricated), rule-verdict correctness (deterministic, so it should be 100% given correct inputs), and the false-reassurance rate (a violation not flagged), which matters most.
- **Documented failures:** real misses go in the docs, as in Projects 2 and 4.
- **Prompt iteration log:** v1 → v2 with what broke and why.

## 9. Demo and deliverables

- Scripted 60–90 second screen recording through the Simulator (`xcrun simctl io recordVideo`), plus 5–6 screenshots for the portfolio site.
- Demo flow: import a messy scanned lease, watch quotes verify, see a void pet clause with its citation; then import a subscription's terms and watch it switch to amber-only with "no rule pack for this document type."
- Repo docs in the established style: README (problem, approach, decisions and why, results, limits), guardrails.md, prompt_engineering.md, eval results, a 150–250 word case study, and a new project page on the portfolio site.
- No live link is possible. The app ships as a repo, a video and screenshots, and the README says why.

## 10. Phases, each with an exit criterion

| Phase | Work | Exit criterion |
|---|---|---|
| 0. Spike ✅ | Minimal app: does Foundation Models run in this Simulator? Read `contextSize`; try one `@Generable` extraction | Done: available-but-fails in Simulator, works on Mac; [results](docs/phase0_spike.md) |
| 1. Core package ✅ | Models, normalizer, quote verifier, chunker, rule engine, pack loader/validator, mock extractor, analyzer | Done: 30 tests (38 cases) green, 0 warnings |
| 2. Packs ✅ | Verify statute text, write the lease and employment packs and the heuristics | Done: 15 rules (10 lease, 5 employment) + 14 amber flags, all read from e-Laws 2026-10-04; 37 tests green; [verification log](docs/rule_verification.md) |
| 3. Extraction ✅ | Foundation Models extractor, Gemini extractor, Mock extractor, doc-type detection | Done: 3 engines + capability-probing selector, `fp-eval` runs the 6-doc corpus end to end; Gemini 100% / on-device 29% recall; [results](docs/phase3_engines.md) |
| 4. UI ✅ | The five screens | Done: import (paste/PDF/photo OCR/samples) → consent → staged progress → results by tier → clause detail with highlight + citation → share; Settings with probe log. Verified in the Simulator with **real Gemini**, not just the Mock engine. Two bugs found and fixed while testing (sheet dismissed by `.constant` bindings; misleading key-source label). |
| 5. Evaluation ✅ | Run the corpus, record the misses, iterate the prompt | Done: corpus 6 → 12 docs (negations, non-solicit, messy PDF, injection); prompt v2/v2.1 + LabelGuard; wrong legal verdicts → 0 on all engines; Gemini 100%; [results](docs/phase5_evaluation.md) |
| 6. Demo and docs ✅ | Recording, screenshots, README, case study, site page | Done: app icon, 115 s Simulator demo (12 MB web version), 7 framed screenshots, README, case study (237 words), portfolio page; no em dashes in any notes or docs |

If Phase 0 shows Foundation Models doesn't run in the Simulator, the default engine becomes Gemini with the Mock engine for tests, and the docs say so. The architecture doesn't change.

## 11. Risks

| Risk | Mitigation |
|---|---|
| Wrong legal rule undermines the whole app | Verification protocol, verified-date display, closed rule set, amber fallback |
| Reads as legal advice | Disclaimer on every verdict screen and in exports; wording is "this clause conflicts with s.X," never "you should" |
| Model fabricates a clause | Quote verification drops it; drop rate is a reported metric |
| Small context window | Chunking and merge, tested with long documents |
| Simulator can't run on-device AI | Phase 0 finds out first; Gemini and Mock engines already planned |
| Disk space (3.8 GB free) | Free space before Phase 0 (see below) |
| Scope creep toward "every contract" | Two packs in v1, extensibility shown by the architecture |

## 12. Decisions made, and decisions needed

**Made:** two rule packs in v1; iOS 26.0 deployment target; engine protocol with three implementations; core logic in a Swift package; amber heuristics for everything without a pack; no document persistence.

**Resolved with the user**
1. **Disk space:** the 1.2 GB StatCan LFS file was deleted with approval (free space went from 3.8 GB to 5.2 GB). Still modest headroom, so avoid extra simulator runtimes and clear DerivedData if builds get tight.
2. **Gemini fallback: kept** (recommended). On-device stays the default. The fallback is the safety net if the Simulator can't run Foundation Models, and it makes the engine protocol a real design decision rather than a theoretical one.

3. **App name and bundle ID:** "Fine Print" and `com.lekanlawal.fineprint`.
4. **Repo:** public at https://github.com/lekanlawal1/fine-print, with a project page on the portfolio site.
