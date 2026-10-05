# Phase 3: Extraction Engine Results

Three engines implement the same `ClauseExtractor` protocol and share one prompt
(`Prompts.swift`, built from `ClauseCatalog`), so they are compared on equal terms. Each was
scored by `fp-eval` over the 6-document labelled corpus in `Eval/corpus`. Full per-document
results: `Eval/results/{mock,ondevice,gemini}.md`.

## Scorecard (prompt v1)

| Metric | Keyword engine (no AI) | Apple on-device (Mac, 8K context) | Gemini 3 Flash |
|---|---|---|---|
| **False reassurance** (violations not flagged) | 7 | 7 | **0** |
| **Wrong legal verdicts** | 1 | 1 | **0** |
| Verdict agreement (rule-backed) | 41% | 45% | **100%** |
| Clause recall | 71% | 29% | **100%** |
| Clause precision | 73% | 71% | **100%** |
| Parameter accuracy | 53% | 75% | **100%** |
| Document type accuracy | 5/6 | **6/6** | **6/6** |
| Quote drop rate (fabricated quotes) | 0% | 0% | 0% |
| Time for the corpus | <0.1 s | ~38 s | ~14 s |

**Caveat, stated up front:** six synthetic documents I wrote myself is a small, friendly test
set. 100% here means "no failures found yet", not "no failures exist". Phase 5 expands the
corpus with harder documents.

## Finding 1: the on-device model under-extracts and mislabels

The ~3B-parameter on-device model classified every document correctly but extracted only 13
clauses in total (34 expected), and **none at all** from the subscription terms. Two patterns:

- **List overload:** 26 clause types in one prompt is too many for a small model. It leans on
  the first types listed (lease types) and tagged a subscription price change as `rent_increase`.
- **The dangerous error:** on the *fully compliant* lease it labelled a legal rent deposit and
  a legal key deposit as `security_deposit`, producing a **wrong legal verdict**. Quote
  verification can't catch this, because the quote is real and only the label is wrong. This
  is the most important finding of Phase 3: verifying *what* the model quotes doesn't verify
  *how* it labels it.

Planned for Phase 5: offer only the clause types relevant to the detected document type, and
add a label-consistency check for the clause types that carry legal verdicts.

## Finding 2: Gemini's "thinking" can run away (fixed)

The first Gemini run timed out on one document on every retry (528 s). Reproducing the
request outside the app showed that identical inputs sometimes trigger enormous hidden
reasoning: **62,912 thinking tokens and ~175 s** to produce a 364-token answer. Which document
triggers it depends on the exact request bytes, so it looked random.

Fix: `thinkingConfig.thinkingLevel = "low"`. Clause extraction and tagging don't need deep
reasoning. Measured before and after:

| Document | Default thinking | Low thinking |
|---|---|---|
| Problem lease | 175 s, 62,912 thinking tokens | **2.0 s**, same 9 clauses |
| Subscription terms | timed out in-app (8 s standalone) | **1.7 s**, same 8 clauses |

Accuracy didn't change; latency and cost dropped by up to ~90×. This matters for the demo and
for anyone paying per token.

## Finding 3: a retry bug the tests caught

A cut-off answer (`MAX_TOKENS`) was first treated like a temporary network error and retried
identically. At temperature 0 that reproduces the same cut-off. It now goes straight to
splitting the chunk in half. A stubbed-network unit test pins this behaviour.

## Engine selection (what the app does at launch)

`EngineSelector` tests capability instead of trusting `availability`:
1. **On-device:** only if a real test generation succeeds (it reports "available" but fails in
   the iOS Simulator, per Phase 0).
2. **Gemini:** if the user has saved a key and a probe request succeeds.
3. **Keyword engine:** always works, labelled "no AI" in every report.

Given the scorecard, the app should **prefer Gemini when the user has consented and saved a
key**, and use on-device as the private, offline option with a clear note that it finds fewer
clauses. This is a product decision the numbers made, not a guess.
